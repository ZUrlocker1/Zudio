Big improvement. AudioTestSequencer is gone — was stale binary as suspected. Here's what the clean profile shows:

Fixed and gone:

LFO on main thread ✓
NSImage disk reads ✓
AudioTestSequencer ghost symbol ✓
AudioWaveformView repeated loads ✓
What remains:

VisualizerView.drawOrbs appears 5 separate times totalling roughly 193ms — it's the 60fps animation doing real drawing work. Each entry is from a slightly different closure context in the body getter. This is expected but it's now the biggest single item on the main thread.

AppState.soloState.getter at 44ms via isAnySolo — this getter is being called very frequently, likely on every step or every animation frame. Worth checking whether it's being called from the visualizer draw path.

PlaybackEngine.currentStep.setter at 59ms — down from 90ms, expected @Published cost.

AppState.isGenerating.setter at 30ms — you regenerated during the run, expected.

Overall: total CPU samples dropped from 34.49s over 1:34 to 26.20s over 1:26 — roughly a 17% reduction in CPU rate. The profile looks genuinely healthy now. The remaining items are all legitimate work rather than bugs.

The only thing worth investigating further is whether isAnySolo is being called from the draw path unnecessarily — if it's checking solo state on every animation frame that's wasteful. Want me to look at that?