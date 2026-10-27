# Zudio Change Log

## V 2.8 (Build 133) — iPhone Duo

- **iPhone Duo layout** — (2026-10-27) The foldable iPhone Duo now gets a layout made for it, tested on a real Duo. Folded, it runs the iPhone player unchanged. Unfolded, it runs the iPad layout, opening on Visuals with the track view one tap away on Tracks. Folding and unfolding mid-song leaves playback alone, and the unfolded tab is remembered. The choice is made by size class, with every iPad kept on the iPad layout by its idiom, so no existing iPhone or iPad changes.
- **Narrow windows, under 700 pt wide** — The unfolded Duo in portrait is 669 pt wide, narrower than an iPad mini. The top bar had been forcing the whole screen wider than the window, which clipped the Songs tab, the track effect buttons and the scrollbar. Below 700 pt the top bar now drops Mood and Key, moves Reset beside BPM, and puts Help, About, Sleep and Share in a row under it. The style picker is wider so Ambient is spelled out in full, and the BPM, Reset and Help rows share one type size. The track effect chips use their natural width, so the MIDI lane keeps its room, and the empty-song message wraps to two lines.
- **Short windows, under 660 pt tall** — The unfolded Duo in landscape is 635 pt tall, too short for seven track rows plus the generation log. In a window that short the log is hidden on the Tracks tab, the Generate, Save, Load and Export buttons are smaller, the tab strip is 28 pt with each icon beside its label, and track rows are 57 pt instead of 63, so all seven tracks show.
- **Chosen by size, not by model** — Both layouts are triggered by window size, so iPad Split View, Slide Over, resizable windows and any future small iPad get them too. iPad mini landscape and every larger iPad are unchanged.
- **Log pinch gesture** — Pinch-to-resize on the generation log stays on for iPhones and the folded Duo, and is off for iPads and the unfolded Duo, where the log behaves as on iPad.
- **Version 2.8 (build 133)** — The Mac download is the v2.8 release. See [iphone-duo-plan.md](iphone-duo-plan.md) for the full plan and what was tested.

## V 2.7 (Build 132) — Chill Soho

