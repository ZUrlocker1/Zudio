#!/bin/bash
# zen_fpcheck.sh — prove Ambient Zen work leaves base Ambient and Ambient Piano songs unchanged.
#
# Fingerprints Ambient seeds 1-300 on the current code and compares them with
# tools/fingerprints/ambient-zen-baseline.txt (captured 2026-11-20 before any Zen code).
# Every seed that is Ambient or Ambient_Piano in BOTH files must have the same hash. Seeds that
# changed class (Ambient -> Ambient_Zen, for example) are expected while the shares move.
#
# In a Claude session /usr/bin/swift fails (arm64e shim), so this calls the real toolchain and
# must run with the sandbox disabled. It writes a temporary XCTest and deletes it afterwards.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
OUT="${1:-${TMPDIR:-/tmp}/zen_now.txt}"
SCRATCH="${ZEN_SCRATCH:-${TMPDIR:-/tmp}/zen_fp_build}"
TEST=Tests/ZudioTests/ZenBaselineDump.swift
cat > "$TEST" <<'SW'
// TEMPORARY — written and removed by tools/zen_fpcheck.sh.
import XCTest
@testable import Zudio
final class ZenBaselineDump: XCTestCase {
    func testDump() throws {
        guard let out = ProcessInfo.processInfo.environment["ZUDIO_FP_OUT"] else { return }
        var lines: [String] = []
        for seed in UInt64(1)...300 {
            let s = SongGenerator.generate(seed: seed, style: .ambient)
            var h: UInt64 = 0xcbf29ce484222325
            func mix(_ x: Int) { h ^= UInt64(bitPattern: Int64(x)); h = h &* 0x100000001b3 }
            for (t, track) in s.trackEvents.enumerated() {
                mix(1000 + t)
                for e in track { mix(e.stepIndex); mix(Int(e.note)); mix(Int(e.velocity)); mix(e.durationSteps) }
            }
            lines.append("\(seed) \(s.displayStyleName.replacingOccurrences(of: " ", with: "_")) \(String(h, radix: 16))")
        }
        try lines.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8)
    }
}
SW
D=/Applications/Xcode.app/Contents/Developer; P=$D/Platforms/MacOSX.platform/Developer
export DEVELOPER_DIR=$D SDKROOT=$P/SDKs/MacOSX.sdk SWIFT_DETERMINISTIC_HASHING=1
F="-Xswiftc -F -Xswiftc $P/Library/Frameworks -Xlinker -F -Xlinker $P/Library/Frameworks -Xlinker -rpath -Xlinker $P/Library/Frameworks"
$D/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift build --build-tests --build-system native --scratch-path "$SCRATCH" $F 2>&1 | grep -E "error:|Build complete" | tail -5
rm -f "$OUT"
ZUDIO_FP_OUT="$OUT" DYLD_FRAMEWORK_PATH=$P/Library/Frameworks DYLD_LIBRARY_PATH=$P/usr/lib:$P/Library/Developer/usr/lib \
  $D/usr/bin/xctest -XCTest ZudioTests.ZenBaselineDump/testDump "$SCRATCH/debug/ZudioPackageTests.xctest" 2>&1 | grep -E "passed|failed" | tail -1
rm -f "$TEST"
[ -s "$OUT" ] || { echo "no output"; exit 1; }
awk 'NR==FNR { cls[$1]=$2; h[$1]=$3; next }
     { if (($2=="Ambient" || $2=="Ambient_Piano") && cls[$1]==$2) { if (h[$1]==$3) same[$2]++; else { diff[$2]++; print "CHANGED", $0 } }
       else if (cls[$1]!=$2) moved[cls[$1] " -> " $2]++ }
     END { for (c in same) print c, "identical", same[c]; for (c in diff) print c, "CHANGED", diff[c]; for (m in moved) print "class", m, moved[m] }' \
  tools/fingerprints/ambient-zen-baseline.txt "$OUT"
