// MIDIFileExporter.swift — writes a Type-1 MIDI file from a SongState
// Spec §Save button: ~/Documents/Zudio/Zudio-NNNN-MM-DD-YYYY.MID

import Foundation

struct MIDIFileExporter {

    // MARK: - Public entry point

    static func export(_ song: SongState) throws -> URL {
        let dir = zudioDocumentsDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = nextFilename(in: dir)
        let url = dir.appendingPathComponent(filename)
        try buildMIDIFile(song).write(to: url)
        return url
    }

    // MARK: - File naming

    private static func zudioDocumentsDir() -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    }

    private static func nextFilename(in dir: URL) -> String {
        let date = DateFormatter()
        date.dateFormat = "MM-dd-yyyy"
        let dateStr = date.string(from: Date())

        var maxNum = 0
        if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            for f in files where f.hasPrefix("Zudio-") && f.hasSuffix(".MID") {
                // "Zudio-NNNN-MM-DD-YYYY.MID" → drop prefix (6) and suffix (4)
                let inner = String(f.dropFirst(6).dropLast(4))  // "NNNN-MM-DD-YYYY"
                if let dash = inner.firstIndex(of: "-"), let n = Int(inner[inner.startIndex..<dash]) {
                    maxNum = max(maxNum, n)
                }
            }
        }
        return String(format: "Zudio-%04d-%@.MID", maxNum + 1, dateStr)
    }

    // MARK: - MIDI file construction

    private static let ticksPerQuarter: UInt16 = 480
    private static let ticksPerStep: Int = 120  // 16th note = 480/4

    private static func buildMIDIFile(_ song: SongState) -> Data {
        var data = Data()
        let numTracks: UInt16 = 8  // 1 tempo + 7 music

        // MThd
        data.append(contentsOf: "MThd".utf8)
        data.append(bigEndian32(6))
        data.append(bigEndian16(1))              // format 1
        data.append(bigEndian16(numTracks))
        data.append(bigEndian16(ticksPerQuarter))

        // Tempo track
        data.append(tempoTrack(bpm: song.frame.tempo))

        // Music tracks
        for i in 0..<7 {
            let events  = song.events(forTrack: i)
            let channel = kTrackMIDIChannels[i]
            let program = kDefaultGMPrograms[i] ?? 0
            data.append(musicTrack(
                name: kTrackNames[i],
                events: events,
                channel: channel,
                program: program
            ))
        }
        return data
    }

    // MARK: - Tempo track

    private static func tempoTrack(bpm: Int) -> Data {
        var body = Data()
        let usPerBeat = 60_000_000 / bpm
        body += varlenData(0)                             // delta = 0
        body.append(contentsOf: [0xFF, 0x51, 0x03,
            UInt8((usPerBeat >> 16) & 0xFF),
            UInt8((usPerBeat >> 8)  & 0xFF),
            UInt8( usPerBeat        & 0xFF)])
        body += varlenData(0)                             // delta = 0
        body.append(contentsOf: [0xFF, 0x2F, 0x00])      // end of track
        return mtrk(body)
    }

    // MARK: - Music track

    private static func musicTrack(name: String, events: [MIDIEvent], channel: UInt8, program: UInt8) -> Data {
        struct RE { let tick: Int; let bytes: [UInt8]; let isNoteOff: Bool }
        var raw: [RE] = []

        // Track name meta-event at tick 0
        let nameUTF8 = Array(name.utf8)
        var nameMeta: [UInt8] = [0xFF, 0x03]
        nameMeta += varlenBytes(nameUTF8.count)
        nameMeta += nameUTF8
        raw.append(RE(tick: 0, bytes: nameMeta, isNoteOff: false))

        // Program change at tick 0
        let ch = channel & 0x0F
        raw.append(RE(tick: 0, bytes: [0xC0 | ch, program], isNoteOff: false))

        // Note on / off pairs
        for ev in events {
            let onTick  = ev.stepIndex * ticksPerStep
            let offTick = onTick + max(1, ev.durationSteps) * ticksPerStep
            raw.append(RE(tick: onTick,  bytes: [0x90 | ch, ev.note, ev.velocity], isNoteOff: false))
            raw.append(RE(tick: offTick, bytes: [0x80 | ch, ev.note, 0x00],        isNoteOff: true))
        }

        // Sort: ascending tick, note-offs before note-ons at same tick
        let sorted = raw.sorted { a, b in
            a.tick != b.tick ? a.tick < b.tick : (a.isNoteOff && !b.isNoteOff)
        }

        // Encode with delta times
        var body = Data()
        var prevTick = 0
        for ev in sorted {
            body += varlenData(ev.tick - prevTick)
            prevTick = ev.tick
            body.append(contentsOf: ev.bytes)
        }
        // End of track
        body += varlenData(0)
        body.append(contentsOf: [0xFF, 0x2F, 0x00])
        return mtrk(body)
    }

    // MARK: - MTrk wrapper

    private static func mtrk(_ body: Data) -> Data {
        var d = Data()
        d.append(contentsOf: "MTrk".utf8)
        d.append(bigEndian32(UInt32(body.count)))
        d.append(body)
        return d
    }

    // MARK: - Encoding helpers

    private static func varlenBytes(_ value: Int) -> [UInt8] {
        var v = value
        var bytes: [UInt8] = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 {
            bytes.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        return bytes.reversed()
    }

    private static func varlenData(_ value: Int) -> Data {
        Data(varlenBytes(value))
    }

    private static func bigEndian16(_ v: UInt16) -> Data {
        Data([UInt8(v >> 8), UInt8(v & 0xFF)])
    }

    private static func bigEndian32(_ v: UInt32) -> Data {
        Data([UInt8(v >> 24), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)])
    }
}