- **New Chill Soho substyle** — A third Chill form modelled on early-80s British sophisticated pop: Sade, Everything but the Girl, The Style Council, Simply Red, Roxy Music, Matt Bianco. Twenty-one new rules measured from MIDI of those records: bossa, samba, Latin sway and soul grooves with hand percussion; 6th, 7th and 9th chords with a separate B-section cycle and a four-bar turnaround the band plays; horn stabs and halos on a MIDI Texture track; sax-led leads built from vocal-line figures; and a house-style Remix Break. Soho song titles.
- **Guitar-led Soho rhythm** — Jazz and Funk Guitar added to the soundfont. Soho Rhythm is Rhodes, Stereo Piano, Nylon, Jazz and Funk Guitar at 20% each; guitars play with a slow amp tremolo by default. The unused SFX drum kit is gone; the soundfont is 21.2 MB.
- **Avalon lead** — The hook rule now draws far more varied figures, and each song applies one or two treatments to them — displace, lengthen, invert, reverse or extend. Figures sometimes run on or end on a held note. The log names the treatments. A varied hook returns to its original form after an episode or two, and the song ends on its opening hook. Episodes start on different chord tones, higher in the B section, and displaced songs no longer put every figure on the same beat.
- **A best first Chill Soho song** — The first time a Chill Soho song comes up, on Generate or in Endless, it is one of twelve chosen songs: a Latin groove in drums and bass, Operator on flute with vibraphone answering, and a Remix Break, Duo or bass break. Base Chill keeps its St Germain opener.
- **Operator, the Soho sung lead** — The Soho lead rule once called Counter-Line is now Operator, after *Smooth Operator*, the record it is mostly measured from. Its opening phrase is the song's hook: it returns about once every three phrases, at least six bars apart, half the time as it was and otherwise with one note added, dropped or moved, or starting on another chord tone. Phrases no longer end on the note they began on.
- **Groove fixup** — On every Chill song, lead notes stranded on weak sixteenths the band doesn't play are moved onto the beat, and one-sixteenth gaps inside a phrase are closed, so solos sit with the band and flow. Regenerating a lead does the same. The log reports how many notes changed.
- **Audio export — tremolo, Beat Fixup and Chill Pads fade** — Exported audio now includes the Beat Fixup delay, and Chill Pads fade in and out per chord with the filter sweep restarting closed at each chord, as in playback. Fast tremolo, vibrato and auto-pan are rendered in 60 fps blocks instead of ~90 ms ones, which had stepped an 8 Hz organ tremolo and a 4 Hz guitar tremolo instead of swelling them.
- **Beat Fixup — behind-the-beat feel (Chill Soho Soul)** — The bass sits 10 ms late and the drum backbeat (side stick, snare, clap) 20 ms late, with kick and hats on the grid, for the Sade / Style Council pocket. Playback only: no note moves. Latin and base Chill are unchanged. The log shows a `Laid back` row. The ⌘J / ⌃G test switch that briefly turned it off and on for comparison on Mac is disabled and removed; the delay is always on.
- **iPhone audio recovery and error display** — (2026-10-25) If the audio engine fails to start, for example when a Bluetooth headset has just been taken by another device, it now waits 300 ms and tries once more before giving up, and a successful retry logs a green `AUDIO  Audio engine restarted after error -50` line. The failure message is shorter, "Audio engine failed to start (error -50)", and ERROR lines show their tag in red and flash the visualizer red briefly. That covers all three audio faults: engine start failure, instrument load failure and missing MIDI patch.
- **Scrubbing no longer repeats log lines** — (2026-10-25) Dragging the progress slider within one bar no longer writes that bar's log lines on every tick: a repeat seek to the same step within a second is ignored. Dragging across bars still buzzes, since each new bar cuts all notes and restarts playback.
- **Beat Fixup test switch disabled** — (2026-10-25) The Mac-only ⌘J / ⌃G keystrokes that switched Beat Fixup off and on for A/B listening are removed, ahead of release. The behind-the-beat delay itself is unchanged and always on, on Mac, iPhone and iPad.
- **Beat Fixup in some Chill Blues** — (2026-10-19) Chill Blues songs on the B.B. King Pickup (CHL-BASS-009), Quarter Pulse (010), Root Sustain (001) or Walking (003) bass get the same behind-the-beat feel, smaller than Soul: bass 6 ms, side stick and snare 15 ms late, for the whole song including Groove B. Rumba (012), Ascending Riff (011) and Air Ostinato (004) songs stay on the grid. That is about 60% of Blues songs. The log shows `Laid back  Blues bass +6 ms, rim/snare +15 ms`. Playback and export both have it; the ⌘J / ⌃G test switch is disabled.
- **Filter sweeps in the log, and automatic ones** — (2026-10-19) Tapping or clicking empty canvas in the visualizer (Mac, iPad and iPhone) already ran a 3-second filter sweep across every track but drums, with a white flash on the canvas; it now writes `Bar 025   Filter sweep` to the log. Kosmic songs also sweep on their own: 40% of regular Kosmic songs (not Drift) get one to three sweeps, started about a bar and a half before a B section, bridge or 16-bar mark so the filter reopens on the change, at least 32 bars apart. The schedule comes from the song's seed, so it does not change a note and repeats on every pass and rewind. Evolve on a Kosmic (not Drift) song also sweeps at the start of phase 1 and phase 2. Each sweep logs and flashes the same way.
- **Endless mix retuned** — (2026-10-19) Chill is stronger with Soho, so the style walk moved from Ambient ~19.5%, Chill ~24%, Kosmic ~32%, Motorik ~24.5% to about Ambient 21%, Chill 27%, Kosmic 28%, Motorik 24%. Ambient jumps to Kosmic 25% of the time (was 32%), Chill 12% (was 8%), Kosmic steps back to Chill 10% (was 17%), and Motorik jumps to Chill 40% (was 15%). Runs of Kosmic and Motorik songs are shorter, median 6 songs (was 9); the longest is still 14. See docs/continuous-play.md.
- **Chill Blues harmony is rarer and pickier** — (2026-10-19) The second-horn harmony (3rds, 6ths or unison) now plays only in songs whose Lead 1 is the slow Blues Lead (CHL-LD1-004) or the Dyad lead (CHL-LD1-003), and never when Lead 2 is a vibraphone, which plays its normal part instead. Busy jazz-idiom lines (CHL-LD1-009) and short punches (CHL-LD1-002) no longer get it. About 15% of Blues songs, down from about 27%.
- **Chill Blues plays its blue note** — (2026-10-19) The b5 blue note (Db in G, Gb in C) never sounded: it was added at the wrong pitch and then stripped as out of mode. Now 60% of Blues songs have a soloist who uses it, as a passing tone between the 4th and 5th over the I chord, and the first move that fits becomes a lick that repeats through the song. Songs that don't fit it, or whose soloist doesn't use it, stay plain Dorian. The Chords line in the log says "blues scale" when it is heard. Blues only.
- **Leads stay in their register** — Chill leads now stay inside each instrument's own range; saxes no longer reach screechy altissimo notes.
- **Chill Soho tuning** — Six bass turnaround treatments, two or three per song. Lead solos answer a figure with a different one. The Harmonic Drone breakdown changes chord halfway and Lead 1 plays over it. Lead 2 rests 8–16 bars rather than whole sections, and a held Shadow Hold note gets a companion note (all Chill forms).
- **Chill instruments** — Each Chill picker lists the same instruments in all three forms; forms differ only in their random odds. Chill Blues pads are Strings Fast, Cello and Synth Strings 5. Soho Elec Bass plays with Low but no Comp.
- **Soho Duo breakdown** — A new Chill Soho breakdown, about one song in five: 8 or 12 bars of Rhythm and Bass alone. The bass keeps its groove, the comp plays every bar a little forward in the mix, and the chords keep moving. The kit drops to a soft shaker, closed hats or ride, and a snare pickup leads back in. Pads and leads sit out; the horns reply with a soft held chord every few bars and a stab into the return.
- **Soho horns sound like a section** — Horn stabs are two- or three-note chords far more often, turnaround stabs included, and each song has its own voicing (open, close, or with a 9th or 6th) that changes now and then. Half of the Sustained Halo's long notes are now two-note chords as well. Xylophone is gone from the Soho texture pool; Vibraphone takes its share.
- **Soho bass slides** — In Chill Soho songs on the Best Melodic bass, the bass now slides into a note from a whole or half step away now and then, from the side the line is coming from, about once every twelve bars, and often into the root after a turnaround. Chill Blues songs on the B.B. King pickup riff slide up a half step into the root at the top of every form. On any bass instrument, in playback and in exports, and marked "Bass slide" in the log.
- **Soho Rhodes tremolo** — Rhodes in Chill Soho plays with the slow amp tremolo by default, as the guitars do. Any Rhodes with tremolo switched on now uses that slow setting rather than the organ's fast Leslie.
- **Chill mix** — Lead 1, Lead 2 and Drums are drier in all Chill forms; Lead 2 and texture vibraphone are quieter.
- **Instruments stay inside their style** — One rule, for every style and play mode, now replaces an instrument carried over from the previous song that the new song's style never uses. Regular Motorik no longer gets Arcade's Metal Pad, Ice Rain or Mystery Pad. Chill songs in Endless and Evolve play their leads on the right instrument.
- **Chill and Blues solos come back to their opening phrases** — Through the middle of a song the lead now returns to its opening phrases now and then, where they fit the chord, so a solo has a theme rather than a long free stretch. Blues waits for the I chord to bring its opening lick back, and Chill Soho's two reused lead rules keep their returns clear of their rests.
- **"Lead 1 return to form" in the log** — Marks the bars where a Chill solo comes back to its opening phrase or hook in its original form.
- **Best first Soho song, refreshed** — Two of the twelve chosen songs had turned into Blues songs when the Blues share rose to 20%; they were replaced by two that meet the same list.
- **Chill mix** — Chill songs are now 30% Chill Soho, 20% Chill Blues and 50% base Chill.
- **Leads keep their shape above the pads** — When a lead is lifted an octave to clear the pads, the whole figure moves, so a step down no longer turns into a seventh up halfway through a phrase, including figures that run across the eight-bar windows the check works in. All styles.
- **Regenerated Chill leads get the full polish** — A regenerated Lead 1 or Lead 2 now goes through the same clean-up as a generated one: the clash guard, the lift above the pads, the song's dynamic arc, the instrument's range and the empty first bar on songs with no intro.
- **Saved songs replay exactly** — The first song of each style, Ambient songs on the Brush Kit, and Kosmic and Ambient songs reloaded from the Songs list now come back note for note. All three reload routes (Songs list, startup, .zudio file) share one replay.
- **Opening a .zudio file sets up its instruments fully** — The Chill leads, Ambient Piano and the Lead 2 mirror are set as on every other route before the song is saved to the Songs list.
- **Chill fade-in on reloads** — A Chill song that opens mid-groove fades in on Endless transitions, ⏮/⏭ and Songs-list taps, as it does when generated.
- **Arcade and Europe songs stay themselves** — Regenerating any track of a Motorik Arcade or Motorik Europe song, or reloading one from the Songs list, no longer turns it into plain Motorik.
- **Soho drum regenerate** — Regenerating the drums of a Chill Soho song with a Remix Break no longer picks a kit that can't play the break.
- **Soho Lead 1 randomise** — Picking a random Lead 1 in Chill Soho now uses the same odds as a generated song.
- **Soho chord cycles** — The B section's chord cycle is now drawn at its intended odds; one cycle had been taking far more than its share.
- **Flute and recorder on iPhone** — Songs replayed from the Songs list or with ⏮/⏭ played a flute or recorder lead as a saxophone. Replays now use the lead the song was written for, and songs already in the list are corrected.
- **Chill piano** — Stereo Piano on Chill Rhythm is about 3 dB quieter.
- **Muting an audio texture works** — Muting Texture now silences audio-loop textures (Chill, Chill Blues, Ambient) on every platform, and exports leave them out.
- **Lower CPU and battery use** — Playback no longer redraws the whole window on every beat, effect timers stop when playback stops and slow down when only slow effects are on, and idle reverbs and the idle texture player are switched off. On a Mac Zudio now typically uses 15–20% CPU, and 5–10% in the compact view with no visualizer.
- **Audio textures follow the song** — Fixed a bug in audio textures: they restarted from the top on Play, a seek or a texture change, so the waveform did not match what was heard. Playback, the waveform and exported audio now line up.
- **Saved songs keep your changes** — Fixed a bug where a regenerated track or a changed instrument was lost when a song was saved or reopened. Chill Blues files reopen exactly, and saved songs keep their Chill form when the mix changes.
- **Endless and Evolve** — Fixed a bug where Endless could occasionally play a song in the wrong style. In Evolve, the two leads no longer play over each other as often.
- **Evolve phase changes play through** — (2026-10-19) Fixed a dropout at both Evolve phase changes on Chill Blues and Chill Soho songs that start without an intro (about half of Blues songs, a few Soho ones). Those songs open on a drums-only pickup bar, and each Evolve phase replayed it, so the band stopped for half a bar or a whole bar mid-song. A phase now plays the same place one chord cycle later instead, with the full band. On iPhone the phase change also waited while the new instruments loaded, a short gap there only; playback now carries on and the instruments switch a moment later, as on the Mac.
- **Evolve fixes** — (2026-10-19) Opening a .zudio file in Evolve no longer plays the previous song's evolution, with its drums, bass and title, at the new song's outro. Generate in Evolve now always evolves the new song. Evolve's new instruments come from each substyle's own list, so Chill Blues no longer gets Recorder, Flute or Synth Brass, and the new Chill leads are written for the instrument that plays them. The Chill Blues behind-the-beat feel continues through both phases, and a song saved mid-Evolve keeps its title and rules.

