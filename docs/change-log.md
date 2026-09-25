# Zudio Change Log

## V 2.6 (Build 131)  In progress

- **Texture speaks in the gaps** — When a synchronised group drops out, Texture now plays through it instead of dropping out with the rest, so the gap reads as a change of texture rather than a hole. The Sparse Punctuation rule also places its bursts against those gaps, not only at section boundaries: a Motorik song has about three sections, so it previously managed two bursts and six notes across a whole song. It now averages ten notes in four or five bursts — still very sparse, about one burst every twenty-five bars.

- **Clavinet removed from Motorik** — The Clavinet sound is not present in Zudio's soundfont, so any Motorik song that drew it for the Rhythm track generated notes that never played, and the status log reported "Missing MIDI patch 7". It has been removed from the Motorik instrument pool. Only one saved song out of 444 was affected, and it had been playing as a six-track song all along; on reload it now takes the pool's default Rhythm instrument instead. An audit confirmed this was the only instrument in any style whose sound was missing.

- **More Kraftwerk flavour in Motorik** — About one Motorik song in seven now leans more Krafwerk machine-like rather than Neu!-like. Rather than a new substyle, a coupled *cluster* of tracks adopts Kraftwerk rules together while the rest of the song draws from normal rotation. Twelve new Kraftwerk derived rules across drums, bass, rhythm, both leads and texture: rigid single-pitch percussion with few fills and a step sequencer's accent pattern rather than a drummer's swing, tiny sequencer cells locked to the barline, octave-unison doubling, and leads that make short statements and then stop. Cluster tracks also drop out together twice a song while everything else keeps playing, and draw from a restricted set of the existing electronic instruments. Cluster songs also run slower — 120-132 BPM against Motorik's usual 126-154, matching the tempo Kraftwerk actually worked at — and the drums fill only where the whole cluster drops out and returns. 
- **Motorik bass pool concentrated** — Four rules were retired from the base Motorik bass pool: McCartney Drive, LA Woman Sustain, Hook Ascent and Quo Arc. All four remain in Motorik Noir or Arcade, The freed weight went to the rules that pull hardest in either direction — both Kraftwerk bass rules rise from 15% combined to 26%, and Neu! Hallogallo doubles — so base Motorik gets more characterful at both ends.

- **Saved songs reload note-for-note** — A saved song stores its seed and is rebuilt from that seed on reload. Previously some patterns in Motorik songs came out slightly differently on reload. All tracks now restore consistently across all styles. 
- **Regression tests** — Added `DeterminismTests`, which generates 200 seeds per style twice over and requires identical notes, plus a third run to catch drift, and pins title, structure, harmony and the generation log as well.

---

## V 2.5 (Build 130)  Improvements to Endless, Chill, bug fixes
- Endless mode style mix modified to increase Kosmik and Motorik, decrease Chill, Ambient slightly: 
    - Ambient ~19.5%
    - Chill ~24%
    - Kosmic ~32%
    - Motorik ~24.5%
