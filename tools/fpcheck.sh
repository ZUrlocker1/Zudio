#!/bin/bash
# Fingerprint every style on the current code and diff against the pre-Soho baseline.
#
# Chill Soho's rules share code with base Chill, and a mis-scoped change there alters songs that
# are already released. Those regressions are SILENT — a changed song does not error, it just
# sounds different — so this runs after every step that touches shared Chill code. It has already
# caught a change that altered 27 released Chill Blues songs.
#
# The baseline is tools/fingerprints/baseline-pre-soho.txt, hashed from commit 75fbf47. Regenerate
# it only from a clean checkout of that commit, never from current code.
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
old=[l.split() for l in open(f"{SP}/baseline-pre-soho.txt").read().splitlines()]
new=[l.split() for l in open(f"{SP}/all_now.txt").read().splitlines()]
from collections import defaultdict
r=defaultdict(lambda:[0,0,0]); bad=[]
for o,n in zip(old,new):
    if n[2]=="Chill_Soho":
        r[o[0]][1]+=1
        if o[2]!="Chill": bad.append(("Soho from non-base",o,n))
    elif o==n: r[o[0]][0]+=1
    else: r[o[0]][2]+=1; bad.append(("CHANGED",o,n))
for st,(a,b,c) in r.items(): print(f"  {st:<8} identical {a:>3}   Soho {b:>3}   CHANGED {c}")
print("  PROBLEMS:",len(bad))
for x in bad[:4]: print("   ",x)
PY