## V 2.6 (Build 131)  Motorik Europe, reverb restored

- **New Motorik Europe substyle** — About one Motorik song in five: a synchronised group of tracks plays twelve new Kraftwerk-derived rules — rigid sequencer percussion and cells, octave doubling, short lead statements — dropping out together twice a song. 120–132 BPM, German-flavoured titles, a `Sync` line in the log.
- **Melodic Motorik leads** — The Kraftwerk lead rules use figures measured from Autobahn, The Robots and Computer Love, anchored to the chord, with no leap over an octave.
- **Motorik leads breathe** — Rest windows scale with song length, replayed phrases vary, phrases end on a held note, and the two densest rules are capped at twenty bars.
- **Motorik bass pool** — McCartney Drive, LA Woman Sustain, Hook Ascent and Quo Arc moved out of base Motorik (still in Noir or Arcade); the Kraftwerk rules rise to 26% and Neu! Hallogallo doubles.
- **Instrument variety** — Every track gets a real choice when a style starts; Mono Synth is weighted down in Europe and never repeats.
- **Kosmic levels** — Moog, Mono Synth and Synth Bass 3 on bass, and Synth Chime on rhythm, turned down.
- **Motorik lead mix** — Call and Answer down from 14% to 11%.
- **Chill pads breathe** — Pads now rest for a few bars at a time, decaying into the gap.
- **Reverb restored** — Playback had lost all reverb since build 124; it's back, and the reverb chip now decides whether a track is wet on every platform.
- **Audio timers thread-safe** — Removes a source of rare glitches and crashes in long playback.
- **Saved songs reload note-for-note** — The same seed now always produces the same song.
- **Crash fix** — A song could fail to generate depending on how its sections lined up.
- **Minor fixes** — Removed Clavinet from Motorik (missing from the soundfont); iPhone info sheet showed v2.4.
- **Regression tests** — Determinism, Motorik Europe, reverb routing, lead density and annotation tests.