- **Endless mode streak cap** — In order to prevent Endless mode from getting stuck for long stretches bouncing beween Ambient / Chill, or Kosmic / Motorik, a hard cap has been added. After 8 songs in a row for Ambient / Chill or 12 for Kosmic / Motorik, Zudio will force a switch to the other style.
- **Chill variety** — Chill Bass and Rhythm (keyboard comping) tracks now evolve more within a song instead of looping the same patterns throughout. The Rhythm comping track switches style between the A and B sections and takes occasional rest bars. The more repetitive bass patterns (including the Chill Blues Quarter-pulse and Pickup grooves) now vary every 16 bars instead of staying fixed for the whole song.
- **Chill Rhythm rebalance** — Bosa Moon (the busiest comping mode) has been reduced in frequency and adjusted so it is less repetitive and dense. Two new Rhythm rules have been added:  **CHL-RHY-005 Chord Hold** (a single chord with occasional syncopation, staccato punctuation, and breathing gaps) and **CHL-RHY-006 Downbeat Pulse** (a plain chord on beats 1 and 3, with occasional staccato hits, a pushed beat 3, or a dropped beat 3). Both new rules are available in Chill Blues too. Each A/B section is tiled into 12-16 bar segments, each independently with a 35% chance of going sparse (up to 2 per section) — the busier modes fall back to their sparse shape (Moby Backbeat gets a half-time variant: a single beat-3 hit instead of the full beat-2/4 pattern). Added a rarer, more dramatic "dropout" fragment (Rhythm goes fully silent for one 12-16 bar stretch) in 20% of songs — always when Bosa Moon is in play, since it benefits most from a real break.
- **Chill Blues bass variation** — During the long 8-bar stretch of I chord in the 16-bar blues form, the bass now gets one small, randomly-placed variation per repeat (somewhere in bars 4-6) — an octave displacement, a repeated note, a reordered phrase, or a passing tone — so it feels less static regardless of which bass pattern is playing.
- **Chill mood-architecture cleanup** — Overall theme of this round of Chill work: less relentless, more breathing room, easier to reason about. Comping-mode selection no longer varies by song mood  — same rule mix heard, but "how often does rule X show up" is now a direct read instead of a simulation. Also removed an unused mood parameter from lead-instrument selection (it never actually affected the pick), and corrected several stale claims in the Chill design doc that no longer matched the shipped code.
- **Chill bass levels reduced** — All three Chill bass instruments have been turned down. Acoustic Bass and Fretless Bass were running noticeably hot and come down the most; Elec Bass drops 3 dB. Chill Blues is affected too, since it draws from the same three-instrument pool.
- **Ambient Piano mix** — Slightly more reverb and a soft echo on the piano so it doesn't sound as bare/flat in sparse arrangements.
- **New Ambient texture** — Added "Long Lake" (AMB-TEXT-010) to the Ambient audio texture pool: loon calls recorded over a lake, sparse and tonal rather than a continuous wash. The pool is now seven textures.
- **Audio texture fixed on reload** — Reloading a song that was still in session memory played every MIDI track but left the Ambient or Chill audio texture silent. The fast reload path called the MIDI engine directly, bypassing the separate audio-texture engine; it now starts the texture itself, as the regenerate-from-seed path already did. 
- **Instruments changed on reload** — An Ambient Piano song pinned Lead 1 to Stereo Piano and never released it, so every later Ambient song inherited the piano. Reloads could also lose the assignment entirely and fall back to the first instrument in each pool, silently, because instrument picks are not derived from the song seed and so cannot be recomputed. A song's instruments are now recovered from the `Instruments` line already stored in its own log, and an unrecoverable assignment is reported in the log instead of being quietly replaced.
- **Air effect fixed in stem export** — When exporting separate track stems, the Air effect used the wrong EQ shape (a single 12 kHz shelf rather than the 4 kHz presence peak plus 8 kHz shelf used in playback), so Air-enabled stems exported noticeably duller than the same song's mix. The normal M4A mix export was not affected.
- **Audio interruption logging** — When playback stops because another app takes over audio or the output device disconnects, the status log now shows a short line (e.g. "AUDIO  Stopped by another app") so it's visible after the fact.
- **Sleep Timer Bug fix** — Sleep timer could show its "playback stopped" message after play was manually stopped and stayed visible long after necessary. The timer now starts when playback starts and cancels when playback stops.
- **Chill breakdown bass rewritten** — In a Chill song with a harmonic-drone breakdown, the Acid Jazz bass rule (CHL-BASS-008) played the root on every beat of every bridge bar — four identical bars, sixteen identical notes, which sounded like a stuck loop rather than a breakdown. The bridge now follows a four-bar arc: pulse, motion, tighter pulse, release. Pulse bars stay on the root so the repetition still builds tension, but they play a funk cell — accent on the beat, ghost note on the "a", push on the "and" — repeated across both halves of the bar. Moving bars leave the root for the b7 and 5th, land on off-beats, and end on the swung "and of 4" so they lift into the next bar instead of closing square. The final bar walks up to a chromatic leading tone into the groove return. Pulse and moving bars alternate, so no two repetitive bars ever land in a row at any bridge length. The other two harmonic-drone bass rules already varied and are unchanged.
- **Song sharing fixed on iOS 26/27** — iOS 26 stopped offering any way to open a shared song on iPhone, and iOS 27 did not restore it. Tapping a shared song now offers **"Copy to Zudio"** again, and Zudio also appears in the iOS share sheet so songs can be handed to it from Files and other apps. Three pieces, which only work together:
    - **`ZudioQuickLook`**, a Quick Look preview extension declaring `QLSupportedContentTypes = com.zudio.song`. This is what restores the handoff — not because of what it draws, but because its presence makes Zudio the only thing on the system that can render a `.zudio`. Do not remove it because the preview looks unused.
    - **An opaque file type on iOS** (`public.data` + `public.content`). A matched pair with the extension above: while `.zudio` conformed to a text type, iOS used its own previewer and never consulted ours. Mac stays text-conforming, so Finder Quick Look still previews as text and Open With still offers TextEdit.
    - **`ZudioShare`**, a Share Extension that copies a song into a shared App Group container and launches Zudio via a new `zudio://` URL scheme. Since an extension cannot reliably launch its own app, Zudio also sweeps that container whenever it becomes active.
    The trade is no inline text preview of `.zudio` on iPhone or iPad — the attachment shows the Zudio icon instead. Mac behaviour is unchanged. Reported to Apple as FB24777501, since the underlying bug affects any text attachment, not just Zudio.
