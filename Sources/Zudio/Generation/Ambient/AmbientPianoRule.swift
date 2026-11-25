import Foundation

/// The three Ambient Piano Lead 1 rules. `rawValue` is the ID stored in SongState and shown in the
/// log, so saved songs keep reading the same strings.
enum AmbientPianoRule: String, CaseIterable {
    case buds  = "AMB-PNO-001"   // Floating Buds (Harold Budd)
    case satin = "AMB-PNO-002"   // Satin Melody (Satie / Arnalds)
    case koln  = "AMB-PNO-003"   // Koln Winter Arc (Winston / Jarrett)

    /// An unrecognised ID plays as Satin, as the generator always has.
    init(id: String) { self = AmbientPianoRule(rawValue: id) ?? .satin }

    /// The IDs a finished song's rule set carries for the variant that was drawn. They log under the
    /// parent ID (`SongGenerator.ambientPianoLogTag`); the log description names the variant.
    enum Variant {
        static let budsSparse    = "AMB-PNO-001-BT"
        static let budsChordWash = "AMB-PNO-001-CW"
        static let budsPendulum  = "AMB-PNO-001-PD"
        static let kolnVamp      = "AMB-PNO-003-VP"
        static let kolnLive      = "AMB-PNO-003-LW"
        static let kolnVampLive  = "AMB-PNO-003-VL"
    }
}
