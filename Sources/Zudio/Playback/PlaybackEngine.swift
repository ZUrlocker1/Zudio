    // PlaybackEngine.swift — AVAudioEngine + 7 AVAudioUnitSampler nodes
// Spec §AVAudioEngine playback architecture

import AVFoundation
import AudioToolbox

@MainActor
final class PlaybackEngine: ObservableObject {
    // MARK: - State

    @Published var isPlaying: Bool = false
    @Published var currentBar: Int = 0
    @Published var currentStep: Int = 0
    @Published var activeVisualizerNotes: [VisualizerNote] = []

    // MARK: - Audio graph

    private let engine   = AVAudioEngine()
    // nonisolated(unsafe): buonce in setupEngine() (main actor, before playback).
    // Read from background timer thread in onStep() — AVAudioUnitSampler is thread-safe.
    nonisolated(unsafe) private var samplers = [AVAudioUnitSampler]()
    private var boosts      = [AVAudioMixerNode]()     // outputVolume > 1 = clean gain boost; also carries pan
    private var sweepFilters = [AVAudioUnitEffect]()   // LFO-driven low-pass for Sweep effect
    private var delays      = [AVAudioUnitDelay]()
    private var comps       = [AVAudioUnitEffect]()
    private var lowEQs      = [AVAudioUnitEQ]()
    private var reverbs     = [AVAudioUnitReverb]()
    private let mixer       = AVAudioMixerNode()

    // Ambient mode — set before defaultsResetToken fires so setEffect uses Ambient values
    var ambientMode: Bool = false

    // Chill pads mode — per-note audio fade-in/fade-out on kTrackPads boost node (same mechanism as Ambient)
    nonisolated(unsafe) var chillPadsMode: Bool = false

    // Per-track Ambient reverb wet values (cathedral for Lead/Pads/Texture, largeChamber for rest)
    // Order: Lead1, Lead2, Pads, Rhythm, Texture, Bass, Drums
    private let ambientReverbWet: [Float]    = [82, 78, 88, 65, 90, 62, 70, 82]  // LeadSynth: same as Lead1

    // Per-track Ambient delay config: wet%, feedback%, lowpassHz (-1 = delay not used on this track)
    // Texture (idx 4): 1-beat echo, 18% wet, feedback=35 → 2–3 audible repeats, rolled off at 2.5kHz
    private let ambientDelayWet:      [Float] = [40,  55, -1, 48, 18, -1, 28, -1]   // -1 = no delay
    private let ambientDelayFeedback: [Float] = [55,  65, -1, 55, 35, -1, 18,  0]
    private let ambientDelayLowpass:  [Float] = [4000, 4500, -1, 3500, 2500, -1, 3000, -1]
    // Delay times in beats: Lead1=dotted-quarter(0.75), Lead2=dotted-quarter(0.75),
    //                       Rhythm=dotted-half(1.5), Texture=1-beat, Drums=1-beat
    private let ambientDelayBeats:   [Double] = [0.75, 0.75, 1.0, 1.5, 1.0, 1.0, 1.0, 1.0]

    // Per-track base volumes — persisted so applyMuteState restores the right level, not 1.0
    private var trackBaseVolume = Array(repeating: Float(1.0), count: kTrackCount)

    // Static pans applied once at load time (not in the LFO loop).
    // Kosmic: wider lead spread; Motorik: tighter. Rhythm/Texture offset for separation.
    // stopPan() restores to these values when auto-pan LFO is disabled.
    private var trackStaticPan = Array(repeating: Float(0), count: kTrackCount)

    // Tremolo LFO
    private var tremEnabled   = Array(repeating: false,   count: kTrackCount)
    private var tremPhase     = Array(repeating: Double(0), count: kTrackCount)
    private var tremPhaseInc  = Array(repeating: Double(0.8378), count: kTrackCount)  // default 8 Hz at 60fps
    private var tremDepth     = Array(repeating: Float(0.40),  count: kTrackCount)    // default 40% depth

    // Sweep LFO (low-pass filter cutoff modulation)
    private var sweepEnabled = Array(repeating: false, count: kTrackCount)
    private var sweepPhase   = Array(repeating: Double(0), count: kTrackCount)

    // Global filter sweep (iPhone two-finger gesture): briefly opens all non-drum filters
    // together, then returns each track to its previous bypass state.
    private var globalSweepTicksRemaining: Int = 0
    private var globalSweepPhase: Double = 0
    private var preGlobalSweepEnabled: [Bool] = Array(repeating: false, count: kTrackCount)

    // Canvas-wide flash for filter-sweep gesture — set when sweep triggers, read by VisualizerView Canvas.
    // NOT @Published: Canvas reads it on TimelineView ticks, no SwiftUI reactive update needed.
    var canvasFlashDate: Date? = nil

    // Pan LFO (auto-pan on boost mixer node)
    private var panEnabled   = Array(repeating: false, count: kTrackCount)
    private var panPhase     = Array(repeating: Double(0), count: kTrackCount)
    private var panPhaseInc  = Array(repeating: Double(0), count: kTrackCount)  // per-track hz baked in

    // Shared LFO timer — replaces per-effect-per-track timers.
    // Fires at 60fps (16ms); tremolo updates every tick, sweep/pan every 3rd tick (~20fps).
    private var lfoTimer:     DispatchSourceTimer? = nil
    private var lfoTickCount: Int = 0
    private let lfoQueue = DispatchQueue(label: "com.zudio.lfo", qos: .userInteractive)

    // Endless / Evolve callbacks — set by AppState.init(); all called on main actor.
    var onApproachingEnd:   (() -> Void)? = nil
    var onSongEndNaturally: (() -> Void)? = nil
    var onOutroStart:       (() -> Void)? = nil

    // Audio health callbacks — set by AppState.init(); called on main actor.
    // onAudioEngineRestarted: fired at the end of restartAudio() so AppState can re-apply
    // instrument programs (route changes invalidate sampler soundbank buffers).
    var onAudioEngineRestarted: (() -> Void)? = nil
    // onEngineError: fired when engine.start() throws so AppState can log the failure.
    var onEngineError: ((String) -> Void)? = nil
    // onAudioInterrupted: fired on iOS when another app takes audio focus (e.g. Apple Music starts)
    // or when headphones are pulled. PlaybackEngine.stop() has already been called; AppState uses
    // this to stop audioTexture (Chill background loop) and any other non-engine audio.
    var onAudioInterrupted: (() -> Void)? = nil
    // Set to true once the corresponding callback fires; reset on load(), seek(), switchToPass().
    private var approachingEndFired = false
    private var outroStartFired     = false

    // Kosmic drone fade (intro 0→1, outro 1→0 on boosts[bass] and boosts[pads])
    var kosmicStyle: Bool = false
    private var droneFadeTimers: [DispatchSourceTimer?] = [nil, nil]  // [intro, outro]
    // Body entrance fade: tracks with no intro notes fade in over 1 bar at the body downbeat
    private var bodyEntranceFadeTimer: DispatchSourceTimer? = nil

    // Motorik fade (intro 0→1, outro 1→0 on engine.mainMixerNode — all tracks together)
    var motorikStyle: Bool = false
    var chillFade: Bool = false
    private var motorikFadeTimers: [DispatchSourceTimer?] = [nil, nil]  // [intro, outro]

    // Ambient song-level outro fade (mainMixerNode 1→0 over outro or last 4 bars)
    private var ambientOutroFadeTimer: DispatchSourceTimer? = nil

    // Ambient per-note attack/decay fades on boosts[kTrackBass] and boosts[kTrackPads].
    // Each note-on triggers a ramp to 1.0; each note-off triggers a ramp to 0.0.
    // Duration is capped to 1/3 of the note's duration so short notes still sound.
    // Index: [0]=Bass, [1]=Pads. Single shared 20 Hz timer drives both channels — eliminates
    // the 1000+ DispatchSource alloc/cancel cycles that occurred with one timer per note event.
    private var ambientFadeTimer:          DispatchSourceTimer? = nil
    private var ambientNoteFadeActive:     [Bool]   = [false, false]
    private var ambientNoteFadeStartNanos: [UInt64] = [0, 0]
    private var ambientNoteFadeFromVol:    [Float]  = [0, 0]
    private var ambientNoteFadeToVol:      [Float]  = [1, 1]
    private var ambientNoteFadeDuration:   [Double] = [0.5, 0.5]   // stored at note-on; reused at note-off

    // Step-event map: built once at load time for O(1) lookup in onStep.
    // nonisolated(unsafe): written on main actor in load(), read from background timer thread.
    // Writes always happen-before reads (load() runs before play() which starts the timer).
    nonisolated(unsafe) private var stepEventMap: [Int: [(Int, MIDIEvent)]] = [:]

    // Note-off map: keyed by (stepIndex + durationSteps), value = [(trackIndex, noteNumber)].
    // Built alongside stepEventMap; fired directly in onStep — eliminates asyncAfter allocs.
    nonisolated(unsafe) private var noteOffMap: [Int: [(Int, UInt8)]] = [:]

    // Export tap state — allows cancelExport() to stop capture from outside the tap closure.
    // @unchecked Sendable: written on main actor, read/written from audio thread; done flag is
    // set once and only grows monotonically — no torn reads possible.
    private final class ExportTapState: @unchecked Sendable {
        var frames:        Int64 = 0
        var done:          Bool  = false
        // Fade-out: fadeStartFrame < fadeTotalFrames means a linear 0→silence fade is applied.
        // Int64.max = no fade (default for full-song export).
        var fadeStartFrame:  Int64 = Int64.max
        var fadeTotalFrames: Int64 = 0
    }
    nonisolated(unsafe) private var currentExportTap:        ExportTapState?                        = nil
    nonisolated(unsafe) private var currentExportOnComplete: (@Sendable (Error?) -> Void)?          = nil

    // Hidden intro/outro modulation: pads sweep LFO + bass slow pan (no UI change)
    // Driven by the shared lfoTimer — no separate timers.
    private var kosmicIntroSweepPhase:  Double = 0.0
    private var kosmicIntroSweepActive: Bool   = false
    private var kosmicIntroBassPanPhase: Double = 0.0
    private var kosmicIntroBassPanActive: Bool  = false
    // Intro volume ramp timer (bass + pads: 0 → 1.0 over intro duration)
    private var kosmicIntroFadeTimer:    DispatchSourceTimer? = nil