- **Regression tests** — Added tests pinning the `.zudio` document-type declarations across both platforms, and tests asserting the effect chains stay in sync between live playback and both export paths. Both classes of bug above were silent drift introduced inside commits about unrelated features.

---

## V 2.4 (Build 129)  Motorik Arcade
- **Motorik Arcade** — New Motorik substyle inspired by the fast, bright, arpeggiated sound of classic arcade and early video game music (Tempest 2000, Contra, Sonic). Features 4-on-the-floor kick, mid-register bass, Lydian/Mixolydian modes, and new arpeggio-driven lead rules including Octave Bounce, Triad Climb, Arcade Arp, and Gate Arp. Motorik Arcade reuses a few rules and instruments from Motorik regular, but adds several unique instruments and rules. It has a mix of major and minor scales. 
- Testing complete — Motorik substyle probabilities set to production values: Noir 21%, Arcade 19%, base Motorik 60%.
- **Bug fix** — Opening a Zudio file from finder or from Messages while the app wasn't already running could launch with no window. Fixed.
- Diagnostic logging for this bug is left in place but off by default. To re-enable: set `kAppOpenDebugLog = true` near the top of `ZudioApp.swift`, rebuild, then filter Console.app (or `log stream`) for subsystem `com.zudio.app`, category `AppOpen`. THis will log to zudio-log-live.txt.
---

## V 2.3 (Build 128)  Audio engine crash fix
- **New instruments** — Tonewheel Organ and Warm Pad added to Kosmic Bass instrument pool.
- **Distortion effect** — New "Dist." effect chip on Motorik Bass and Rhythm tracks (replaces Low and Boost chips). Uses soft-clip saturation for a warm, gritty character. Applied automatically by default: Motorik Noir bass and rhythm each distorted ~75% of the time independently; regular Motorik bass distorted ~20% of the time. Note distortion is off for Acoustic Bass and Fuzz Guitar by default, as a matter of taste.
- **Vibrato effect** — New "Vibrato" chip on Chill Lead 1, Lead 2 and Kosmic Lead 1, Lead 2. Applied probabilistically (~20% regular, 50% Kosmic Drift) and only for instruments where it is musically appropriate (e.g. flute, sax, trumpet, trombone on Chill; flute, oboe, sine wave, bassoon, vox on Kosmic). This replaces Boost and Comp effects.
- **Air effect** — New "Air" chip on Motorik Lead 1 and Lead 2. A two-band EQ boost (presence at 4 kHz + high shelf at 8 kHz) that adds brightness, bite and openness to synth leads. Applied probabilistically on Lead 1: ~25% of regular Motorik songs, ~45% of Motorik Noir songs. The chip is also available manually on Lead 2.
- **Probabilistic effects** — Several effects are now applied randomly on each new song generation to increase variety: Air on Motorik Lead 1 (~25% regular, ~45% Noir), Tremolo on Motorik Lead 1 for certain patches, Sweep on Kosmic Pads (~20%) and Motorik Pads (~15%), Tremolo on Kosmic Bass (~15%), Pan on Kosmic Texture (~15%), and Delay on Motorik Lead 2 (~20%). Kosmic Drift already had Sweep, Pan, and Tremolo always on; these additions bring the same textural variety to regular Kosmic.
- **Style chip** — The Mood chip next to the song title on Mac and iPad is replaced with the style or substyle (e.g. "Motorik", "Chill Blues"), matching the iPhone display.
- **iOS bug fixes** — Fixed a bug where regenerating an instrument track in a Motorik Noir song incorrectly changed the substyle to Motorik. Also removed a distracting "Generating…" flash in the iPhone player when regenerating a single track.
- **Crash fix** — Fixed a rare Mac crash that could occur after extended playback (2+ hours). A legacy audio unit was fanning its output to two destinations simultaneously, which caused CoreAudio's render thread to enter infinite recursion and crash with a segfault. Fixed by routing through a native pass-through node instead.

