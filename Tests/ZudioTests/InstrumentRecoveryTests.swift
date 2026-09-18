// InstrumentRecoveryTests.swift — instrument-assignment recovery on song reload.
//
// Run with:
//   swift test --filter InstrumentRecoveryTests
// (xcodebuild test cannot launch the test runner on this machine — LaunchServices error.)
//
// Covers the Sept 2026 bug where reloading a song replaced its instruments with the first
// entry of each pool. Instrument picks use SystemRandomNumberGenerator, so they cannot be
// re-derived from the song seed — they are recovered from the "Instruments" line stored in
// the song's own generation log. These tests pin that recovery and the warning that fires
// when it is not possible.

import Testing
import Foundation
@testable import Zudio

@MainActor
@Suite struct InstrumentRecoveryTests {

    /// Ambient pools, for reference:
    ///   Lead1 [61001, 73, 79, 78, 100, 82, 46, 77]   Lead2 [46, 24, 98, 91, 99]
    ///   Pads  [95, 50, 94, 97]                       Bass  [42, 60, 54, 62, 93]
    /// So "L1:73 L2:99 Pd:94 Bs:42" is indices 1, 4, 2, 0 — and index 0 everywhere is the
    /// silent fallback this bug produced ("L1:61001 L2:46 Pd:95 Bs:42").
    private func ambientState(instrumentsLine: String?) -> SongState {
        var state = SongGenerator.generate(seed: 4766134943568505749, style: .ambient)
        if let line = instrumentsLine {
            state.generationLog.append(GenerationLogEntry(
                tag: "Instruments", description: line, isTitle: false))
        }
        return state
    }

    // MARK: - The recovery logic (pure, no AppState)

    @Test func recoversIndicesFromInstrumentsLine() throws {
        let state = ambientState(instrumentsLine: "L1:73 L2:99 Pd:94 Bs:42")
        let ovr = AppState.instrumentOverridesFromLog(state)
        #expect(ovr[kTrackLead1] == 1, "L1:73 is index 1 of the Ambient Lead 1 pool")
        #expect(ovr[kTrackLead2] == 4, "L2:99 is index 4")
        #expect(ovr[kTrackPads]  == 2, "Pd:94 is index 2")
        #expect(ovr[kTrackBass]  == 0, "Bs:42 is index 0")
    }

    /// The failure mode: index 0 for every track. Recovery must reproduce it faithfully
    /// rather than treating it as "no data" — a song really can use index 0 everywhere.
    @Test func recoversAllZeroAssignmentFaithfully() throws {
        let state = ambientState(instrumentsLine: "L1:61001 L2:46 Pd:95 Bs:42")
        let ovr = AppState.instrumentOverridesFromLog(state)
        #expect(ovr[kTrackLead1] == 0)
        #expect(ovr[kTrackLead2] == 0)
        #expect(ovr[kTrackPads]  == 0)
        #expect(ovr[kTrackBass]  == 0)
    }

    /// Tx: carries a texture NAME, not a program, and the name can contain a space
    /// ("Tx:Long Lake"). It must never be parsed as an instrument program.
    @Test func ignoresTextureNameToken() throws {
        let state = ambientState(instrumentsLine: "L1:73 Tx:Long Lake Bs:42")
        let ovr = AppState.instrumentOverridesFromLog(state)
        #expect(ovr[kTrackTexture] == nil, "texture is handled by the texture paths, not here")
        #expect(ovr[kTrackLead1] == 1, "tokens after the texture name must still parse")
        #expect(ovr[kTrackBass]  == 0)
    }

    @Test func noInstrumentsLineYieldsNothing() throws {
        let state = ambientState(instrumentsLine: nil)
        #expect(AppState.instrumentOverridesFromLog(state).isEmpty)
    }

    // MARK: - The warning, driven through AppState

    /// A fresh AppState has an empty sessionInstrumentOverrides cache, which is exactly the
    /// condition that made reloads fall back to pool index 0. With no Instruments line to
    /// recover from, the reload must say so in the log instead of silently substituting.
    @Test func warnsWhenAssignmentCannotBeRecovered() async throws {
        let app = AppState()
        app.loadFromGenerationHistory(ambientState(instrumentsLine: nil))
        let warnings = app.statusLog.filter { $0.tag == "Warning" }
        #expect(!warnings.isEmpty, "expected a warning when no assignment can be recovered")
        #expect(warnings.contains { $0.description.contains("default instruments") })
    }

    /// The same reload, but with the song's own Instruments line present, must recover the
    /// assignment and stay quiet.
    @Test func noWarningWhenAssignmentIsRecoverable() async throws {
        let app = AppState()
        app.loadFromGenerationHistory(ambientState(instrumentsLine: "L1:73 L2:99 Pd:94 Bs:42"))
        #expect(app.instrumentOverrides[kTrackLead1] == 1, "recovered from the log, not index 0")
        #expect(!app.statusLog.contains { $0.tag == "Warning" },
                "assignment was recoverable, so no warning should be logged")
    }

    // MARK: - The Ambient Piano leak

    /// An Ambient Piano song pins Lead 1 to Stereo Piano (index 0). That pin used to survive
    /// into the next Ambient song and then get persisted with it, showing as "L1:61001".
    @Test func ambientPianoPinDoesNotLeakIntoNextSong() async throws {
        let app = AppState()
        // Drive a piano song first so the Lead 1 pin is applied.
        var piano = SongGenerator.generate(seed: 99, style: .ambient, forceAmbientPianoRule: "AMB-PNO-002")
        piano.generationLog.append(GenerationLogEntry(
            tag: "Instruments", description: "L1:61001", isTitle: false))
        app.loadFromGenerationHistory(piano)

        // Then a non-piano Ambient song whose own log says Lead 1 is Flute (73, index 1).
        app.loadFromGenerationHistory(ambientState(instrumentsLine: "L1:73 L2:99 Pd:94 Bs:42"))
        #expect(app.instrumentOverrides[kTrackLead1] == 1,
                "Lead 1 must be the song's own instrument, not the piano pinned by the previous song")
    }
}