---

## V 2.5 (Build 130)  Improvements to Endless, Chill, bug fixes

- **Endless mix** — Ambient ~19.5%, Chill ~24%, Kosmic ~32%, Motorik ~24.5%.
- **Endless streak cap** — After 8 Ambient/Chill songs or 12 Kosmic/Motorik songs in a row, Endless switches to the other pair.
- **Chill variety** — Bass and Rhythm evolve within a song: Rhythm switches between A and B and takes rest bars; repetitive bass patterns vary every 16 bars.
- **Chill Rhythm rebalance** — Bosa Moon reduced. New **CHL-RHY-005 Chord Hold** and **CHL-RHY-006 Downbeat Pulse** (also in Chill Blues). Sections tile into 12–16 bar segments that may go sparse, and 20% of songs get a full dropout.
- **Chill Blues bass variation** — One small variation per pass through the long I-chord stretch.
- **Chill comping and lead selection** — No longer vary by mood.
- **Chill bass levels** — All three Chill basses turned down.
- **Ambient Piano mix** — More reverb and a soft echo.
- **New Ambient texture** — "Long Lake" (AMB-TEXT-010), loon calls over a lake.
- **Audio texture on reload** — A reloaded song now plays its audio texture.
- **Instruments on reload** — Restored from the song's own log; Ambient Piano no longer pins Stereo Piano onto later songs.
- **Stem export Air effect** — Now matches playback.
- **Audio interruption logging** — The log notes when another app or a disconnected device stops playback.
- **Sleep timer** — Starts and cancels with playback.
- **Chill breakdown bass** — The Acid Jazz rule's harmonic-drone bridge now follows a four-bar arc instead of repeating the root.
- **Song sharing on iOS 26/27** — "Copy to Zudio" works again, and Zudio appears in the share sheet, via a Quick Look extension, an opaque `.zudio` type on iOS and a Share Extension. Reported to Apple as FB24777501.
- **Regression tests** — `.zudio` document types and playback/export effect-chain parity.