---

## V 2.2 (Build 126)  Optional stem export + new icon + new instruments
- **Audio export** — When exporting on the Mac the user can select an option to export separate track stems for bass, drums, leads and so on with full EQ and reverb
- **New instruments** — Guitar Fdbk added to Motorik Noir Texture; Fantasia 2 added to Kosmic Pads; Kalimba added to Ambient Rhythm
- **New app icon** — Redesigned icon replaces "Z!" with a periodic-table style "Zu"

---

## V 2.1 (Build 125)  Substyle shown in song list 
- **Song list shows substyle** — The saved song list now displays the substyle name where applicable (e.g. "Ambient Piano", "Chill Blues", "Motorik Noir", "Kosmic Drift") instead of just the base style.
- **iOS Save Song fix** — Fixed a bug where Save Song on iPhone and iPad did not export the MIDI file.
- **New instruments** — Shakuhachi added to Ambient Lead 1; Tonewheel organ added to Chill Rhythm; Pulse Bass added to Kosmic Bass; Fuzz Guitar now available in regular Motorik as well as Motorik Noir.


---

## V 2.0 (Build 124)  Reduced CPU by 50% with reverb bus
- **Reverb bus architecture** — Replaced 7 independent per-track `AVAudioUnitReverb` instances with 2 shared reverb buses for playback: a large bus (Cathedral, Large Room) and a small bus (Medium Hall). Each track sends its post-EQ signal to the appropriate bus; the dry signal travels directly to the main mixer. Result: **over 50% reduction in CPU load**. Playback without the visualizer now runs under 10% CPU; with the visualizer generally under 20%, compared to over 35% before. 
- **Higher fidelity M4A audio export** — M4A audio export continues to use per-track reverbs with the original presets for full audio fidelity.  The offline audio export now simulates all track effects including auto-pan, tremolo, and sweep filter, which are critical for Kosmic Drift and Ambient styles. 

---

## V 1.7 (Build 123)  Kosmic Drift

- **Kosmic Drift** — New Kosmic sub-style appearing in ~50% of Kosmic songs. Inspired by Boards of Canada, Portishead, and Sigur Ros. Slower tempo (70–90 BPM), sparse and meditative. Features three new drum rules (Loping Groove, Half-Time Lope, Dreamscape Float), four new bass rules, three new lead rules (Tycho Phrase, Drift Memory, Sigur Ros late entry float), and five new rhythm rules (Chord Tremolo, Slow Chord Pulse, Four-Bar Chord Hold, Chromatic Tremolo, Downbeat Chord) all drawn from MIDI analysis of reference tracks. A Dreamscape variant (~10% of Drift songs) produces the most extreme spaciousness.
- **Expanded Kosmic instrument pools** — Kosmic Pads gains Halo Pad and Bowed Glass for warmer choices. Kosmic Texture gains Solar Wind and FX Echoes for added atmospheric depth. Drift Lead 1 uses Warm Pad, Sine Wave, Bottle Blow, and Shenai. Drift Rhythm uses Moog, New Age Pad, Synth Mallet, Synth Chime, and Mystery Pad. Tremolo added to Kosmic Bass effects chip, replacing Low Filter.
- **Kosmic bass improvements** — KOS-BASS-001 Berlin School drone gains breathing gaps, duration variety and colour notes to make it a slow-evolving drone. The dual-bass layer (KOS-BASS-007 tremolo) now suppresses when the primary bass is on a sustained major-7th note to avoid semitone clashes.
- **Chill instrument selection simplified** — Removed incorrect mood-weighted Lead 1 and Lead 2 instrument selection.
- **Chill horn harmony in regular Chill** — The second-horn harmony previously  only in Chill Blues now appears in ~20% of regular Chill songs. Harmony is diatonic (a third or sixth below) or unison.
- **Generation log improvements** — Shortened and cleaned up descriptions for clarity and consistency.

---

## V 1.6 (Build 122)  Motorik Noir + improved gestures