    private static let compDesc = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_DynamicsProcessor,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0, componentFlagsMask: 0
    )
    private static let lpDesc = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_LowPassFilter,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0, componentFlagsMask: 0
    )
    private var scheduler: StepScheduler?

    // MARK: - Song state

    private(set) var songState: SongState?

    // Incremented each time a new scheduler starts. onStep tasks check this to
    // reject stale callbacks queued before a stop/seek/generate.
    // nonisolated(unsafe): written on main actor, read from background note-off closures.
    // Reads may be slightly stale (one extra stopNote at worst) — acceptable trade-off.
    nonisolated(unsafe) private(set) var currentSchedulerID: Int = 0

    // X-Files delay mute: Lead 1 delay is temporarily disabled during the Ambient whistle block.
    private var xFilesDelayBlockRange: Range<Int>? = nil
    private var xFilesDelayWasEnabled = false

    // Mute/solo state indexed by trackIndex
    var muteState: [Bool] = Array(repeating: false, count: kTrackCount) {
        didSet { applyMuteState() }
    }
    var soloState: [Bool] = Array(repeating: false, count: kTrackCount) {
        didSet { anySoloActive = soloState.contains(true); applyMuteState() }
    }
    private var anySoloActive = false

    // MARK: - Init — engine starts once at launch (spec §Engine setup)

    init() {
        setupEngine()
        startEngine()
        registerAudioNotifications()
    }

    private func registerAudioNotifications() {
        // AVAudioEngineConfigurationChange fires on both Mac and iOS when the hardware
        // config changes (e.g. Bluetooth connects and negotiates a different sample rate,
        // or a USB audio interface is plugged in). The engine auto-stops; restart it.
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.restartAudio()
        }

        #if os(iOS)
        // interruptionNotification fires when another app takes audio focus.
        // On .began: the system has already deactivated our session — stop the scheduler only;
        //   do NOT call setActive(false) (the session is already gone, and notifying others is
        //   wrong here since the interrupting app is already playing).
        // On .ended: do nothing — standard music-app behaviour is to wait for the user to press play.
        //   play() calls setActive(true) + engine restart so no action needed here.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let typeVal = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeVal),
                  type == .began
            else { return }
            self.stopSchedulerOnly()
            self.onAudioInterrupted?()
        }

        // routeChangeNotification fires when headphones connect or disconnect.
        // Headphones pulled (.oldDeviceUnavailable): stop playback and restart the engine for the
        // new output route — iOS silences audio in this case, so running silently is pointless.
        // New device (.newDeviceAvailable): keep playing, just re-enumerate the output route.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let reasonVal = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonVal)
            else { return }
            switch reason {
            case .oldDeviceUnavailable:
                // Headphones pulled — stop scheduler (don't touch session, restartAudio re-arms it)
                self.stopSchedulerOnly()
                self.onAudioInterrupted?()
                self.restartAudio()
            case .newDeviceAvailable:
                self.restartAudio()
            default:
                break
            }
        }
        #endif
    }

    // MARK: - Public API

    func load(_ state: SongState) {
        songState = state
        approachingEndFired = false
        outroStartFired     = false
        activeVisualizerNotes = []
        buildStepEventMap(state: state)
        // Cancel any in-progress note fades before restoring volumes.
        stopAmbientNoteFades()
        stopAmbientOutroFade()
        // Restore volumes that any in-progress intro/outro fade may have left at non-unity values.
        samplers[kTrackBass].volume = trackBaseVolume[kTrackBass]
        samplers[kTrackPads].volume = trackBaseVolume[kTrackPads]
        boosts[kTrackBass].outputVolume = 1.0
        boosts[kTrackPads].outputVolume = 1.0
        engine.mainMixerNode.outputVolume = 1.0
        applyStaticPans()
        // Restore Lead 1 delay if a previous X-Files block was interrupted before its end step.
        if xFilesDelayWasEnabled {
            setEffect(.delay, enabled: true, forTrack: kTrackLead1)
            xFilesDelayWasEnabled = false
        }
        xFilesDelayBlockRange = state.ambientXFilesBlockRange
        // Re-apply mute/solo: the explicit bass/pads volume resets above would undo any
        // active solo state. Must come last so it wins over all the resets above.
        applyMuteState()
    }

    private func applyStaticPans() {
        // Track order: Lead1=0, Lead2=1, Pads=2, Rhythm=3, Texture=4, Bass=5, Drums=6
        if kosmicStyle {
            trackStaticPan = [-0.15, 0.15, 0, 0.22, -0.22, 0, 0, 0]   // LeadSynth: centre
        } else if motorikStyle {
            // Pads and Rhythm panned for separation; Texture rarely used so stays centre
            trackStaticPan = [-0.07, 0.07, -0.20, 0.20, 0, 0, 0, 0]
        } else {
            trackStaticPan = [0, 0, 0, 0, 0, 0, 0, 0]   // Ambient: no static spread
        }
        for i in 0..<boosts.count {
            boosts[i].pan = trackStaticPan[i]
        }
    }

    private func buildStepEventMap(state: SongState) {
        var map:    [Int: [(Int, MIDIEvent)]] = [:]
        var offMap: [Int: [(Int, UInt8)]]    = [:]
        for trackIndex in 0..<kTrackCount {
            for ev in state.events(forTrack: trackIndex) {
                map[ev.stepIndex, default: []].append((trackIndex, ev))
                offMap[ev.stepIndex + ev.durationSteps, default: []].append((trackIndex, ev.note))
            }
        }
        // Sync to stepTimerQueue so the assignment can't race with an in-flight onStep read.
        // The timer fires on stepTimerQueue (serial), so this sync waits for any running
        // tick to finish before writing, and blocks the timer until both writes are done.
        stepTimerQueue.sync {
            stepEventMap = map
            noteOffMap   = offMap
        }
    }

    func play() {
        guard !isPlaying, let state = songState else { return }
        #if os(iOS)
        // Re-activate the session (deactivated by the previous stop()) and restart the engine
        // if it was suspended when the session deactivated. setActive must precede engine.start().
        try? AVAudioSession.sharedInstance().setActive(true)
        if !engine.isRunning { startEngine() }
        #endif
        // Resume from current playhead position (currentStep already set correctly)
        isPlaying = true
        currentSchedulerID += 1
        let schedulerID = currentSchedulerID

        if kosmicStyle && currentStep == 0 {
            // Zero volumes first, then delay the scheduler start.
            // AVAudioMixerNode.outputVolume has ~1 render-cycle latency (~10 ms) before the
            // render thread sees the new value. Without the delay, the scheduler fires step-0
            // notes immediately and the first render cycle executes at the old volume (1.0),
            // producing the audible startup pop. Waiting 50 ms guarantees at least one full
            // render cycle passes at volume=0 before any note reaches the audio graph.
            boosts[kTrackBass].outputVolume = 0.0
            boosts[kTrackPads].outputVolume = 0.0
            engine.mainMixerNode.outputVolume = 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.050) { [weak self] in
                guard let self, self.isPlaying, self.currentSchedulerID == schedulerID else { return }
                let sched = StepScheduler(engine: self, songState: state, startStep: 0, schedulerID: schedulerID)
                self.scheduler = sched
                sched.start()
                self.startKosmicDroneFades(state: state)
            }
        } else if (motorikStyle || chillFade) && currentStep == 0 && state.structure.introSection != nil {
            // Same pop-prevention as Kosmic: zero master before first note fires.
            engine.mainMixerNode.outputVolume = 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.050) { [weak self] in
                guard let self, self.isPlaying, self.currentSchedulerID == schedulerID else { return }
                let sched = StepScheduler(engine: self, songState: state, startStep: 0, schedulerID: schedulerID)
                self.scheduler = sched
                sched.start()
                self.startMotorikFades(state: state)
            }
        } else {
            // Ambient: start with boost at 0 from the top so the first note fades in cleanly.
            if ambientMode && currentStep == 0 {
                boosts[kTrackBass].outputVolume = 0.0
                boosts[kTrackPads].outputVolume = 0.0
            }
            // Chill pads: same — start silent so the first pad note fades in rather than snapping on.
            if chillPadsMode && currentStep == 0 {
                boosts[kTrackPads].outputVolume = 0.0
            }
            let sched = StepScheduler(engine: self, songState: state, startStep: currentStep, schedulerID: schedulerID)
            scheduler = sched
            sched.start()
            if kosmicStyle              { startKosmicDroneFades(state: state) }
            if motorikStyle || chillFade { startMotorikFades(state: state) }
            if ambientMode               { startAmbientOutroFade(state: state, schedulerID: currentSchedulerID) }
        }
    }

    func stop() {
        stopSchedulerOnly()
        // AVAudioSession stays active — deactivating it on every Stop button press suspends
        // the engine and can clear AUSampler soundbank state, causing silence on the next Play.
        // The session is only deactivated by the OS when another app takes audio focus
        // (interruptionNotification .began), which is the correct trigger.
    }

    /// Stop the scheduler and clean up playback state without touching the AVAudioSession.
    /// Used by system-driven stop paths (interruption, headphone pull, route change) where
    /// the session is already deactivated by iOS — calling setActive(false) there is wrong.
    private func stopSchedulerOnly() {
        scheduler?.stop()
        scheduler = nil
        isPlaying = false
        // Leave playhead in place — user can resume from here with Play
        allNotesOff()
        stopKosmicDroneFades()
        stopMotorikFades()
        stopAmbientNoteFades()
        stopAmbientOutroFade()
        // Clear reverb/delay buffers so tails don't bleed through when volume
        // is restored for the next song — applies to all styles.
        for rev in reverbs { rev.reset() }
        for del in delays  { del.reset() }
    }

    /// Stop and restart the AVAudioEngine so it re-enumerates the output device.
    /// Call this when the user connects or disconnects headphones or Bluetooth audio.
    func restartAudio() {
        allNotesOff()
        #if os(iOS)
        // Capture playing state before stopping — beginBatchLoad() inside
        // applyCurrentInstrumentsToPlayback() checks engine.isRunning, but the engine
        // is already stopped here, so it returns false and endBatchLoad() is never called.
        // We restart the engine ourselves below if playback was active.
        let wasPlaying = isPlaying
        #endif
        engine.stop()
        currentProgram    = Array(repeating: 255, count: kTrackCount)
        currentBankMSB    = Array(repeating: 0,   count: kTrackCount)
        cachedDrumProgram = 255
        #if !os(iOS)
        // macOS: start now; setProgram() works with the engine running.
        startEngine()
        #endif
        onAudioEngineRestarted?()
        #if os(iOS)
        // iOS: restart the engine after instruments are loaded if we were playing.
        // (.oldDeviceUnavailable calls stopSchedulerOnly() first → isPlaying = false
        //  → stays stopped so the user must press Play to resume through the speaker.
        //  .newDeviceAvailable while playing → wasPlaying = true → restarts here.)
        if wasPlaying { startEngine() }
        #endif
    }

    /// Clears the loaded-program dedup cache so the next setProgram() call for every
    /// track forces a fresh loadSoundBankInstrument(), regardless of the previous program.
    /// Called on iOS before applyCurrentInstrumentsToPlayback() so that route-change engine
    /// restarts (which reset AUSampler state) are followed by a full reload of all tracks.
    func invalidateProgramCache() {
        currentProgram    = Array(repeating: 255, count: kTrackCount)
        currentBankMSB    = Array(repeating: 0,   count: kTrackCount)
        cachedDrumProgram = 255
    }

    /// Stop the engine once before a batch of setProgram() calls.
    /// On iOS, loadSoundBankInstrument() must be called while the engine is stopped to
    /// commit the soundbank — calling it while running appears to succeed but produces silence.
    /// Returns true if the engine was running and was stopped; false if already stopped.
    /// Caller must call endBatchLoad() only when this returns true.
    @discardableResult
    func beginBatchLoad() -> Bool {
        guard engine.isRunning else { return false }
        engine.stop()
        return true
    }

    /// Restart the engine after a batch of setProgram() calls initiated by beginBatchLoad().
    /// startEngine() activates the AVAudioSession before engine.start() so the engine opens
    /// onto a live audio route, not a null one.
    func endBatchLoad() {
        startEngine()
    }

    /// Resets the playhead to bar 1 without requiring a loaded song.
    func resetPlayhead() {
        currentStep = 0
        currentBar  = 0
        activeVisualizerNotes = []
    }

    // MARK: - Step callback (called by StepScheduler on a background queue)

    /// Thread-safe snapshot of the audio engine's last render time.
    /// StepScheduler reads this on the timer thread to anchor step deadlines
    /// to the audio hardware crystal clock rather than to mach_absolute_time alone.
    nonisolated var lastRenderTime: AVAudioTime? { engine.outputNode.lastRenderTime }

    nonisolated func onStep(_ step: Int, bar: Int, schedulerID: Int) {
        guard currentSchedulerID == schedulerID else { return }
        // Bind both maps once — eliminates 4 redundant re-lookups in the main.async block.
        let noteOffs = noteOffMap[step]   ?? []
        let noteOns  = stepEventMap[step] ?? []
        // Fire note-offs first — pre-computed at load time, no asyncAfter allocations.
        // Chill Pads note-offs are deferred: stopNote fires after the boost fade-out completes
        // (see main.async block below), so the audio has time to fade before the note cuts.
        for (trackIndex, note) in noteOffs {
            if chillPadsMode && trackIndex == kTrackPads { continue }
            samplers[trackIndex].stopNote(note, onChannel: gmChannel(trackIndex))
        }
        // Fire note-ons — AVAudioUnitSampler.startNote() is thread-safe.
        for (trackIndex, ev) in noteOns {
            let channel = gmChannel(trackIndex)
            // Machine Kit (GM program 24) has harsh kick/snare at full velocity — scale down
            let fireVelocity: UInt8
            if trackIndex == kTrackDrums && cachedDrumProgram == 24 {
                fireVelocity = UInt8(max(1, Int(ev.velocity) * 78 / 100))
            } else {
                fireVelocity = ev.velocity
            }
            samplers[trackIndex].startNote(ev.note, withVelocity: fireVelocity, onChannel: channel)
        }
        // Minimal main-actor hop: update @Published playhead and handle X-Files delay mute.
        // Ambient fade loops are skipped on silent steps (~75% of steps have no events).
        let hasEvents = !noteOffs.isEmpty || !noteOns.isEmpty
        DispatchQueue.main.async { [weak self] in
            guard let self, self.currentSchedulerID == schedulerID else { return }
            self.currentStep = step
            if bar != self.currentBar { self.currentBar = bar }
            // Visualizer note spawning — append new notes, prune expired every 16 steps
            if !noteOns.isEmpty {
                let now = Date()
                self.activeVisualizerNotes.append(contentsOf: noteOns.map { (trackIdx, ev) in
                    VisualizerNote(trackIndex: trackIdx, note: ev.note,
                                   velocity: ev.velocity, birthDate: now,
                                   durationSteps: ev.durationSteps)
                })
                // Cap at 80 entries — dense songs can accumulate 200+ orbs; oldest are
                // already nearly transparent (cosine fade) so dropping them is imperceptible.
                if self.activeVisualizerNotes.count > 80 {
                    self.activeVisualizerNotes.removeFirst(self.activeVisualizerNotes.count - 80)
                }
            }
            if step % 4 == 0 {
                let cutoff = Date().addingTimeInterval(-8.0)  // max orb lifetime is 7s
                self.activeVisualizerNotes.removeAll { $0.birthDate < cutoff }
            }
            // Ambient per-note attack/decay: fade boost up on note-on, down on note-off.
            // Attack duration = min(500ms, noteDuration/3) so short notes still sound.
            // The chosen duration is stored per-track and reused for the matching note-off.
            if hasEvents, self.ambientMode {
                // sps is constant for the life of a song; computed here so silent steps skip it.
                let sps = self.songState?.frame.secondsPerStep ?? 0.1
                for (trackIndex, ev) in noteOns {
                    if trackIndex == kTrackBass || trackIndex == kTrackPads {
                        let noteSecs  = Double(ev.durationSteps) * sps
                        let fadeSecs  = min(0.5, max(0.03, noteSecs / 3.0))
                        let idx       = trackIndex == kTrackBass ? 0 : 1
                        self.ambientNoteFadeDuration[idx] = fadeSecs
                        self.startAmbientBoostFade(trackIndex: trackIndex, toVolume: 1.0, duration: fadeSecs)
                    }
                }
                for (trackIndex, _) in noteOffs {
                    if trackIndex == kTrackBass || trackIndex == kTrackPads {
                        let idx      = trackIndex == kTrackBass ? 0 : 1
                        let fadeSecs = self.ambientNoteFadeDuration[idx]
                        self.startAmbientBoostFade(trackIndex: trackIndex, toVolume: 0.0, duration: fadeSecs)
                    }
                }
            }
            // Chill per-note pads fade: same boost-node ramp as Ambient, Pads track only.
            // Also resets sweep phase to bottom of cycle (filter fully closed) on each note-on,
            // so every chord starts dark and sweeps upward — then back down before it ends.
            if self.chillPadsMode {
                let sps = self.songState?.frame.secondsPerStep ?? 0.1
                for (trackIndex, ev) in noteOns {
                    if trackIndex == kTrackPads {
                        let noteSecs = Double(ev.durationSteps) * sps
                        let fadeSecs = min(1.0, max(0.1, noteSecs / 4.0))
                        self.ambientNoteFadeDuration[1] = fadeSecs
                        self.startAmbientBoostFade(trackIndex: kTrackPads, toVolume: 1.0, duration: fadeSecs)
                        // Sync sweep to chord: reset phase to -π/2 so filter starts at 300 Hz (fully closed)
                        // and sweeps open naturally over the chord duration.
                        if self.sweepEnabled[kTrackPads] {
                            self.sweepPhase[kTrackPads] = -1.5708
                        }
                    }
                }
                for (trackIndex, note) in noteOffs {
                    if trackIndex == kTrackPads {
                        let fadeSecs = self.ambientNoteFadeDuration[1]
                        self.startAmbientBoostFade(trackIndex: kTrackPads, toVolume: 0.0, duration: fadeSecs)
                        // Defer stopNote until after the fade completes so the audio fades rather than cuts.
                        // Capture schedulerID so a stop/seek during the fade window cancels the stale stopNote.
                        let channel    = self.gmChannel(kTrackPads)
                        let capturedID = self.currentSchedulerID
                        DispatchQueue.main.asyncAfter(deadline: .now() + fadeSecs) { [weak self] in
                            guard let self, self.currentSchedulerID == capturedID else { return }
                            self.samplers[kTrackPads].stopNote(note, onChannel: channel)
                        }
                    }
                }
            }
            // Mute Lead 1 delay at block start; restore at block end (4 bars later).
            if let range = self.xFilesDelayBlockRange {
                if step == range.lowerBound {
                    self.xFilesDelayWasEnabled = !self.delays[kTrackLead1].auAudioUnit.shouldBypassEffect
                    if self.xFilesDelayWasEnabled {
                        self.setEffect(.delay, enabled: false, forTrack: kTrackLead1)
                    }
                } else if step == range.upperBound {
                    if self.xFilesDelayWasEnabled {
                        self.setEffect(.delay, enabled: true, forTrack: kTrackLead1)
                        self.xFilesDelayWasEnabled = false
                    }
                }
            }
            // Endless: fire approaching-end 8 bars before Outro starts (or immediately for short songs).
            // approachingEndFired resets on load() and seek() so it fires exactly once per song.
            if let cb = self.onApproachingEnd, !self.approachingEndFired,
               let state = self.songState {
                let totalBars  = state.frame.totalBars
                let outroStart = state.structure.outroSection?.startBar ?? totalBars
                let triggerStep = max(0, outroStart * 16 - 192)  // 12 bars = 192 steps
                if step >= triggerStep || (step == 0 && totalBars < 16) {
                    self.approachingEndFired = true
                    cb()
                }
            }
            // Evolve: fire once when playhead first reaches the Outro section start.
            if let cb = self.onOutroStart, !self.outroStartFired,
               let outroBar = self.songState?.structure.outroSection?.startBar,
               bar >= outroBar {
                self.outroStartFired = true
                cb()
            }
        }
    }

    // Called by StepScheduler when song ends — leave playhead at end position so
    // atLimit closures in HoldRepeater see the final bar and stop correctly.
    // AppState.play() detects the end position and rewinds to bar 1 before playing.
    nonisolated func onSongEnd() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.scheduler?.stop()
            self.scheduler = nil
            self.isPlaying = false
            // Keep currentStep / currentBar at their last-set values (end of song)
            self.allNotesOff()
            self.stopKosmicDroneFades()
            self.stopMotorikFades()
            self.stopAmbientNoteFades()
            self.stopAmbientOutroFade()
            self.onSongEndNaturally?()
        }
    }

    // MARK: - Seek (restart scheduler from a new position)

    func seek(toStep newStep: Int) {
        guard let state = songState else { return }
        let totalSteps = state.frame.totalBars * 16
        let clampedStep = max(0, min(newStep, totalSteps - 1))
        approachingEndFired = false
        outroStartFired     = false
        if isPlaying {
            scheduler?.stop()
            scheduler = nil
            allNotesOff()
            stopKosmicDroneFades()
            stopMotorikFades()
            stopAmbientNoteFades()
            stopAmbientOutroFade()
            currentStep = clampedStep
            currentBar  = clampedStep / 16
            currentSchedulerID += 1
            let sched = StepScheduler(engine: self, songState: state, startStep: clampedStep, schedulerID: currentSchedulerID)
            scheduler = sched
            sched.start()
            if kosmicStyle               { startKosmicDroneFades(state: state) }
            if motorikStyle || chillFade { startMotorikFades(state: state) }
            if ambientMode               { startAmbientOutroFade(state: state, schedulerID: currentSchedulerID) }
        } else {
            currentStep = clampedStep
            currentBar  = clampedStep / 16
        }
    }

    // MARK: - Real-time tempo change

    /// Updates the step-timer interval to match a new BPM without restarting the song.
    /// If playing, the current scheduler is swapped out from the current playhead position.
    func setTempo(_ bpm: Int) {
        guard let state = songState else { return }
        let newFrame = state.frame.withTempo(bpm)
        songState = state.withFrame(newFrame)
        guard isPlaying else { return }
        scheduler?.stop()
        scheduler = nil
        allNotesOff()
        currentSchedulerID += 1
        let sched = StepScheduler(engine: self, songState: songState!, startStep: currentStep, schedulerID: currentSchedulerID)
        scheduler = sched
        sched.start()
    }

    // MARK: - Evolve pass swap

    /// Hot-swap to an Evolve pass state without resetting audio effects or volumes.
    /// Stops the current scheduler, rebuilds the step-event map atomically, and restarts
    /// from bar 0 using the pass state's shorter totalBars. Called on main actor.
    func switchToPass(_ passState: SongState) {
        songState           = passState
        approachingEndFired = false
        outroStartFired     = false
        scheduler?.stop()
        scheduler = nil
        allNotesOff()
        buildStepEventMap(state: passState)
        currentStep = 0
        currentBar  = 0
        activeVisualizerNotes = []
        currentSchedulerID += 1
        // Always restart — switchToPass is called mid-Evolve; onSongEnd sets isPlaying=false
        // before the callback fires, so we can't rely on that flag here.
        isPlaying = true
        let sched = StepScheduler(engine: self, songState: passState,
                                  startStep: 0, schedulerID: currentSchedulerID)
        scheduler = sched
        sched.start()
    }

    /// Loads a new SongState and immediately starts playing from `startStep`.
    /// Used by Evolve mode to extend the display mid-song without resetting to bar 0.
    /// Always restarts the scheduler regardless of current isPlaying state.
    func loadAndPlay(state: SongState, fromStep startStep: Int) {
        songState           = state
        approachingEndFired = false
        outroStartFired     = false
        scheduler?.stop()
        scheduler = nil
        allNotesOff()
        stopKosmicDroneFades()
        stopMotorikFades()
        stopAmbientNoteFades()
        stopAmbientOutroFade()
        buildStepEventMap(state: state)
        let totalSteps = state.frame.totalBars * 16
        currentStep = max(0, min(startStep, totalSteps - 1))
        currentBar  = currentStep / 16
        currentSchedulerID += 1
        isPlaying = true
        let sched = StepScheduler(engine: self, songState: state, startStep: currentStep,
                                  schedulerID: currentSchedulerID)
        scheduler = sched
        sched.start()
        // Pass states have no intro/outro — set volume directly to full.
        engine.mainMixerNode.outputVolume = 1.0
    }

    // MARK: - Instrument program change (called from TrackRowView via AppState)

    // Cache the currently-loaded program per sampler to skip redundant loadSoundBankInstrument
    // calls. loadSoundBankInstrument is expensive (SF2 parse + audio buffer alloc), and
    // TrackRowView always resets to program index 0 on generate — the same program every time.
    private var currentProgram: [UInt8] = Array(repeating: 255, count: kTrackCount)   // 255 = "not yet loaded"
    private var currentBankMSB: [UInt8] = Array(repeating: 0,   count: kTrackCount)
    // Cached drum program for nonisolated onStep (written on main actor in setProgram, read from timer thread)
    nonisolated(unsafe) private var cachedDrumProgram: UInt8 = 255

    func setProgram(_ program: UInt8, forTrack trackIndex: Int) {
        guard trackIndex < samplers.count else { return }
        let isDrum = (trackIndex == kTrackDrums)
        let bankMSB: UInt8 = isDrum ? 0x78 : 0x79
        // Skip if the sampler already has this exact program loaded
        if program == currentProgram[trackIndex] && bankMSB == currentBankMSB[trackIndex] { return }
        currentProgram[trackIndex] = program
        currentBankMSB[trackIndex] = bankMSB
        if trackIndex == kTrackDrums { cachedDrumProgram = program }
        try? samplers[trackIndex].loadSoundBankInstrument(
            at: gmDLSSoundBankURL(), program: program, bankMSB: bankMSB, bankLSB: 0
        )
        // Per-track default volumes; tremolo overrides this via LFO
        if !tremEnabled[trackIndex] {
            let vol: Float
            if trackIndex == kTrackLead1 && program == 59 {
                vol = 1.3    // Muted Trumpet runs soft in GM — boost for presence
            } else if trackIndex == kTrackLead2 && program == 11 {
                vol = 1.45   // Vibraphone runs soft in GM — boost for presence
            } else if trackIndex == kTrackLead1 && program == 81 {
                vol = 0.88   // Mono Synth slightly hot on Lead 1 — trim
            } else if trackIndex == kTrackLead1 && program == 80 {
                vol = 0.78   // Square Lead on Lead 1
            } else if trackIndex == kTrackBass && kosmicStyle && program == 87 {
                vol = 0.40   // Lead Bass runs hot on Kosmic bass — pull back further
            } else if trackIndex == kTrackBass && program == 87 {
                vol = 0.56   // Lead Bass runs hot
            } else if trackIndex == kTrackLead2 && program == 0 {
                vol = 1.4    // Grand Piano runs soft in GM
            } else if trackIndex == kTrackLead2 && program == 8 {
                vol = 1.8    // Celesta runs soft in GM
            } else if trackIndex == kTrackLead2 && program == 99 {
                vol = 2.0    // FX Atmosphere runs very soft in GM
            } else if trackIndex == kTrackTexture && (program == 90 || program == 86) {
                vol = 0.85   // Pad 3 Poly (90) and Fifths Lead (86) run loud — pull back
            } else if trackIndex == kTrackTexture && kosmicStyle && program == 99 {
                vol = 3.2    // FX Atmosphere very soft on Kosmic Texture — boost more
            } else if trackIndex == kTrackTexture && ambientMode && program == 99 {
                vol = 4.0    // FX Atmosphere very soft on Ambient Texture — boost more
            } else if trackIndex == kTrackTexture && program == 99 {
                vol = 2.6    // FX Atmosphere runs very soft on Texture — boost
            } else if trackIndex == kTrackPads && chillPadsMode && program == 89 {
                vol = 0.75   // Warm Pad runs hot on Chill Pads — pull back
            } else if trackIndex == kTrackTexture && program == 89 {
                vol = 0.9    // Warm Pad runs loud on Texture — pull back
            } else if trackIndex == kTrackTexture && ambientMode {
                vol = 2.0    // Ambient Texture instruments run soft — boost
            } else if trackIndex == kTrackTexture {
                vol = 1.4    // Texture pads are quiet
            } else if trackIndex == kTrackDrums && ambientMode {
                vol = 2.2    // Drums sit under heavy Ambient reverb — boost so they're audible
            } else if trackIndex == kTrackRhythm && chillPadsMode && program == 4 {
                vol = 1.6    // Rhodes runs soft in GM — boost for Chill rhythm presence
            } else if trackIndex == kTrackRhythm && chillPadsMode && program == 5 {
                vol = 0.75   // Wurlitzer runs hot on Chill rhythm — pull back
            } else if trackIndex == kTrackRhythm && chillPadsMode && program == 17 {
                vol = 0.75   // B3 Organ runs hot on Chill rhythm — pull back
            } else if trackIndex == kTrackBass && kosmicStyle && program == 81 {
                vol = 0.48   // Mono Synth runs hot on Kosmic bass — pull back more
            } else if trackIndex == kTrackLead2 && ambientMode && program == 8 {
                vol = 1.6    // Celesta runs soft on Ambient Lead 2 — boost for presence
            } else if trackIndex == kTrackLead2 && chillPadsMode {
                vol = 1.25   // Chill Lead 2 instruments run soft — boost for presence
            } else if trackIndex == kTrackLead2 && motorikStyle && program == 39 {
                vol = 1.8    // Minimoog runs soft on Lead 2 — boost
            } else if trackIndex == kTrackRhythm && motorikStyle && program == 29 {
                vol = 0.75   // Fuzz Guitar runs hot on Motorik rhythm — pull back
            } else if trackIndex == kTrackRhythm && kosmicStyle && program == 5 {
                vol = 0.55   // Wurlitzer runs hot on Kosmic rhythm — pull back
            } else if trackIndex == kTrackRhythm && kosmicStyle {
                vol = 0.75   // Kosmic arpeggio runs hot and overpowers leads — pull back
            } else {
                vol = 1.0
            }
            trackBaseVolume[trackIndex] = vol
            samplers[trackIndex].volume = vol
        }
        // Re-apply mute/solo state — loadSoundBankInstrument resets the sampler node
        applyMuteState()
    }

    /// Returns the most recently CONFIRMED loaded program for a track (255 = never successfully loaded).
    /// Used by AppState to detect whether a style-specific instrument loaded correctly.
    func loadedProgram(forTrack trackIndex: Int) -> UInt8 {
        guard trackIndex < currentProgram.count else { return 255 }
        return currentProgram[trackIndex]
    }

    // MARK: - Ambient mode configuration

    /// Call before defaultsResetToken fires so all subsequent setEffect calls use Ambient values.
    func setAmbientMode(_ enabled: Bool) {
        ambientMode = enabled
        if !enabled {
            // Restore HPF bypass for all tracks when leaving Ambient mode
            for i in 0..<lowEQs.count { lowEQs[i].bands[1].bypass = true }
            return
        }
        // Set per-track reverb presets for Ambient
        let atmosphericTracks: Set<Int> = [kTrackLead1, kTrackLead2, kTrackPads, kTrackTexture]
        for i in 0..<reverbs.count {
            if i == kTrackDrums {
                reverbs[i].loadFactoryPreset(.plate)
            } else if atmosphericTracks.contains(i) {
                reverbs[i].loadFactoryPreset(.cathedral)
            } else {
                reverbs[i].loadFactoryPreset(.largeChamber)
            }
        }
        // Set Ambient delay times based on current song tempo
        let tempo = songState?.frame.tempo ?? 75
        let beatSecs = 60.0 / Double(tempo)
        for i in 0..<delays.count {
            guard i < ambientDelayBeats.count && ambientDelayWet[i] >= 0 else { continue }
            delays[i].delayTime     = Swift.min(2.0, beatSecs * ambientDelayBeats[i])
            delays[i].feedback      = ambientDelayFeedback[i]
            delays[i].lowPassCutoff = ambientDelayLowpass[i]
        }
        // Enable HPF (250 Hz) on Lead and Texture to prevent reverb low-end muddiness
        let hpfTracks: Set<Int> = [kTrackLead1, kTrackLead2, kTrackTexture]
        for i in 0..<lowEQs.count {
            lowEQs[i].bands[1].bypass = !hpfTracks.contains(i)
        }
    }

    /// Set Chill pads mode — enables per-note audio fade-in/fade-out on the Pads boost node.
    /// Call before defaultsResetToken fires, same as setAmbientMode.
    func setChillMode(_ enabled: Bool) {
        chillPadsMode = enabled
        if !enabled {
            stopAmbientNoteFades()  // reuse the same stop/cleanup as Ambient
            return
        }
        // Tempo-synced delay for Chill Lead 1 (dotted-quarter) and Lead 2 (quarter note).
        // Without this, both tracks default to the init value of 0.125 s (fixed 16th-note).
        let tempo    = songState?.frame.tempo ?? 80
        let beatSecs = 60.0 / Double(tempo)
        delays[kTrackLead1].delayTime     = Swift.min(2.0, beatSecs * 0.75)  // dotted-quarter
        delays[kTrackLead1].feedback      = 55
        delays[kTrackLead1].lowPassCutoff = 5000
        delays[kTrackLead2].delayTime     = Swift.min(2.0, beatSecs * 0.5)   // quarter note
        delays[kTrackLead2].feedback      = 40
        delays[kTrackLead2].lowPassCutoff = 5500
    }

    // MARK: - Per-track effect toggle

    func setEffect(_ effect: TrackEffect, enabled: Bool, forTrack trackIndex: Int) {
        guard trackIndex < samplers.count else { return }
        switch effect {
        case .boost:
            boosts[trackIndex].outputVolume = enabled ? 1.7 : 1.0  // 1.7 ≈ +4.6 dB
        case .delay:
            delays[trackIndex].auAudioUnit.shouldBypassEffect = !enabled
            if ambientMode, trackIndex < ambientDelayWet.count, ambientDelayWet[trackIndex] >= 0 {
                delays[trackIndex].wetDryMix = enabled ? ambientDelayWet[trackIndex] : 0
            } else {
                delays[trackIndex].wetDryMix = enabled ? 40 : 0
            }
        case .sweep:
            if enabled { startSweep(forTrack: trackIndex) }
            else       { stopSweep(forTrack: trackIndex) }
        case .pan:
            if enabled {
                let hz: Double
                if ambientMode && trackIndex == kTrackTexture {
                    // 1 full sweep per 4 bars: hz = tempo / (4 bars × 4 beats × 60 s/min)
                    let bpm = Double(songState?.frame.tempo ?? 75)
                    hz = bpm / 960.0   // e.g. 75 BPM → 0.078 Hz → ~12.8s per sweep
                } else {
                    hz = 0.5
                }
                startPan(forTrack: trackIndex, hz: hz)
            } else { stopPan(forTrack: trackIndex) }
        case .tremolo:
            if enabled { startTremolo(forTrack: trackIndex) }
            else       { stopTremolo(forTrack: trackIndex) }
        case .compression:
            comps[trackIndex].auAudioUnit.shouldBypassEffect = !enabled
        case .lowShelf:
            lowEQs[trackIndex].auAudioUnit.shouldBypassEffect = !enabled
        case .reverb:
            reverbs[trackIndex].auAudioUnit.shouldBypassEffect = !enabled
            let wet: Float = ambientMode && trackIndex < ambientReverbWet.count
                ? ambientReverbWet[trackIndex] : 50
            reverbs[trackIndex].wetDryMix = enabled ? wet : 0
        case .space:
            reverbs[trackIndex].auAudioUnit.shouldBypassEffect = !enabled
            let wet: Float = ambientMode && trackIndex < ambientReverbWet.count
                ? ambientReverbWet[trackIndex]
                : (chillPadsMode ? 55 : 70)
            reverbs[trackIndex].wetDryMix = enabled ? wet : 0
        }
    }

    // MARK: - Shared LFO timer
    // One 16ms DispatchSource drives all tremolo/sweep/pan updates.
    // Tremolo updates every tick (60fps); sweep and pan every 3rd tick (~20fps).
    // One DispatchQueue.main.async dispatch per 16ms regardless of how many effects are active.

    private func startSharedLFO() {
        guard lfoTimer == nil else { return }
        lfoTickCount = 0
        let src = DispatchSource.makeTimerSource(queue: lfoQueue)
        src.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))
        src.setEventHandler { [weak self] in
            self?.lfoTick()
        }
        src.resume()
        lfoTimer = src
    }

    private func stopSharedLFOIfIdle() {
        let anyActive = tremEnabled.contains(true) || sweepEnabled.contains(true)
                     || panEnabled.contains(true)  || kosmicIntroSweepActive || kosmicIntroBassPanActive
        guard !anyActive else { return }
        lfoTimer?.cancel()
        lfoTimer     = nil
        lfoTickCount = 0
    }

    private func lfoTick() {
        // Skip all work if no effect is currently running — handles the brief window
        // between an effect being disabled and the timer being cancelled.
        guard tremEnabled.contains(true) || sweepEnabled.contains(true)
           || panEnabled.contains(true) || kosmicIntroSweepActive || kosmicIntroBassPanActive
           || globalSweepTicksRemaining > 0
        else { return }

        lfoTickCount += 1
        let do20fps   = (lfoTickCount % 3 == 0)
        let anySolo   = anySoloActive

        // Tremolo — 60fps for fast tremolos (≥2 Hz), 20fps for slow swells (<2 Hz, e.g. Chill/Ambient pads at 0.15 Hz)
        for i in 0..<kTrackCount where tremEnabled[i] {
            if !do20fps && tremPhaseInc[i] < 0.1 { continue }
            tremPhase[i] += tremPhaseInc[i]
            let muted = muteState[i] || (anySolo && !soloState[i])
            let tremVol = Float(1.0 - Double(tremDepth[i]) * (1.0 + sin(tremPhase[i])))
            samplers[i].volume = muted ? 0.0 : tremVol
        }

        guard do20fps else { return }

        // Sweep — ~20fps, all active tracks (skipped for tracks overridden by global sweep)
        for i in 0..<kTrackCount where sweepEnabled[i] && globalSweepTicksRemaining == 0 {
            sweepPhase[i] += 0.02199  // 2π × 0.07 Hz / 20 fps
            let cutoff = Float(300 + 1600 * (1 + sin(sweepPhase[i])))
            AudioUnitSetParameter(sweepFilters[i].audioUnit, 0, kAudioUnitScope_Global, 0, cutoff, 0)
        }

        // Global filter sweep (iPhone two-finger gesture) — one unified phase across all tracks
        if globalSweepTicksRemaining > 0 {
            globalSweepTicksRemaining -= 1
            globalSweepPhase += 0.052   // ~0.33 Hz → full open-close cycle in ~6 seconds
            let cutoff = Float(300 + 5700 * (1.0 + sin(globalSweepPhase)) / 2.0)
            for i in 0..<kTrackCount where i != kTrackDrums {
                AudioUnitSetParameter(sweepFilters[i].audioUnit, 0, kAudioUnitScope_Global, 0, cutoff, 0)
            }
            if globalSweepTicksRemaining == 0 {
                // Restore each track to its pre-sweep state and drop resonance back to static 3 dB
                for i in 0..<kTrackCount where i != kTrackDrums {
                    AudioUnitSetParameter(sweepFilters[i].audioUnit, 1, kAudioUnitScope_Global, 0, 3.0, 0) // restore from 10 dB
                    if preGlobalSweepEnabled[i] {
                        // Track had its own sweep running — let sweepEnabled[] loop resume next tick
                    } else {
                        sweepFilters[i].auAudioUnit.shouldBypassEffect = true
                        AudioUnitSetParameter(sweepFilters[i].audioUnit, 0, kAudioUnitScope_Global, 0, 6000, 0)
                    }
                }
            }
        }

        // Pan — ~20fps, all active tracks
        for i in 0..<kTrackCount where panEnabled[i] {
            panPhase[i] += panPhaseInc[i]
            boosts[i].pan = Float(sin(panPhase[i]))
        }

        // Kosmic hidden intro effects — ~20fps
        if kosmicIntroSweepActive {
            kosmicIntroSweepPhase += 0.02199
            let cutoff = Float(400 + 1400 * (1 + sin(kosmicIntroSweepPhase)))
            AudioUnitSetParameter(sweepFilters[kTrackPads].audioUnit,
                                  0, kAudioUnitScope_Global, 0, cutoff, 0)
        }
        if kosmicIntroBassPanActive {
            kosmicIntroBassPanPhase += 0.01571  // 2π × 0.05 Hz / 20 fps
            boosts[kTrackBass].pan = Float(0.5 * sin(kosmicIntroBassPanPhase))
        }
    }

    // MARK: - Tremolo LFO (6 Hz sine, 50% depth, main-queue timer)

    private func startTremolo(forTrack i: Int) {
        if (ambientMode || chillPadsMode) && i == kTrackPads {
            tremPhaseInc[i] = 0.015708   // 2π × 0.15 Hz / 60 fps — one swell per ~6.5 seconds
            tremDepth[i]    = 0.38       // 38% depth: volume swells 1.0 → 0.24, clearly audible
        } else {
            tremPhaseInc[i] = 0.8378     // 2π × 8 Hz / 60 fps
            tremDepth[i]    = 0.40
        }
        tremEnabled[i] = true
        tremPhase[i]   = 0.0
        startSharedLFO()
    }

    private func stopTremolo(forTrack i: Int) {
        tremEnabled[i] = false
        tremPhase[i]   = 0.0
        samplers[i].volume = trackBaseVolume[i]
        stopSharedLFOIfIdle()
    }

    // MARK: - Sweep LFO (0.07 Hz sine, cutoff 300–3500 Hz, slight resonance)
    // Ambient phase offsets: Lead1=0°, Lead2=90°, Pads=180°, Bass=270° — keeps all sweeps
    // permanently out of phase so the texture breathes rather than pumping as a single block.
    private let ambientSweepOffset: [Double] = [0.0, 1.5708, 3.1416, 0.0, 0.0, 4.7124, 0.0, 0.0]  // LeadSynth: 0°

    private func startSweep(forTrack i: Int) {
        sweepEnabled[i] = true
        sweepPhase[i]   = ambientMode ? ambientSweepOffset[i] : 0.0
        sweepFilters[i].auAudioUnit.shouldBypassEffect = false
        startSharedLFO()
    }

    private func stopSweep(forTrack i: Int) {
        sweepEnabled[i] = false
        sweepPhase[i]   = 0.0
        sweepFilters[i].auAudioUnit.shouldBypassEffect = true
        AudioUnitSetParameter(sweepFilters[i].audioUnit, 0, kAudioUnitScope_Global, 0, 6000, 0)
        stopSharedLFOIfIdle()
    }

    /// Triggers a global filter sweep across all non-drum tracks (~3 seconds, open→close→open).
    /// Re-triggerable — a second call restarts from fully open so the effect is always audible.
    /// Resonance is boosted to 15 dB during the sweep for a dramatic Moog-style wah character,
    /// then restored to the 3 dB static value when the sweep completes.
    func triggerGlobalFilterSweep() {
        preGlobalSweepEnabled = sweepEnabled
        globalSweepPhase = .pi / 2    // start at maximum cutoff (6000 Hz — fully open)
        globalSweepTicksRemaining = 60 // 60 × 50ms (20fps) ≈ 3 seconds (open → close → open)
        canvasFlashDate = Date()       // triggers canvas-wide white flash in VisualizerView
        for i in 0..<kTrackCount where i != kTrackDrums {
            sweepFilters[i].auAudioUnit.shouldBypassEffect = false
            // Boost resonance from 3 dB (static) to 10 dB for an audible resonant wah peak.
            // 15 dB caused EXC_BAD_ACCESS on the IO thread: the resonant peak (Q≈5.6) fed into
            // delay feedback loops (up to 65% in Ambient mode) producing ~16× signal accumulation
            // that overwhelmed the dynamics processor / reverb on the render thread.
            // 10 dB (Q≈3.2) is clearly audible and dramatic without blowing up the feedback chain.
            AudioUnitSetParameter(sweepFilters[i].audioUnit, 1, kAudioUnitScope_Global, 0, 10.0, 0)
        }
        startSharedLFO()
    }

    // MARK: - Pan LFO (sine, sweeps −1.0 to +1.0)
    // Default 0.5 Hz (~2s cycle); Ambient Texture uses 0.05 Hz (~20s cycle)

    private func startPan(forTrack i: Int, hz: Double = 0.5) {
        panEnabled[i]  = true
        panPhase[i]    = 0.0
        panPhaseInc[i] = 2.0 * Double.pi * hz / 20.0  // increment per 20fps tick
        startSharedLFO()
    }

    private func stopPan(forTrack i: Int) {
        panEnabled[i]  = false
        panPhase[i]    = 0.0
        panPhaseInc[i] = 0.0
        boosts[i].pan  = trackStaticPan[i]   // restore static position, not hard centre
        stopSharedLFOIfIdle()
    }

    // MARK: - Kosmic Drone Fade (intro/outro continuous note with boost volume ramp)
    // Uses boosts[kTrackBass/kTrackPads].outputVolume (separate from sampler mute volume).
    // Intro: 0 → 1 over the intro section duration.
    // Outro: 1 → 0 over the outro section duration.

    private func startKosmicDroneFades(state: SongState) {
        // Cancel timers only — do NOT call stopKosmicDroneFades(), which would flash
        // volumes to 1.0 right as notes begin and cause the startup pop.
        droneFadeTimers[0]?.cancel();   droneFadeTimers[0]   = nil
        droneFadeTimers[1]?.cancel();   droneFadeTimers[1]   = nil
        kosmicIntroFadeTimer?.cancel(); kosmicIntroFadeTimer  = nil
        bodyEntranceFadeTimer?.cancel(); bodyEntranceFadeTimer = nil
        stopKosmicIntroEffects()

        let schedulerID   = currentSchedulerID
        let intro         = state.structure.introSection
        let introEndStep  = (intro?.endBar ?? 0) * 16
        let inIntro       = intro != nil && currentStep < introEndStep

        // --- Volume setup: depends on where the playhead is ---
        if currentStep == 0, intro != nil {
            // Song start: zero everything; a master ramp + intro boost ramp will open audio.
            boosts[kTrackBass].outputVolume      = 0.0
            boosts[kTrackPads].outputVolume      = 0.0
            engine.mainMixerNode.outputVolume    = 0.0
            // Master mixer 0→1 over ~100 ms to absorb any DSP-init transient.
            for i in 1...5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.020) { [weak self] in
                    guard let self, self.currentSchedulerID == schedulerID else { return }
                    self.engine.mainMixerNode.outputVolume = Float(i) / 5.0
                }
            }
        } else if inIntro {
            // Mid-intro seek: jump to the proportional volume so the fade continues smoothly.
            let startProg = Float(currentStep) / Float(max(1, introEndStep))
            boosts[kTrackBass].outputVolume   = startProg
            boosts[kTrackPads].outputVolume   = startProg
            engine.mainMixerNode.outputVolume = 1.0
        } else {
            // Body or outro seek: full volume immediately — no ramp.
            boosts[kTrackBass].outputVolume   = 1.0
            boosts[kTrackPads].outputVolume   = 1.0
            engine.mainMixerNode.outputVolume = 1.0
        }

        // Intro effects (Cathedral reverb, sweep LFO) only while playhead is in the intro.
        if inIntro { startKosmicIntroEffects() }

        // --- Intro boost ramp (only when playhead is inside the intro) ---
        if inIntro, let intro = intro {
            let startProg    = (currentStep == 0) ? Float(0) : Float(currentStep) / Float(max(1, introEndStep))
            let remSteps     = max(1, introEndStep - currentStep)
            let durationSecs = Double(remSteps) * state.frame.secondsPerStep
            let startNanos   = DispatchTime.now().uptimeNanoseconds

            let fadeSrc = DispatchSource.makeTimerSource(queue: .main)
            fadeSrc.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
            fadeSrc.setEventHandler { [weak self] in
                guard let self, self.currentSchedulerID == schedulerID else { return }
                let elapsed  = Double(DispatchTime.now().uptimeNanoseconds - startNanos) / 1_000_000_000.0
                let fraction = Float(min(1.0, elapsed / max(0.001, durationSecs)))
                let progress = startProg + fraction * (1.0 - startProg)
                let anySolo  = self.anySoloActive
                let bassMuted = self.muteState[kTrackBass] || (anySolo && !self.soloState[kTrackBass])
                let padsMuted = self.muteState[kTrackPads] || (anySolo && !self.soloState[kTrackPads])
                self.boosts[kTrackBass].outputVolume = bassMuted ? 0.0 : progress
                self.boosts[kTrackPads].outputVolume = padsMuted ? 0.0 : progress
                if progress >= 1.0 {
                    self.kosmicIntroFadeTimer?.cancel()
                    self.kosmicIntroFadeTimer = nil
                }
            }
            fadeSrc.resume()
            kosmicIntroFadeTimer = fadeSrc

            // At body boundary: stop intro effects and start body entrance fade.
            let stepsUntilBody = max(0, introEndStep - currentStep)
            let delayToBody    = Double(stepsUntilBody) * state.frame.secondsPerStep
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delayToBody) {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.isPlaying, self.currentSchedulerID == schedulerID else { return }
                    self.stopKosmicIntroEffects()
                    self.startBodyEntranceFade(state: state, schedulerID: schedulerID)
                }
            }
        }

        startOutroDroneFade(state: state, schedulerID: schedulerID)
    }

    private func startOutroDroneFade(state: SongState, schedulerID: Int) {
        guard let outro = state.structure.outroSection else { return }
        let outroStartStep = outro.startBar * 16
        let outroEndStep   = outro.endBar   * 16
        let totalSteps     = outroEndStep - outroStartStep
        guard totalSteps > 0, currentStep < outroEndStep else { return }

        let sps             = state.frame.secondsPerStep
        let stepsUntilStart = max(0, outroStartStep - currentStep)
        let delaySeconds    = Double(stepsUntilStart) * sps

        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isPlaying, self.currentSchedulerID == schedulerID else { return }
                guard self.droneFadeTimers[1] == nil else { return }

                let elapsedInOutro = max(0, self.currentStep - outroStartStep)
                let startProgress  = Float(1.0 - Double(elapsedInOutro) / Double(totalSteps))
                let remainingSecs  = Double(totalSteps - elapsedInOutro) * sps
                let startNanos     = DispatchTime.now().uptimeNanoseconds

                self.boosts[kTrackBass].outputVolume = startProgress
                self.boosts[kTrackPads].outputVolume = startProgress
                self.startKosmicIntroEffects()

                let src = DispatchSource.makeTimerSource(queue: .main)
                src.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
                src.setEventHandler { [weak self] in
                    guard let self, self.currentSchedulerID == schedulerID else { return }
                    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startNanos) / 1_000_000_000.0
                    let linearFade = Float(max(0.0, 1.0 - elapsed / max(0.001, remainingSecs)))
                    let vol = startProgress * linearFade
                    let anySolo = self.anySoloActive
                    for trackIdx in [kTrackBass, kTrackPads] {
                        let muted = self.muteState[trackIdx] || (anySolo && !self.soloState[trackIdx])
                        self.boosts[trackIdx].outputVolume = muted ? 0.0 : vol
                    }
                    if linearFade <= 0.0 {
                        self.droneFadeTimers[1]?.cancel()
                        self.droneFadeTimers[1] = nil
                        self.stopKosmicIntroEffects()
                    }
                }
                src.resume()
                self.droneFadeTimers[1] = src
            }
        }
    }

    private func stopKosmicDroneFades() {
        droneFadeTimers[0]?.cancel()
        droneFadeTimers[0] = nil
        droneFadeTimers[1]?.cancel()
        droneFadeTimers[1] = nil
        bodyEntranceFadeTimer?.cancel()
        bodyEntranceFadeTimer = nil
        stopKosmicIntroEffects()
        // Restore volumes that the intro/outro ramp may have left at non-unity values
        boosts[kTrackBass].outputVolume = 1.0
        boosts[kTrackPads].outputVolume = 1.0
        engine.mainMixerNode.outputVolume = 1.0
        applyMuteState()
    }

    // MARK: - Motorik fade (intro 0→1, outro 1→0 on mainMixerNode — all tracks)
    // Unlike Kosmic (which fades per-track boosts for bass+pads only), Motorik fades all
    // tracks together via the master mixer node, since every track participates in intro/outro.
    // The same 4-case position logic as Kosmic is used to prevent the seek-silence bug.

    private func startMotorikFades(state: SongState) {
        // Cancel existing timers inline — no volume restore (position-based setup below handles it)
        motorikFadeTimers[0]?.cancel(); motorikFadeTimers[0] = nil
        motorikFadeTimers[1]?.cancel(); motorikFadeTimers[1] = nil

        let schedulerID    = currentSchedulerID
        let intro          = state.structure.introSection
        let introEndStep   = (intro?.endBar ?? 0) * 16
        let inIntro        = intro != nil && currentStep < introEndStep
        let outro          = state.structure.outroSection
        let totalBars      = state.frame.totalBars
        let outroStartStep = (outro?.startBar ?? totalBars) * 16   // Int.max would overflow × 16
        let outroEndStep   = (outro?.endBar   ?? totalBars) * 16
        let inOutro        = outro != nil && currentStep >= outroStartStep && currentStep < outroEndStep

        // --- Volume setup: depends on where the playhead is ---
        if currentStep == 0, intro != nil {
            // Song start: already zeroed in play(); confirm 0 here for safety.
            engine.mainMixerNode.outputVolume = 0.0
        } else if inIntro {
            // Mid-intro seek: jump to proportional volume so the fade continues smoothly.
            let startProg = Float(currentStep) / Float(max(1, introEndStep))
            engine.mainMixerNode.outputVolume = startProg
        } else if inOutro, let outro = outro {
            // In outro: set to the proportional remaining volume.
            let totalOutroSteps = outro.endBar * 16 - outroStartStep
            let elapsed         = currentStep - outroStartStep
            engine.mainMixerNode.outputVolume = Float(max(0.0, 1.0 - Double(elapsed) / Double(max(1, totalOutroSteps))))
        } else {
            // Body (past intro, before outro) or no intro/outro: full volume.
            engine.mainMixerNode.outputVolume = 1.0
        }

        // --- Intro ramp timer ---
        if inIntro, let intro = intro {
            let startProg    = (currentStep == 0) ? Float(0) : Float(currentStep) / Float(max(1, introEndStep))
            let remSteps     = max(1, introEndStep - currentStep)
            let durationSecs = Double(remSteps) * state.frame.secondsPerStep
            let startNanos   = DispatchTime.now().uptimeNanoseconds

            let fadeSrc = DispatchSource.makeTimerSource(queue: .main)
            fadeSrc.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
            fadeSrc.setEventHandler { [weak self] in
                guard let self, self.currentSchedulerID == schedulerID else { return }
                let elapsed  = Double(DispatchTime.now().uptimeNanoseconds - startNanos) / 1_000_000_000.0
                let fraction = Float(min(1.0, elapsed / max(0.001, durationSecs)))
                let progress = startProg + fraction * (1.0 - startProg)
                self.engine.mainMixerNode.outputVolume = progress
                if progress >= 1.0 {
                    self.motorikFadeTimers[0]?.cancel()
                    self.motorikFadeTimers[0] = nil
                }
            }
            fadeSrc.resume()
            motorikFadeTimers[0] = fadeSrc
        }

        startMotorikOutroFade(state: state, schedulerID: schedulerID)
    }

    private func startMotorikOutroFade(state: SongState, schedulerID: Int) {
        guard let outro = state.structure.outroSection else { return }
        let outroStartStep = outro.startBar * 16
        let outroEndStep   = outro.endBar   * 16
        let totalSteps     = outroEndStep - outroStartStep
        guard totalSteps > 0, currentStep < outroEndStep else { return }

        let sps             = state.frame.secondsPerStep
        let stepsUntilStart = max(0, outroStartStep - currentStep)
        let delaySeconds    = Double(stepsUntilStart) * sps

        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isPlaying, self.currentSchedulerID == schedulerID else { return }
                guard self.motorikFadeTimers[1] == nil else { return }

                let elapsedInOutro = max(0, self.currentStep - outroStartStep)
                let startProgress  = Float(1.0 - Double(elapsedInOutro) / Double(totalSteps))
                let remainingSecs  = Double(totalSteps - elapsedInOutro) * sps
                let startNanos     = DispatchTime.now().uptimeNanoseconds

                self.engine.mainMixerNode.outputVolume = startProgress

                let src = DispatchSource.makeTimerSource(queue: .main)
                src.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
                src.setEventHandler { [weak self] in
                    guard let self, self.currentSchedulerID == schedulerID else { return }
                    let elapsed    = Double(DispatchTime.now().uptimeNanoseconds - startNanos) / 1_000_000_000.0
                    let linearFade = Float(max(0.0, 1.0 - elapsed / max(0.001, remainingSecs)))
                    self.engine.mainMixerNode.outputVolume = startProgress * linearFade
                    if linearFade <= 0.0 {
                        self.motorikFadeTimers[1]?.cancel()
                        self.motorikFadeTimers[1] = nil
                        // Clear effect buffers so reverb/delay tails don't bleed through
                        // when mainMixerNode volume is restored for the next song.
                        self.allNotesOff()
                        for rev in self.reverbs { rev.reset() }
                        for del in self.delays  { del.reset() }
                    }
                }
                src.resume()
                self.motorikFadeTimers[1] = src
            }
        }
    }

    private func stopMotorikFades() {
        motorikFadeTimers[0]?.cancel()
        motorikFadeTimers[0] = nil
        motorikFadeTimers[1]?.cancel()
        motorikFadeTimers[1] = nil
        engine.mainMixerNode.outputVolume = 1.0
        applyMuteState()
    }

    // MARK: - Ambient per-note attack/decay fades

    /// Smoothly ramps boosts[trackIndex].outputVolume to `toVolume` over `duration` seconds.
    /// Called on the main actor (from the onStep main.async block).
    /// Updates fade state for the channel and starts the shared timer if not already running —
    /// no DispatchSource is created or cancelled per note event.
    private func startAmbientBoostFade(trackIndex: Int, toVolume: Float, duration: Double) {
        let idx = trackIndex == kTrackBass ? 0 : 1
        ambientNoteFadeFromVol[idx]    = boosts[trackIndex].outputVolume
        ambientNoteFadeToVol[idx]      = toVolume
        ambientNoteFadeDuration[idx]   = max(0.001, duration)
        ambientNoteFadeStartNanos[idx] = DispatchTime.now().uptimeNanoseconds
        ambientNoteFadeActive[idx]     = true

        // Start shared timer only if not already running
        guard ambientFadeTimer == nil else { return }
        let src = DispatchSource.makeTimerSource(queue: .main)
        src.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(10))
        src.setEventHandler { [weak self] in self?.tickAmbientFades() }
        src.resume()
        ambientFadeTimer = src
    }

    /// 20 Hz tick: advances all active ambient fade channels, stops timer when all complete.
    private func tickAmbientFades() {
        let now = DispatchTime.now().uptimeNanoseconds
        var anyActive = false
        for idx in 0..<2 {
            guard ambientNoteFadeActive[idx] else { continue }
            let trackIndex = idx == 0 ? kTrackBass : kTrackPads
            let elapsed = Double(now - ambientNoteFadeStartNanos[idx]) / 1_000_000_000.0
            let t       = Float(min(1.0, elapsed / ambientNoteFadeDuration[idx]))
            let vol     = ambientNoteFadeFromVol[idx] + t * (ambientNoteFadeToVol[idx] - ambientNoteFadeFromVol[idx])
            let muted   = muteState[trackIndex] || (anySoloActive && !soloState[trackIndex])
            boosts[trackIndex].outputVolume = muted ? 0.0 : vol
            if t >= 1.0 { ambientNoteFadeActive[idx] = false } else { anyActive = true }
        }
        if !anyActive {
            ambientFadeTimer?.cancel()
            ambientFadeTimer = nil
        }
    }

    private func stopAmbientNoteFades() {
        ambientFadeTimer?.cancel()
        ambientFadeTimer = nil
        ambientNoteFadeActive = [false, false]
        boosts[kTrackBass].outputVolume = 1.0
        boosts[kTrackPads].outputVolume = 1.0
    }

    // MARK: - Ambient song-level outro fade

    /// Fades engine.mainMixerNode.outputVolume 1→0 over the declared outro section,
    /// or over the last 4 bars when no outro exists (pureDrone form).
    private func startAmbientOutroFade(state: SongState, schedulerID: Int) {
        ambientOutroFadeTimer?.cancel()
        ambientOutroFadeTimer = nil

        let totalBars = state.frame.totalBars
        let outroStartStep: Int
        let outroEndStep: Int
        if let outro = state.structure.outroSection, outro.endBar > outro.startBar {
            outroStartStep = outro.startBar * 16
            outroEndStep   = outro.endBar   * 16
        } else {
            // Fallback for pureDrone (no outro section): fade over last 4 bars
            outroStartStep = max(0, totalBars - 4) * 16
            outroEndStep   = totalBars * 16
        }
        let totalSteps = outroEndStep - outroStartStep
        guard totalSteps > 0, currentStep < outroEndStep else { return }

        let sps             = state.frame.secondsPerStep
        let stepsUntilStart = max(0, outroStartStep - currentStep)
        let delaySeconds    = Double(stepsUntilStart) * sps

        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isPlaying, self.currentSchedulerID == schedulerID else { return }
                guard self.ambientOutroFadeTimer == nil else { return }

                let elapsedInOutro = max(0, self.currentStep - outroStartStep)
                let startProgress  = Float(1.0 - Double(elapsedInOutro) / Double(totalSteps))
                let remainingSecs  = Double(totalSteps - elapsedInOutro) * sps
                let startNanos     = DispatchTime.now().uptimeNanoseconds

                self.engine.mainMixerNode.outputVolume = startProgress

                let src = DispatchSource.makeTimerSource(queue: .main)
                src.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
                src.setEventHandler { [weak self] in
                    guard let self, self.currentSchedulerID == schedulerID else { return }
                    let elapsed    = Double(DispatchTime.now().uptimeNanoseconds - startNanos) / 1_000_000_000.0
                    let linearFade = Float(max(0.0, 1.0 - elapsed / max(0.001, remainingSecs)))
                    self.engine.mainMixerNode.outputVolume = startProgress * linearFade
                    if linearFade <= 0.0 {
                        self.ambientOutroFadeTimer?.cancel()
                        self.ambientOutroFadeTimer = nil
                        // Clear effect buffers so reverb/delay tails don't bleed through
                        // when mainMixerNode volume is restored for the next song.
                        self.allNotesOff()
                        for rev in self.reverbs { rev.reset() }
                        for del in self.delays  { del.reset() }
                    }
                }
                src.resume()
                self.ambientOutroFadeTimer = src
            }
        }
    }

    private func stopAmbientOutroFade() {
        ambientOutroFadeTimer?.cancel()
        ambientOutroFadeTimer = nil
        engine.mainMixerNode.outputVolume = 1.0
    }

    // MARK: - Kosmic body entrance fade
    // Tracks that have no events in the intro section enter cold at the body downbeat.
    // This fades their sampler volume 0→1 over 1 bar so the entrance is smooth, not a slam.

    private func startBodyEntranceFade(state: SongState, schedulerID: Int) {
        guard let intro = state.structure.introSection else { return }
        let introEndStep = intro.endBar * 16

        // Identify tracks with no intro events — they're "cold entrants" at the body start.
        var tracksToFade: [Int] = []
        for i in 0..<kTrackCount {
            guard i != kTrackBass && i != kTrackPads else { continue }  // drone tracks handled separately
            let hasIntroNotes = state.trackEvents[i].contains { $0.stepIndex < introEndStep }
            if !hasIntroNotes { tracksToFade.append(i) }
        }
        guard !tracksToFade.isEmpty else { return }

        // Silence them now; the timer will ramp them up.
        for i in tracksToFade { samplers[i].volume = 0.0 }

        let fadeSecs  = Double(8) * state.frame.secondsPerStep  // half bar — quick entrance, not a slam
        let startNanos = DispatchTime.now().uptimeNanoseconds

        let src = DispatchSource.makeTimerSource(queue: .main)
        src.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
        src.setEventHandler { [weak self] in
            guard let self, self.currentSchedulerID == schedulerID else { return }
            let elapsed  = Double(DispatchTime.now().uptimeNanoseconds - startNanos) / 1_000_000_000.0
            let progress = min(1.0, elapsed / max(0.001, fadeSecs))
            let curved   = Float(Foundation.sqrt(progress))
            let anySolo  = self.anySoloActive
            for i in tracksToFade {
                let muted = self.muteState[i] || (anySolo && !self.soloState[i])
                self.samplers[i].volume = muted ? 0.0 : curved * self.trackBaseVolume[i]
            }
            if progress >= 1.0 {
                self.bodyEntranceFadeTimer?.cancel()
                self.bodyEntranceFadeTimer = nil
                self.applyMuteState()  // restore authoritative mute/solo volumes
            }
        }
        src.resume()
        bodyEntranceFadeTimer = src
    }

    // MARK: - Kosmic hidden intro/outro effects (pads sweep + bass slow pan)
    // Activated during intro/outro drone sections only — no UI state change.

    private func startKosmicIntroEffects() {
        // Bass: Cathedral reverb during the Kosmic intro — lush and spatial.
        // wetDryMix 70 (vs Large Chamber 50 in body) for a deep, washy quality.
        reverbs[kTrackBass].loadFactoryPreset(.cathedral)
        reverbs[kTrackBass].wetDryMix = 70

        // Pads: sweep LFO (0.07 Hz, cutoff 400–3200 Hz) — driven by shared lfoTimer
        if !sweepEnabled[kTrackPads] {
            kosmicIntroSweepPhase  = 0.0
            kosmicIntroSweepActive = true
            sweepFilters[kTrackPads].auAudioUnit.shouldBypassEffect = false
            startSharedLFO()
        }

        // Bass: very slow pan (0.05 Hz, ±0.5) — driven by shared lfoTimer
        if !panEnabled[kTrackBass] {
            kosmicIntroBassPanPhase  = 0.0
            kosmicIntroBassPanActive = true
            startSharedLFO()
        }
    }

    private func stopKosmicIntroEffects() {
        kosmicIntroFadeTimer?.cancel()
        kosmicIntroFadeTimer = nil
        kosmicIntroSweepActive  = false
        kosmicIntroSweepPhase   = 0.0
        kosmicIntroBassPanActive = false
        kosmicIntroBassPanPhase  = 0.0
        if !sweepEnabled[kTrackPads] {
            sweepFilters[kTrackPads].auAudioUnit.shouldBypassEffect = true
            AudioUnitSetParameter(sweepFilters[kTrackPads].audioUnit,
                                  0, kAudioUnitScope_Global, 0, 6000, 0)
        }
        if !panEnabled[kTrackBass] {
            boosts[kTrackBass].pan = 0.0
        }
        stopSharedLFOIfIdle()
        // Revert bass reverb to Large Chamber for the body
        reverbs[kTrackBass].loadFactoryPreset(.largeChamber)
        reverbs[kTrackBass].wetDryMix = 50
    }

    // MARK: - All-notes-off (used by stop())

    private func allNotesOff() {
        for (i, sampler) in samplers.enumerated() {
            let ch = gmChannel(i)
            // CC 120 = All Sound Off, CC 123 = All Notes Off
            sampler.sendController(120, withValue: 0, onChannel: ch)
            sampler.sendController(123, withValue: 0, onChannel: ch)
        }
    }

    // MARK: - Private setup

    private func setupEngine() {
        #if os(iOS)
        // Exclusive playback category: activating our session interrupts other apps (Apple Music,
        // Audible, etc.) and they can interrupt us — the correct behaviour for a music app.
        // Must be set before engine.start() so the session is configured before audio routes open.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        #endif

        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        for i in 0..<kTrackCount {
            let sampler      = AVAudioUnitSampler()
            let boost        = AVAudioMixerNode()   // outputVolume > 1 = boost; pan = auto-pan
            let sweepFilter  = AVAudioUnitEffect(audioComponentDescription: Self.lpDesc)
            let delay        = AVAudioUnitDelay()
            let comp         = AVAudioUnitEffect(audioComponentDescription: Self.compDesc)
            let lowEQ        = AVAudioUnitEQ(numberOfBands: 2)
            let reverb       = AVAudioUnitReverb()

            // Boost: unity gain, centre pan by default
            boost.outputVolume = 1.0
            boost.pan          = 0.0

            // Sweep filter: high cutoff (open), slight resonance for Moog character, bypassed until enabled
            AudioUnitSetParameter(sweepFilter.audioUnit, 0, kAudioUnitScope_Global, 0, 6000, 0) // cutoff Hz
            AudioUnitSetParameter(sweepFilter.audioUnit, 1, kAudioUnitScope_Global, 0,  3.0, 0) // resonance dB
            sweepFilter.auAudioUnit.shouldBypassEffect = true

            // Delay: 16th-note echo, rolled off above 6kHz
            delay.delayTime     = 0.125
            delay.feedback      = 40
            delay.lowPassCutoff = 6000
            delay.wetDryMix     = 0
            delay.auAudioUnit.shouldBypassEffect = true

            // Comp: threshold -15 dB, fast attack (2 ms), moderate release (80 ms), +4 dB makeup
            AudioUnitSetParameter(comp.audioUnit, 0, kAudioUnitScope_Global, 0, -15.0, 0)
            AudioUnitSetParameter(comp.audioUnit, 1, kAudioUnitScope_Global, 0,   5.0, 0)
            AudioUnitSetParameter(comp.audioUnit, 2, kAudioUnitScope_Global, 0,   1.0, 0)
            AudioUnitSetParameter(comp.audioUnit, 4, kAudioUnitScope_Global, 0, 0.002, 0)
            AudioUnitSetParameter(comp.audioUnit, 5, kAudioUnitScope_Global, 0,  0.08, 0)
            AudioUnitSetParameter(comp.audioUnit, 6, kAudioUnitScope_Global, 0,   4.0, 0)
            comp.auAudioUnit.shouldBypassEffect = true

            // Low shelf: +5 dB at 80 Hz, bypassed until enabled
            lowEQ.bands[0].filterType = .lowShelf
            lowEQ.bands[0].frequency  = 80
            lowEQ.bands[0].gain       = 5.0
            lowEQ.bands[0].bypass     = false
            // High-pass: 250 Hz, -12 dB/oct — enabled for Lead/Texture in Ambient mode to
            // prevent reverb muddiness; bypassed by default and in Kosmic/Motorik
            lowEQ.bands[1].filterType = .highPass
            lowEQ.bands[1].frequency  = 250
            lowEQ.bands[1].bypass     = true
            lowEQ.auAudioUnit.shouldBypassEffect = true

            // Reverb: cathedral for atmospheric tracks (Lead1, Lead2, Pads, Texture);
            // large chamber for rhythmic tracks (Rhythm, Bass, Drums)
            let atmosphericTracks: Set<Int> = [kTrackLead1, kTrackLead2, kTrackPads, kTrackTexture, kTrackLeadSynth]
            reverb.loadFactoryPreset(atmosphericTracks.contains(i) ? .cathedral : .largeChamber)
            reverb.wetDryMix = 0
            reverb.auAudioUnit.shouldBypassEffect = true

            engine.attach(sampler)
            engine.attach(boost)
            engine.attach(sweepFilter)
            engine.attach(delay)
            engine.attach(comp)
            engine.attach(lowEQ)
            engine.attach(reverb)

            // Chain: sampler → boost → sweep → delay → comp → lowEQ → reverb → mixer
            engine.connect(sampler,     to: boost,       format: nil)
            engine.connect(boost,       to: sweepFilter, format: nil)
            engine.connect(sweepFilter, to: delay,       format: nil)
            engine.connect(delay,       to: comp,        format: nil)
            engine.connect(comp,        to: lowEQ,       format: nil)
            engine.connect(lowEQ,       to: reverb,      format: nil)
            engine.connect(reverb,      to: mixer,       format: nil)

            samplers.append(sampler)
            boosts.append(boost)
            sweepFilters.append(sweepFilter)
            delays.append(delay)
            comps.append(comp)
            lowEQs.append(lowEQ)
            reverbs.append(reverb)
        }
        loadGMPrograms()
    }

    private func startEngine() {
        #if os(iOS)
        // Session must be active before the engine starts — starting on an inactive session
        // causes the engine to open onto a dead route, producing silence even though isRunning=true.
        // Re-assert the preferred buffer duration here in case it was cleared by an interruption.
        try? AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.023)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        do { try engine.start() }
        catch {
            let msg = "AVAudioEngine failed to start: \(error.localizedDescription)"
            print(msg)
            onEngineError?(msg)
        }
    }