---

## V 2.4 (Build 129)  Motorik Arcade

- **Motorik Arcade** — New Motorik substyle in the style of classic arcade music: four-on-the-floor kick, mid-register bass, Lydian/Mixolydian, and arpeggio leads (Octave Bounce, Triad Climb, Arcade Arp, Gate Arp). Motorik is 60% base, 21% Noir, 19% Arcade.
- **Bug fix** — Opening a Zudio file while the app wasn't running could launch with no window. Diagnostic logging remains, off by default (`kAppOpenDebugLog` in `ZudioApp.swift`).

---

## V 2.3 (Build 128)  Audio engine crash fix

- **New instruments** — Tonewheel Organ and Warm Pad on Kosmic Bass.
- **Distortion effect** — "Dist." chip on Motorik Bass and Rhythm; on by default for ~75% of Noir and ~20% of regular Motorik bass.
- **Vibrato effect** — On Chill and Kosmic leads, applied to suitable instruments (~20% of songs, 50% in Kosmic Drift).
- **Air effect** — Presence and high-shelf boost on Motorik leads (~25% regular, ~45% Noir on Lead 1).
- **Probabilistic effects** — Sweep, tremolo, pan and delay applied randomly on several Kosmic and Motorik tracks.
- **Style chip** — Mac and iPad show the style or substyle next to the title.
- **iOS fixes** — Regenerating a Noir track no longer changes the substyle; no "Generating…" flash.
- **Crash fix** — Rare Mac crash after 2+ hours of playback.

---

## V 2.2 (Build 126)  Optional stem export + new icon + new instruments

- **Stem export** — Mac export can write separate track stems with full EQ and reverb.
- **New instruments** — Guitar Fdbk (Motorik Noir Texture), Fantasia 2 (Kosmic Pads), Kalimba (Ambient Rhythm).
- **New app icon** — Periodic-table style "Zu".

---

## V 2.1 (Build 125)  Substyle shown in song list

- **Song list shows substyle** — e.g. "Chill Blues", "Motorik Noir".
- **iOS Save Song fix** — Now exports the MIDI file.
- **New instruments** — Shakuhachi (Ambient Lead 1), Tonewheel (Chill Rhythm), Pulse Bass (Kosmic Bass); Fuzz Guitar in regular Motorik.

---

