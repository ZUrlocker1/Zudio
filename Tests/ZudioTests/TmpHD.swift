import Testing
import Foundation
@testable import Zudio
@Suite struct TmpHD {
    @Test func which() {
        var n = 0
        for seed in UInt64(1)...600 {
            let s = SongGenerator.generate(seed: seed, style: .chill)
            if s.generationLog.contains(where: { $0.tag == "CHL-LD1-012" }) { n += 1 }
        }
        print("HD songs=\(n)")
    }
}