private func loadGMPrograms() {
        let bankURL = gmDLSSoundBankURL()
        for i in 0..<kTrackCount {
            let program = kDefaultGMPrograms[i] ?? 0
            let isDrum  = (i == kTrackDrums)
            // bankMSB: 0x79 = melodic GM, 0x78 = percussion (GM drum channel 10)
            let bankMSB: UInt8 = isDrum ? 0x78 : 0x79
            // Texture pads tend to be quiet — boost their default volume
            if i == kTrackTexture { samplers[i].volume = 1.4 }
            try? samplers[i].loadSoundBankInstrument(
                at: bankURL, program: program, bankMSB: bankMSB, bankLSB: 0
            )
            // Seed the cache so setProgram() skips redundant reloads of the startup defaults
            currentProgram[i] = program
            currentBankMSB[i] = bankMSB
        }
    }

    private func gmDLSSoundBankURL() -> URL {
        // Prefer bundled GeneralUser GS SF2 for higher quality.
        // To roll back: delete the SF2 from Resources — this fallback restores the Apple DLS bank.
        if let sf2 = Bundle.main.url(forResource: "GeneralUser_GS_v1.471", withExtension: "sf2") {
            return sf2
        }
        return URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
    }

    /// Spec: MIDI channel assignment — drums must use channel 9 (GM drums).
    nonisolated private func gmChannel(_ trackIndex: Int) -> UInt8 {
        trackIndex == kTrackDrums ? 9 : UInt8(trackIndex)
    }

    /// Spec §Mute and Solo: set sampler output volume to 0; keep dispatching events for sync.
    /// Lead Synth (kTrackLeadSynth) is invisible to the user — it always mirrors Lead 1's mute/solo state.
    private func applyMuteState() {
        let anySolo = anySoloActive
        for i in 0..<samplers.count {
            let effectiveSolo = (i == kTrackLeadSynth) ? soloState[kTrackLead1] : soloState[i]
            let effectiveMute = (i == kTrackLeadSynth) ? muteState[kTrackLead1] : muteState[i]
            let muted = effectiveMute || (anySolo && !effectiveSolo)
            samplers[i].volume = muted ? 0.0 : trackBaseVolume[i]
        }
    }

    // MARK: - Audio export (real-time tap capture)

    /// Records the song by tapping the main mixer output during live playback.
    /// Captures exactly what the user hears — all effects, reverb, and samplers are live.
    ///
    /// A 500 ms pre-delay is inserted after stop() before the tap starts — this lets reverb
    /// tails from prior playback drain to silence so they never bleed into the recorded file.
    ///
    /// Full-song mode adds a 2.5-second reverb tail after the last bar.
    /// Sample mode captures up to 60 seconds with a 5-second linear fade-out at the end.
    func exportAudio(
        url: URL,
        state: SongState,
        sampleMode: Bool = false,
        onProgress: @escaping @Sendable (Double) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    ) {
        stop()
        // Increment schedulerID to invalidate any pending onStep async blocks from the
        // previous playback session — they check this ID before writing currentStep and
        // would otherwise race to overwrite the 0 we set here.
        currentSchedulerID += 1
        currentStep = 0
        currentBar  = 0

        // Store callback now so cancelExport() works even during the pre-delay window.
        currentExportOnComplete = onComplete

        // 500 ms silence: lets cathedral/chamber reverb tails from prior playback decay
        // before the tap opens. The engine keeps running; samplers are silent via allNotesOff.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.currentExportOnComplete != nil else { return }
            self.installExportTap(url: url, state: state, sampleMode: sampleMode,
                                  onProgress: onProgress, onComplete: onComplete)
        }
    }

    private func installExportTap(
        url: URL,
        state: SongState,
        sampleMode: Bool,
        onProgress: @escaping @Sendable (Double) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    ) {
        let mixerNode       = engine.mainMixerNode
        let tapFormat       = mixerNode.outputFormat(forBus: 0)
        let sr              = tapFormat.sampleRate
        let sps             = state.frame.secondsPerStep
        let songMusicFrames = Int64(Double(state.frame.totalBars * 16) * sr * sps)

        let musicFrames:    Int64
        let totalFrames:    Int64
        let fadeStartFrame: Int64

        if sampleMode {
            musicFrames    = min(songMusicFrames, Int64(60.0 * sr))
            totalFrames    = musicFrames
            fadeStartFrame = max(0, musicFrames - Int64(5.0 * sr))
        } else {
            musicFrames    = songMusicFrames
            totalFrames    = musicFrames + Int64(sr * 2.5)
            fadeStartFrame = Int64.max
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey:         kAudioFormatMPEG4AAC,
            AVSampleRateKey:       sr,
            AVNumberOfChannelsKey: tapFormat.channelCount,
            AVEncoderBitRateKey:   128_000
        ]
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: outputSettings)
        } catch {
            currentExportOnComplete = nil
            onComplete(error)
            return
        }

        let tapState = ExportTapState()
        tapState.fadeStartFrame  = fadeStartFrame
        tapState.fadeTotalFrames = totalFrames
        currentExportTap        = tapState

        // Silence the first 100 ms of captured audio regardless of mixer volume state.
        // This is a belt-and-suspenders guard against any DSP-init transient that slips
        // through between the time outputVolume is set to 0 and the render thread picks it up.
        let silenceFrames = Int64(0.100 * sr)

        mixerNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buf, _ in
            guard !tapState.done else { return }
            let remaining = totalFrames - tapState.frames
            guard remaining > 0 else { return }
            if Int64(buf.frameLength) > remaining {
                buf.frameLength = AVAudioFrameCount(remaining)
            }

            // Zero the first 100 ms of the captured audio to suppress any startup transient.
            let bufStart = tapState.frames
            if bufStart < silenceFrames, let channelData = buf.floatChannelData {
                let nch     = Int(buf.format.channelCount)
                let zeroEnd = min(silenceFrames - bufStart, Int64(buf.frameLength))
                for ch in 0..<nch { memset(channelData[ch], 0, Int(zeroEnd) * MemoryLayout<Float>.size) }
            }

            // Linear fade-out for sample mode.

            let fadeLen  = tapState.fadeTotalFrames - tapState.fadeStartFrame
            if fadeLen > 0 && bufStart + Int64(buf.frameLength) > tapState.fadeStartFrame,
               let channelData = buf.floatChannelData {
                let nch = Int(buf.format.channelCount)
                for i in 0..<Int(buf.frameLength) {
                    let absFrame = bufStart + Int64(i)
                    if absFrame >= tapState.fadeStartFrame {
                        let t      = Float(absFrame - tapState.fadeStartFrame) / Float(fadeLen)
                        let factor = max(0.0, 1.0 - t)
                        for ch in 0..<nch { channelData[ch][i] *= factor }
                    }
                }
            }

            do {
                try audioFile.write(from: buf)
            } catch {
                tapState.done = true
                Task { @MainActor [weak self] in
                    self?.finishExport(onComplete: onComplete, error: error)
                }
                return
            }
            tapState.frames += Int64(buf.frameLength)
            onProgress(min(1.0, Double(tapState.frames) / Double(musicFrames)))
            if tapState.frames >= totalFrames {
                tapState.done = true
                Task { @MainActor [weak self] in
                    self?.finishExport(onComplete: onComplete, error: nil)
                }
            }
        }

        load(state)
        play()
    }

    /// Cancels an in-progress export (including during the pre-delay window before the tap opens).
    /// AppState is responsible for deleting the partial file on cancel.
    func cancelExport() {
        if let ts = currentExportTap, !ts.done {
            // Tap is installed — stop it.
            ts.done = true
            currentExportTap = nil
            let cb = currentExportOnComplete
            currentExportOnComplete = nil
            engine.mainMixerNode.removeTap(onBus: 0)
            stop()
            cb?(CancellationError())
        } else if let cb = currentExportOnComplete {
            // Cancel during pre-delay — tap not yet installed, no file written yet.
            currentExportOnComplete = nil
            cb(CancellationError())
        }
    }

    private func finishExport(onComplete: @Sendable (Error?) -> Void, error: Error?) {
        currentExportTap        = nil
        currentExportOnComplete = nil
        engine.mainMixerNode.removeTap(onBus: 0)
        stop()
        onComplete(error)
    }
}
