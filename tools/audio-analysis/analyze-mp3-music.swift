import Foundation
import AVFoundation

struct TrackResult {
    let path: String
    let name: String
    let duration: Double
    let bpmEstimate: Double?
    let introEnd: Double
    let outroStart: Double
    let sectionPoints: [Double]
    let dynamicRangeDB: Double
    let densityMean: Double
    let densityVar: Double
    let pulseRegularity: Double
    let pulseBPMProxy: Double
    let subdivisionRegularity: Double

    var jsonObject: [String: Any] {
        [
            "path": path,
            "name": name,
            "duration_s": duration,
            "bpm_est": bpmEstimate as Any,
            "intro_end_s": introEnd,
            "outro_start_s": outroStart,
            "section_points_s": sectionPoints,
            "dynamic_range_db": dynamicRangeDB,
            "density_mean": densityMean,
            "density_var": densityVar,
            "pulse_regularity": pulseRegularity,
            "pulse_bpm_proxy": pulseBPMProxy,
            "subdivision_regularity": subdivisionRegularity
        ]
    }
}

func fmt(_ x: Double) -> String { String(format: "%.2f", x) }

func movingAverage(_ x: [Double], win: Int) -> [Double] {
    if win <= 1 { return x }
    var out = Array(repeating: 0.0, count: x.count)
    var sum = 0.0
    var q = [Double]()
    q.reserveCapacity(win + 1)
    for i in 0..<x.count {
        q.append(x[i]); sum += x[i]
        if q.count > win { sum -= q.removeFirst() }
        out[i] = sum / Double(q.count)
    }
    return out
}

func median(_ x: [Double]) -> Double? {
    if x.isEmpty { return nil }
    let s = x.sorted()
    if s.count % 2 == 1 { return s[s.count / 2] }
    return 0.5 * (s[s.count / 2 - 1] + s[s.count / 2])
}

func autocorrAt(_ x: [Double], lag: Int) -> Double {
    if lag <= 0 || lag >= x.count { return 0 }
    var a = 0.0, b = 0.0, c = 0.0
    for i in lag..<x.count {
        let p = x[i], q = x[i - lag]
        a += p * q
        b += p * p
        c += q * q
    }
    if b <= 1e-9 || c <= 1e-9 { return 0 }
    return a / sqrt(b * c)
}

func analyze(path: String) throws -> TrackResult {
    let url = URL(fileURLWithPath: path)
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    let sr = format.sampleRate
    let channels = Int(format.channelCount)
    let frameCount = AVAudioFrameCount(file.length)
    let duration = Double(file.length) / sr

    guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        throw NSError(domain: "zudio", code: 1)
    }
    try file.read(into: buf)
    let n = Int(buf.frameLength)
    guard let chData = buf.floatChannelData else {
        throw NSError(domain: "zudio", code: 2)
    }

    var mono = Array(repeating: 0.0, count: n)
    if channels == 1 {
        for i in 0..<n { mono[i] = Double(chData[0][i]) }
    } else {
        for i in 0..<n { mono[i] = 0.5 * (Double(chData[0][i]) + Double(chData[1][i])) }
    }

    let hopSec = 0.05
    let winSec = 0.05
    let hop = max(1, Int(sr * hopSec))
    let win = max(1, Int(sr * winSec))

    var rms = [Double]()
    var zcr = [Double]()
    var idx = 0
    while idx + win < n {
        let slice = mono[idx..<(idx + win)]
        var e = 0.0
        var crosses = 0
        var prevSign = slice.first! >= 0
        for v in slice {
            e += v * v
            let sign = v >= 0
            if sign != prevSign { crosses += 1; prevSign = sign }
        }
        rms.append(sqrt(e / Double(win)))
        zcr.append(Double(crosses) / winSec)
        idx += hop
    }

    let env = movingAverage(rms, win: max(1, Int(1.5 / hopSec)))
    let envMax = env.max() ?? 1.0
    let envMin = env.min() ?? 0.0

    let sustainNeed = max(1, Int(2.0 / hopSec))
    var introEnd = 0.0
    if env.count > sustainNeed {
        for i in 0..<(env.count - sustainNeed) {
            let m = env[i..<(i + sustainNeed)].min() ?? 0
            if m >= 0.45 * envMax {
                introEnd = Double(i) * hopSec
                break
            }
        }
    }
    var outroStart = max(0.0, duration - 8.0)
    if env.count > sustainNeed {
        var i = env.count - sustainNeed - 1
        while i > 0 {
            let m = env[i..<(i + sustainNeed)].max() ?? 0
            let t = Double(i) * hopSec
            if m <= 0.55 * envMax && (duration - t) >= 4.0 {
                outroStart = t
                break
            }
            i -= 1
        }
    }

    var diff = Array(repeating: 0.0, count: rms.count)
    if rms.count > 1 {
        for i in 1..<rms.count {
            let d = rms[i] - rms[i - 1]
            diff[i] = d > 0 ? d : 0
        }
    }
    let odf = movingAverage(diff, win: 3)
    let odfMax = odf.max() ?? 0
    let thr = odfMax * 0.35
    var peaks = [Int]()
    let minGap = max(1, Int(0.22 / hopSec))
    var last = -1_000_000
    if odfMax > 0 && odf.count > 5 {
        for i in 2..<(odf.count - 2) {
            if odf[i] >= thr && (i - last) >= minGap {
                let lo = max(0, i - 2), hi = min(odf.count - 1, i + 2)
                if odf[i] >= (odf[lo...hi].max() ?? odf[i]) {
                    peaks.append(i)
                    last = i
                }
            }
        }
    }

    var bpmEstimate: Double? = nil
    if peaks.count >= 10 {
        var intervals = [Double]()
        for i in 1..<peaks.count {
            let dt = Double(peaks[i] - peaks[i - 1]) * hopSec
            if dt >= 0.25 && dt <= 1.2 { intervals.append(dt) }
        }
        if let med = median(intervals), med > 0 {
            var b = 60.0 / med
            while b < 80 { b *= 2 }
            while b > 180 { b /= 2 }
            bpmEstimate = b
        }
    }

    let smooth = movingAverage(rms, win: max(1, Int(2.0 / hopSec)))
    let den = max(1e-9, envMax - envMin)
    let norm = smooth.map { ($0 - envMin) / den }

    var sectionPoints = [0.0]
    let w = max(1, Int(4.0 / hopSec))
    let step = max(1, Int(1.0 / hopSec))
    if norm.count > 2 * w {
        var i = w
        while i < norm.count - w {
            let pre = norm[(i - w)..<i].reduce(0, +) / Double(w)
            let post = norm[i..<(i + w)].reduce(0, +) / Double(w)
            if abs(post - pre) >= 0.16 {
                let t = Double(i) * hopSec
                if t - (sectionPoints.last ?? 0) >= 8.0 {
                    sectionPoints.append(t)
                }
            }
            i += step
        }
    }
    if duration - (sectionPoints.last ?? 0) > 6.0 { sectionPoints.append(duration) }

    let densityMean = zcr.reduce(0, +) / Double(max(1, zcr.count))
    var dv = 0.0
    for v in zcr {
        let d = v - densityMean
        dv += d * d
    }
    let densityVar = sqrt(dv / Double(max(1, zcr.count)))
    let dynamicRangeDB = envMax > 0 ? 20.0 * log10((envMax + 1e-9) / max(envMin, 1e-6)) : 0

    let pulseBestLagRange = 7...20
    var pulseBest = 0.0
    var pulseLag = 0
    for lag in pulseBestLagRange {
        let c = autocorrAt(diff, lag: lag)
        if c > pulseBest { pulseBest = c; pulseLag = lag }
    }
    let pulseBPMProxy = pulseLag > 0 ? 60.0 / (Double(pulseLag) * 0.05) : 0
    let subdivisionRegularity = autocorrAt(diff, lag: max(1, pulseLag / 2))

    return TrackResult(
        path: path,
        name: url.lastPathComponent,
        duration: duration,
        bpmEstimate: bpmEstimate,
        introEnd: introEnd,
        outroStart: outroStart,
        sectionPoints: sectionPoints,
        dynamicRangeDB: dynamicRangeDB,
        densityMean: densityMean,
        densityVar: densityVar,
        pulseRegularity: pulseBest,
        pulseBPMProxy: pulseBPMProxy,
        subdivisionRegularity: subdivisionRegularity
    )
}

