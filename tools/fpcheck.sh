#!/bin/bash
# Fingerprint every style on the current code and diff against tools/fingerprints/baseline.txt.
#
# Chill Soho's rules share code with base Chill, and a mis-scoped change there alters songs that
# are already released. Those regressions are SILENT — a changed song does not error, it just
# sounds different — so this runs after every step that touches shared Chill code. It has already
# caught a change that altered 27 released Chill Blues songs.
#
# The baseline holds the INTENDED output, not a historical snapshot. Re-pin it with
#     bash tools/fpcheck.sh && cp tools/fingerprints/all_now.txt tools/fingerprints/baseline.txt
# ONLY after every reported difference has been accounted for as a deliberate change. Re-pinning
# to silence a difference you cannot explain is how a real regression gets baked in.
#
# Re-pinned 2026-10-13: Chill moved deliberately — the Shadow Hold companion note across all Chill
# forms, and Blues 20% -> 15% to make room for a 70/15/15 Soho/Blues/base split. Motorik, Kosmic
# and Ambient were byte-identical through that change and remain pinned where they always were.
#
# Re-pinned 2026-10-18: Motorik, Kosmic and Ambient moved deliberately with the all-style Harmonic
# filter change (whole figures lifted above the pads; e0e8b5f, d2645e7), bisected and accepted by
# Zack. Chill moved with the Soho work since 10-15 and the 30/20/50 mix.
#
# Re-pinned 2026-10-19: Chill moved deliberately with the Blues blue-note lick (Blues only; base Chill no
# longer injects a stray blue note, which also moved 10 Soho songs on the shared base lead rules) and the
# Blues harmony gate (CHL-LD1-004/003 leads, no vibraphone Lead 2). Motorik, Kosmic and Ambient identical.
# NOTE: the Chill mix is now 30/20/50 Soho/Blues/base (2026-10-18). Any later change to the
# mix reclassifies seeds and shows a large Chill diff — expected; re-pin after checking it.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SP="${ROOT}/tools/fingerprints"
cd "$ROOT" || exit 1
cat > Tests/ZudioTests/AllStylesFingerprintDump.swift <<'SW'
// TEMPORARY — written and removed by scratchpad/fpcheck.sh.
import Testing
import Foundation
@testable import Zudio
@Suite struct AllStylesFingerprintDump {
    @Test func dump() throws {
        guard let out = ProcessInfo.processInfo.environment["ZUDIO_FP_OUT"] else { return }
        var lines: [String] = []
        for style in [MusicStyle.motorik, .kosmic, .ambient, .chill] {
            for seed in UInt64(1)...300 {
                let s = SongGenerator.generate(seed: seed, style: style)
                var h: UInt64 = 0xcbf29ce484222325
                func mix(_ x: Int) { h ^= UInt64(bitPattern: Int64(x)); h = h &* 0x100000001b3 }
                for (t, track) in s.trackEvents.enumerated() {
                    mix(1000 + t)
                    for e in track { mix(e.stepIndex); mix(Int(e.note)); mix(Int(e.velocity)); mix(e.durationSteps) }
                }
                lines.append("\(style.rawValue) \(seed) \(s.displayStyleName.replacingOccurrences(of: " ", with: "_")) \(String(h, radix: 16))")
            }
        }
        try lines.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8)
    }
}
SW
ZUDIO_FP_OUT=$SP/all_now.txt swift test --filter AllStylesFingerprintDump 2>&1 | grep -E "error:" | head -3
rm -f Tests/ZudioTests/AllStylesFingerprintDump.swift
python3 - "$SP" <<'PY'
import sys
SP=sys.argv[1]
old=[l.split() for l in open(f"{SP}/baseline.txt").read().splitlines()]
new=[l.split() for l in open(f"{SP}/all_now.txt").read().splitlines()]
from collections import defaultdict
r=defaultdict(lambda:[0,0,0]); bad=[]
for o,n in zip(old,new):
    if o==n:
        r[o[0]][0]+=1
        if n[2]=="Chill_Soho": r[o[0]][1]+=1
    else: r[o[0]][2]+=1; bad.append(("CHANGED",o,n))
for st,(a,b,c) in r.items(): print(f"  {st:<8} identical {a:>3}   (of which Soho {b:>3})   CHANGED {c}")
print("  PROBLEMS:",len(bad))
for x in bad[:4]: print("   ",x)
PY
