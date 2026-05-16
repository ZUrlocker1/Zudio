# Zudio Change Log

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
