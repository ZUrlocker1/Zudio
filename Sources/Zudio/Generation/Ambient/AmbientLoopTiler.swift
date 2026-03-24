// AmbientLoopTiler.swift — tiles a short loop across the full song length
// Each track in Ambient style is generated as a short co-prime loop, then tiled
// to fill totalBars. Different loop lengths create Eno-style phase shifting.

struct AmbientLoopTiler {
    /// Tiles `events` (covering [0, loopBars×16) steps) across [0, totalBars×16).
    /// Partial final tiles are included (notes starting within range are kept).
    static func tile(events: [MIDIEvent], loopBars: Int, totalBars: Int) -> [MIDIEvent] {
        guard loopBars > 0, totalBars > 0, !events.isEmpty else { return [] }
        let loopSteps  = loopBars * 16
        let totalSteps = totalBars * 16
        var result: [MIDIEvent] = []
        var tileStart = 0
        while tileStart < totalSteps {
            for ev in events {
                let newStep = tileStart + ev.stepIndex
                guard newStep < totalSteps else { continue }
                result.append(MIDIEvent(stepIndex: newStep, note: ev.note,
                                        velocity: ev.velocity, durationSteps: ev.durationSteps))
            }
            tileStart += loopSteps
        }
        return result.sorted { $0.stepIndex < $1.stepIndex }
    }
}
