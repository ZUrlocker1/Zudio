// SaveReloadRoundTripTests.swift — a song changed after generation reopens as it was saved.
//
// Run with:
//   swift test --filter SaveReloadRoundTripTests
//
// ReplayFidelityTests rebuilds songs straight from their seed and never changes anything first,
// so it could not see these (all found 2026-10-18):
//   • ⚡ REGEN kept the old track seed, so a saved file rebuilt the track as it was before.
//   • An instrument changed after load never reached the saved file, and the .zudio load pinned
//     the Chill leads back to the generator's choice anyway (The Walled Lake Option reopened
//     with its old Lead 1).
//   • Forcing Blues on a .zudio reload skipped one main-stream draw, so a Blues file reopened
//     as a different song.
//   • An instrument change was not recorded against the song, so ⏮ / ⏭ brought back the
//     instruments it first loaded with.
//   • History reloads did not replay the saved Chill substyle, so a change to the Soho share
//     could turn a saved song into another substyle.

import Testing
import Foundation
@testable import Zudio

@MainActor
@Suite(.serialized) struct SaveReloadRoundTripTests {

    // MARK: - Helpers

    /// Waits for AppState's background generation or load to finish.
    private func waitUntilIdle(_ app: AppState) async throws {
        for _ in 0..<400 {
            if !app.isGenerating { return }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        Issue.record("AppState still generating after 10 s")
    }

    private func replay(_ s: SongState) -> SongState {
        AppState.regenerateSong(seed: s.globalSeed, keyOverride: nil, tempoOverride: nil, moodOverride: nil,
                                style: s.style, forced: s.forcedRules, trackOverrides: s.trackOverrides,
                                forceBlues: s.chillBluesVariation, forceSoho: s.chillSohoVariation,
                                forbidSoho: s.style == .chill && !s.chillBluesVariation && !s.chillSohoVariation)
    }

    private func chillSeeds(where pick: (SongState) -> Bool, count: Int) -> [UInt64] {
        var found: [UInt64] = []
        var seed: UInt64 = 1
        while found.count < count && seed < 400 {
            if pick(SongGenerator.generate(seed: seed, style: .chill)) { found.append(seed) }
            seed += 1
        }
        return found
    }

    // MARK: - ⚡ REGEN

    /// The regenerated track's seed is kept, so rebuilding the song from what it saves
    /// reproduces the new track, not the one it replaced.
    @Test func regeneratedTrackSurvivesReload() async throws {
        let app = AppState()
        app.playMode = .song
        app.loadFromGenerationHistory(SongGenerator.generate(seed: 11, style: .chill))
        let before = try #require(app.songState)
        app.regenerateTrack(kTrackLead1)
        try await waitUntilIdle(app)
        let after = try #require(app.songState)
        #expect(after.trackEvents[kTrackLead1] != before.trackEvents[kTrackLead1], "REGEN changed nothing")
        #expect(after.trackOverrides[kTrackLead1] != nil, "the new Lead 1 seed was dropped")
        #expect(replay(after).trackEvents[kTrackLead1] == after.trackEvents[kTrackLead1],
                "a saved song rebuilt the old Lead 1")
    }

    // MARK: - Instruments

    /// An instrument changed after load is written to the saved file, and the .zudio load
    /// brings it back instead of pinning the Chill lead to the generator's choice.
    @Test func changedLeadInstrumentSurvivesSaveAndReload() async throws {
        let app = AppState()
        app.playMode = .song
        let song = SongGenerator.generate(seed: 11, style: .chill)
        app.loadFromGenerationHistory(song)
        let pool = AppState.instrumentPoolPrograms(trackIndex: kTrackLead1, style: .chill,
                                                   isChillSoho: song.chillSohoVariation)
        try #require(pool.count > 1)
        let newIdx = ((app.instrumentOverrides[kTrackLead1] ?? 0) + 1) % pool.count
        app.setProgram(pool[newIdx], forTrack: kTrackLead1)
        app.instrumentOverrides[kTrackLead1] = newIdx

        let saved = try #require(app.songStateForSaving())
        let line = try #require(saved.generationLog.last { $0.tag == "Instruments" })
        #expect(line.description.split(separator: " ").contains("L1:\(pool[newIdx])"),
                "saved Instruments line still has the old Lead 1: \(line.description)")

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaveReloadRoundTrip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let midiURL = dir.appendingPathComponent("song.MID")
        try SongLogExporter.export(saved, midiURL: midiURL)

        let reopened = AppState()
        reopened.playMode = .song
        reopened.loadFromLogURL(midiURL.deletingPathExtension().appendingPathExtension("zudio"))
        try await waitUntilIdle(reopened)
        #expect(reopened.instrumentOverrides[kTrackLead1] == newIdx, "Lead 1 reopened with its old instrument")
    }

    /// An instrument changed with the picker (which calls only setProgram) is still there
    /// after stepping to another song and back with ⏮ / ⏭.
    @Test func changedLeadInstrumentSurvivesHistoryNavigation() async throws {
        let app = AppState()
        app.playMode = .song
        let songA = SongGenerator.generate(seed: 11, style: .chill)
        app.loadFromGenerationHistory(songA)
        let pool = AppState.instrumentPoolPrograms(trackIndex: kTrackLead1, style: .chill,
                                                   isChillSoho: songA.chillSohoVariation)
        try #require(pool.count > 1)
        let newIdx = ((app.instrumentOverrides[kTrackLead1] ?? 0) + 1) % pool.count
        app.setProgram(pool[newIdx], forTrack: kTrackLead1)

        app.loadFromGenerationHistory(SongGenerator.generate(seed: 12, style: .chill))
        app.loadFromGenerationHistory(songA)
        #expect(app.instrumentOverrides[kTrackLead1] == newIdx, "Lead 1 came back as first loaded")
    }

    // MARK: - Substyle

    /// A Blues file forces Blues on reload; that must not shift any later draw.
    @Test func bluesSongReloadsExactly() {
        let seeds = chillSeeds(where: { $0.chillBluesVariation }, count: 8)
        try? #require(!seeds.isEmpty)
        for seed in seeds {
            let original = SongGenerator.generate(seed: seed, style: .chill)
            #expect(replay(original).trackEvents == original.trackEvents, "Blues seed \(seed) reloaded differently")
        }
    }

    /// Soho songs reload as Soho and base Chill songs as base Chill, note for note.
    @Test func sohoAndBaseChillReloadExactly() {
        for seed in chillSeeds(where: { $0.chillSohoVariation }, count: 8)
                  + chillSeeds(where: { !$0.chillSohoVariation && !$0.chillBluesVariation }, count: 8) {
            let original = SongGenerator.generate(seed: seed, style: .chill)
            let again = replay(original)
            #expect(again.chillSohoVariation == original.chillSohoVariation, "seed \(seed) changed substyle")
            #expect(again.trackEvents == original.trackEvents, "seed \(seed) reloaded differently")
        }
    }

    /// Forbidding Soho actually holds a seed that would roll Soho to base Chill, which is what
    /// keeps a saved base Chill song base Chill after the Soho share is raised.
    @Test func forbidSohoHoldsBaseChill() throws {
        let seed = try #require(chillSeeds(where: { $0.chillSohoVariation }, count: 1).first)
        let held = AppState.regenerateSong(seed: seed, keyOverride: nil, tempoOverride: nil, moodOverride: nil,
                                           style: .chill, forced: [:], trackOverrides: [:], forbidSoho: true)
        #expect(!held.chillSohoVariation)
    }
}