- **Motorik Noir** — New dark sub-style appearing in ~30% of Motorik songs. Slower tempo (110–128 BPM), always minor mode. Inspired by Public Image Ltd, Joy Division etc.  Has deep bass rules (Albatross Pulse, Annalisa Riff, Wobble Theme), inverted drum grooves (Albatross Grid, Annalisa March), sparse pads, Cold Chord texture lead, and power-chord Chord Chug rhythm. Fills are rare and minimal.
- **Expanded Motorik instruments** — Motorik Rhythm pool expanded from 3 to 8 instruments: Crunch Guitar, Doctor Solo, Acoustic Bass, Pick Bass, and Charang added alongside the existing guitars and synth bass. Machine Kit added to Motorik Drums. Techno Bass added to Motorik Bass. Motorik Lead 1 gains two new voices: Synth Lead and Saw Stack. Kosmic Rhythm gains Harpsi Pad.
- **Swipe up / swipe down** — New visualizer gestures on all platforms: swipe up increases tempo by 5 BPM, swipe down decreases by 5 BPM (clamped 20–200). On iPhone/iPad uses UISwipeGestureRecognizer; on Mac uses vertical trackpad scroll (dominant-axis logic prevents conflict with horizontal swipes).
- **Orb click regenerates instrument and track** — Clicking or tapping an orb, swiping or pinching now regenerates both the instrument and the MIDI track, matching the lightning bolt button in the Tracks view.
- **Evolve tempo clamping fix** — Minor bug fixed to clamp tempo within the proper range for each style when playing in Evolve mode.
- **Kosmic intro effects fix** — Fixed a bug where incorrect reverb effects were applied during the Kosmic intro and outro.
- **Bass/drum sync improvements** — Fixed off-beat note placement in CHL-BASS-008 (Acid Jazz), KOS-BASS-009, MOT-BASS-003 (Crawling Walk) where primary bass notes were landing on weak 16th-note positions causing rhythmic misalignment.
- **Audio export respects Mute and Solo** — Exporting audio now respects  Mute and Solo track settings. Muted tracks are silent in the export matching what the user hears during playback.
- **Evolve mode Next Track fix** — Fixed a timing bug where pressing Next Track while Evolve mode was mid-evolution could cause it to alternate between two history songs instead of generating a new one.
- **First-best rules tightened** — The curated "first best" rules (which select the most representative groove for each style) now only fire on a true clean slate: the first time the user runs Zudio or after a full reset. Every session after the first uses a full random selection.
- **Smoother track view animation** — Playhead position now computed from wall-clock time rather than dispatch callbacks, eliminating lag during playback.


---

## V 1.5.1 (Build 121)  Minor improvements

- **Chill Blues lead** — CHL-LD1-004 blues lead now includes occasional fast runs and varied note lengths for a more realistic horn feel. CHL-LD1-002 short punch lead flows more smoothly with less halting silence and better phrase continuity.

---

## V 1.5.1 (Build 120)  Bug fix

- **Audio export fix** — Save as Audio was broken due to a missing soundfont reference; fixed.

---

## V 1.5 (Build 119)  Ambient Piano and new instruments

- **Ambient Piano** — New Ambient sub-style (work in progress). Appears in roughly 20% of Ambient songs. Generates a solo piano arrangement with optional pad accompaniment, piano-specific phrasing rules, smaller room reverb, and no delay on the lead voice.
- **New Ambient rhythm instruments** — Church Bells, Windchime, and Tinker Bell added to the Ambient Rhythm instrument pool.
- **Expanded Kosmic and Motorik instruments** — New synth bass options (Synth Bass 3, Synth Bass 4, Mean Saw Bass) added to Kosmic and Motorik bass pools; Saw Lead 3 added to Motorik Lead 1; Night Vision added to Motorik Lead 2.
- **SC55 Stereo piano** — After experimenting with several external SF2 piano soundfonts (Florestan, SC55 variants, Velocity Grand, Yamaha PSR), SC55 Stereo from the Roland SC55 soundfont emerged as the best option: more dynamic and natural-sounding than the GeneralUser GS Grand Piano. Now used in Ambient, Ambient Piano and Chill.
- **New drum kits** — Jazz Drums added to the Chill drum pool; Dance Drums added to the Motorik drum pool.
**Custom Zudio.sf2** — Replaced the bundled GeneralUser GS soundfont with a trimmed custom build. 115 unused presets were removed — including the piano/brass family cluster, Violin, Pipe Organ, accordion, woodwinds and all sound-effect programs reducing the size from **29.8 MB to 20.9 MB**, a saving of **(30%)** which makes the Zudio app 9MB smaller.