func printUsage() {
    let name = (CommandLine.arguments.first as NSString?)?.lastPathComponent ?? "analyze-mp3-music.swift"
    print("Usage:")
    print("  xcrun swift \(name) [--json /path/out.json] <audio1.mp3> <audio2.mp3> ...")
    print("  xcrun swift \(name) [--json /path/out.json] --list /path/input-files.txt")
}

var args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty {
    printUsage()
    exit(1)
}

var jsonPath: String? = nil
var listPath: String? = nil
var files = [String]()

var i = 0
while i < args.count {
    let a = args[i]
    if a == "--json" && i + 1 < args.count {
        jsonPath = args[i + 1]
        i += 2
    } else if a == "--list" && i + 1 < args.count {
        listPath = args[i + 1]
        i += 2
    } else {
        files.append(a)
        i += 1
    }
}

if let listPath {
    let raw = try String(contentsOfFile: listPath, encoding: .utf8)
    let listed = raw
        .split(separator: "\n")
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    files.append(contentsOf: listed)
}

files = Array(Set(files)).sorted()
if files.isEmpty {
    print("No input files provided.")
    printUsage()
    exit(1)
}

var results = [TrackResult]()
for f in files {
    do {
        let r = try analyze(path: f)
        results.append(r)
    } catch {
        fputs("ERROR \(f): \(error)\n", stderr)
    }
}

print("AUDIO_ANALYSIS_RESULTS")
for r in results {
    print("---")
    print(r.name)
    print("duration_s=\(fmt(r.duration)) bpm_est=\(r.bpmEstimate != nil ? fmt(r.bpmEstimate!) : "n/a")")
    print("intro_end_s=\(fmt(r.introEnd)) outro_start_s=\(fmt(r.outroStart))")
    let sp = r.sectionPoints.prefix(12).map { fmt($0) }.joined(separator: ",")
    print("section_points_s=[\(sp)] n_sections=\(max(0, r.sectionPoints.count - 1))")
    print("dynamic_range_db=\(fmt(r.dynamicRangeDB)) density_mean=\(fmt(r.densityMean)) density_var=\(fmt(r.densityVar))")
    print("pulse_regularity=\(fmt(r.pulseRegularity)) pulse_bpm_proxy=\(fmt(r.pulseBPMProxy)) subdivision_regularity=\(fmt(r.subdivisionRegularity))")
}

if let jsonPath {
    let payload = results.map { $0.jsonObject }
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: jsonPath))
    print("WROTE_JSON \(jsonPath)")
}