## V 2.0 (Build 124)  Reduced CPU by 50% with reverb bus

- **Reverb buses** — Two shared reverb buses replace seven per-track reverbs, more than halving CPU load.
- **M4A export** — Keeps per-track reverbs and now renders auto-pan, tremolo and sweep.

---

## V 1.7 (Build 123)  Kosmic Drift

- **Kosmic Drift** — New Kosmic substyle (~50% of Kosmic songs), after Boards of Canada, Portishead and Sigur Rós: 70–90 BPM, sparse, with new drum, bass, lead and rhythm rules.
- **Kosmic instruments** — New pads, textures, Drift leads and Drift rhythm voices; Tremolo replaces Low Filter on Kosmic Bass.
- **Kosmic bass** — Berlin School drone breathes and varies; the tremolo bass layer avoids semitone clashes.
- **Chill** — Lead instruments no longer mood-weighted; second-horn harmony in ~20% of regular Chill songs.
- **Generation log** — Shorter descriptions.

---

## V 1.6 (Build 122)  Motorik Noir + improved gestures

- **Motorik Noir** — New dark Motorik substyle (~30%): 110–128 BPM, always minor, after Public Image Ltd and Joy Division.
- **Motorik instruments** — Rhythm pool grows to 8; Machine Kit, Techno Bass, Synth Lead and Saw Stack added; Harpsi Pad on Kosmic Rhythm.
- **Swipe up / down** — Changes tempo by 5 BPM on all platforms.
- **Orb gestures** — Regenerate both instrument and track.
- **Fixes** — Evolve tempo clamping, Kosmic intro effects, bass/drum sync, export respects Mute and Solo, Evolve Next Track.
- **First-best rules** — Only on a true first run or after a reset.
- **Smoother playhead** — Driven by wall-clock time.

---

## V 1.5.1 (Build 121)  Minor improvements

- **Chill Blues lead** — More varied runs and note lengths; Short Punch flows better.

---

## V 1.5.1 (Build 120)  Bug fix

- **Audio export fix** — Save as Audio restored.

---

## V 1.5 (Build 119)  Ambient Piano and new instruments

- **Ambient Piano** — New Ambient substyle (~20%): solo piano with optional pads.
- **New instruments** — Church Bells, Windchime and Tinker Bell (Ambient Rhythm); new synth basses in Kosmic and Motorik; Saw Lead 3 and Night Vision in Motorik.
- **SC55 Stereo piano** — Used in Ambient, Ambient Piano and Chill.
- **New drum kits** — Jazz Drums (Chill), Dance Drums (Motorik).
- **Custom Zudio.sf2** — Trimmed GeneralUser GS from 29.8 MB to 20.9 MB.

---

## V 1.4 (Build 118)  New Chill Blues

- **Chill Blues** — New Chill form (~1 in 5): a 16-bar blues with brushed drums, horns and reeds, sparse pads and a blues soloist.
- **Chill Blues horn harmony** — A second horn in 25% of songs.
- **Jazzy blues lead (CHL-LD1-009)** — In Chill Blues and occasionally regular Chill.
- **Chill rhythm variety** — St Germain and Bosa Moon vary after 16 bars.
- **Trumpet register** — Floors at Bb3.
- **Performance** — Lower main-thread CPU.
- **Visualizer gestures** — Fully regenerate the track.
- **iOS 17 fix** — Turning off Reverb no longer silences a track.

---

## V 1.3 (Build 117)  Bug fixes

- **Lock screen** — Play/pause reflects playback state.
- **Kosmic export on iOS** — Fixed.

---

## V 1.1 (Build 116)  Fast audio export and musical improvements

- **Fast audio export** — Offline render, 20–40× faster; share sheet on iOS.
- **Ambient** — New bass rules and a descending secondary lead.
- **Chill** — More melodic solos, four new pad rules, more rhythm variety, a new secondary lead, less trumpet.
- **Kosmic** — Improved leads, pad variation and driving bass.
- **Drums** — Better 808 fills; more Motorik variety.

---

## 1.02 (Build 115)  App Store fixes

- **Mac App Store** — Save panels instead of writing to ~/Downloads.
- **Keyboard** — Shortcuts no longer fire while a dialog is open.
- **Fixes** — Chill outro, iPad BPM selector, lock screen and audio texture.

---

## 1.01 (Build 113)  Minor musical improvements and bug fixes

- iPhone save fix, instrument override persistence, rain/wind textures for Ambient, Chill groove pocket breakdown, evolve mode track addition.