---

## V 1.4 (Build 118)  New Chill Blues

- **Chill Blues** — A new variation of the Chill style, appearing in roughly 1 in 5 Chill songs. Chill Blues generates a 16-bar blues form (I–IV–V) in a laid-back jazz-blues idiom: brushed or neo-soul drums, warm horns and reeds (tenor sax, clarinet, muted trumpet), sparse pads, and a soloist that phrases across the 16-bar form with blues-scale inflections and turnaround licks. Delay is removed from the lead voices for a drier, more authentic tone.
- **Chill Blues horn harmony** — In 25% of Chill Blues songs, a second horn joins Lead 1 in harmony or unison for up to two phrases during the second and final passes of the 16-bar form, evoking the call-and-response texture of a small jazz-blues ensemble.
- **Jazzy blues lead (CHL-LD1-009)** — A new Chill Blues lead rule with jazz phrasing idioms: turn figures, riff cells, chromatic approach notes, and short rapid-fire note bursts. Available in both Chill Blues (35% of songs) and regular Chill (8% of songs) for a jazz-inflected edge.
- **Chill rhythm variety** — CHL-RHY-001 (St Germain) and CHL-RHY-003 (Bosa Moon) now introduce subtle variations after the first 16 bars of a section, keeping long songs from feeling static.
- **Trumpet register fix** — Trumpet and muted trumpet lead voices now floor at Bb3, avoiding unnatural low-register notes.
- **Performance improvements** — Reduced main-thread CPU load: Canvas playhead views  update at display rate rather than step rate; audio waveform load is off the main thread.
- **Visualizer gestures regenerate tracks** — Tap/click on an orb, swipe, pinch, and double-tap/double-click on empty canvas now fully regenerate the track (new rule + new MIDI events), not just the instrument patch.
- **iOS 17 reverb bug fix** — Fixed a bug on iOS 17 where turning off the Reverb effect on any track would silence that track entirely. Affects all styles.

---

## V 1.3 (Build 117)  Bug fixes

- **iPhone lock screen transport sync fix** — iOS Lock screen play/pause button now correctly reflects Zudio's playback state at all times.
- **Kosmic audio export fix** — Fixed a bug where Kosmic songs did not export properly on iOS.

---

## V 1.1 (Build 116)  Fast audio export and musical improvements

- **Fast audio export** — Now uses an offline render 20–40× faster (about 15 sec) instead of real-time capture. On iOS, a share sheet appears so the file can be saved or shared.
- **New Ambient bass rules** — ECM pluck, Octave Double Slow Pendulum.
- **Ambient secondary lead** — New descending phrase form (AMB-LEAD-006).
- **More melodic Chill solos** — Chill lead solos use recurring themes with a free-form middle.
- **New Chill pad rules** — Moby Anchor, Open Fifth Hold, Slow Chord Build, String Hold.
- **Chill rhythm variety** — More variation in Chill rhythm tracks.
- **Chill secondary lead** — New Chill secondary lead form.
- **Chill lead balance** — Decreased trumpet frequency in Chill lead selection.
- **Chill audio texture bug fix** — Minor fix to texture playback variation.
- **More melodic Kosmic leads** — Pentatonic Drift and TD Skip Sequence are improved.
- **Kosmic pads variations** — Kosmic Quartal Stack pads has more variation.
- **Kosmic pads variations** — Kosmic Vangelis Swell pads has more variation.
- **Kosmic driving bass** — More evolving Kosmic driving bass sequencer.
- **808 kit drum fills** — Improved Kosmic and Motorik tom fills for 808 kit.
- **Motorik drum variety** — More variation in Motorik drum tracks.

---

## 1.02 (Build 115)  App Store fixes

- **Mac App Store fix** — Export Audio and Save Song now use NSSavePanel instead of writing directly to ~/Downloads. Single panel with Full Song / 60-sec Sample radio buttons replaces the old two-dialog flow.
- **Keyboard fix** — Arrow keys and other shortcuts no longer fire in Zudio while a save/export dialog is open.
- **Chill outro coordination, iPad BPM selector, lock screen and audio texture bug fixes.**

---

## 1.01 (Build 113)  Minor musical improvements and bug fixes

- iPhone save bug fix, instrument override persistence, rain/wind audio texture tracks for Ambient, Chill groove pocket breakdown and evolve mode track addition.
