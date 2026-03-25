# Encoding Genre: Building a Rule-Based Music Generator Without Machine Learning

**Zack Urlocker**

---

## The Itch I Couldn't Scratch

I have spent most of my career in software—as a computer scientist by training, then as a software executive at companies including MySQL, Zendesk, and Duo Security. Music has run parallel to all of it. I play bass, I compose, and for many years my friend Rob and I have been making music under the name Electric Buddha Band. We started with a somewhat ambitious side project—an open source rock opera that we released under a Creative Commons license—but in recent years the band has shifted toward instrumental tracks spanning Kosmic, Motorik, and Ambient styles, composed in Logic Pro and occasionally with more generative tools like Sonic Pi and Bespoke.

My actual listening skews toward classic 70s rock—Led Zeppelin, Cream, the Allman Brothers—but I chose Motorik, Kosmic, and Ambient for Zudio precisely because they are comparatively formulaic. That is not a criticism; it is what makes them tractable. A Motorik groove is built on a small number of verifiable constraints. A Kosmic arpeggio follows identifiable sequencer patterns. The rules are real and extractable. The creative core of classic rock—the guitar solo, the vocal inflection, the feel that comes from a specific player on a specific day—is much harder to encode, and probably should not be attempted.

There was a second motivation I should be transparent about: I wanted to see how far Claude could take me on a project that genuinely exceeded my individual skills. I had previously vibe-coded a video poker web app and a video blackjack web app—programs I had written before in earlier careers for Windows and DOS, so the problem space was familiar even if the implementation language was new. A native macOS music application was a different order of challenge. I do not have the knowledge to become a fluent Swift developer, a SwiftUI layout expert, a MIDI programmer, and an advanced music theorist simultaneously—and I did not have the patience to acquire all four before starting. The question was whether careful specification, clear documentation, and iterative AI-assisted development could substitute for that deep technical expertise. The answer, for the most part, is yes—with caveats I will get to.

When generative music apps started appearing seriously on the market, I paid close attention. I tried Brian Eno and Peter Chilvers' Reflections and Trope—beautiful, meditative, cohesive experiences that can sustain an ambient listening session indefinitely. I tried EON, the app built around Jean-Michel Jarre's Bloom: 10 Worlds collaboration—rich audiovisual textures that feel like living artwork. What all of these apps share is a strong aesthetic identity and a kind of effortless beauty. What they lack is any ability to steer the output toward a specific genre or compositional intent. They are more like ambient weather than music—beautiful, but you cannot ask the weather to sound like Neu!.

Machine learning-based generation tools like Suno and Udio offer a different kind of abundance. Prompt them and they produce. But the output is stylistically diffuse, unpredictable, and entirely opaque. The model has learned statistical patterns from a vast training dataset; it cannot explain why it made a particular harmonic choice, because it doesn't know. There is no authorial intent to examine.

That gap—between "beautiful but unsteerable" and "steerable but inscrutable"—is where Zudio lives.

## Genre as a Set of Verifiable Rules

The founding hypothesis of Zudio is that a musical genre is largely describable as a finite set of measurable properties. Not metaphors ("it sounds like driving at night"), but specific, falsifiable claims: tempo in BPM, kick drum placement in a 4/4 bar, rate of harmonic change in bars, melodic density in notes per bar.

My research process started where any good engineering project starts: with data collection. For Motorik, I assembled a reference set of canonical tracks—Neu!'s *Hallogallo* and *Für Immer*, Harmonia's *Deluxe (Immer Wieder)* and *Walky-Talky*, several Cluster pieces—and measured them. The results were specific. Mean BPM across the canonical set: approximately 129. Mean intro duration: 9.1% of total track length. Section-count proxy (estimated structural transitions per track): 7.3. Pulse regularity scores derived from audio analysis using Apple's AVFoundation framework in Swift scripts, providing a numeric proxy for how mechanically consistent the groove remained across the track's duration.

I then added my own Electric Buddha Band compositions to the reference set. I exported MIDI files and stems from my Logic Pro sessions for songs like *Dark Sun*, *Time Loops*, *Vanishing Point*, and *Schulers Dream 05*, and gave those files to Claude for analysis alongside the canonical references. The Electric Buddha set showed somewhat lower pulse regularity (0.585 vs 0.689) and shorter intros—reflecting a slightly less strict Motorik orthodoxy—but confirmed the core structural patterns: long continuity sections, sparse harmonic rhythm, motif-first melodic development.

That combination—canonical references plus my own compositions—gave me both a target and a calibration point. The rules needed to produce music consistent with what Neu! does, but also with what I actually make, not some imagined ideal of the genre.

The methodology applied similarly to Kosmic and Ambient. For Kosmic, the key architectural observation from analyzing Jarre, Tangerine Dream, and Vangelis is that the arpeggio sequencer plays the role that the kick drum plays in Motorik: it is the pulse, the groove, the heartbeat. Harmony changes every 8–32 bars via one of five progression families—static drone, two-chord pendulum, modal drift, suspended resolution, quartal stack. Rhythm is secondary or absent. The energy is inward and spatial.

For Ambient, the most important structural principle turned out to be what I ended up calling the *co-prime loop architecture*: each track generates a short loop of a different length, with no shared common factors. Pads might loop every 7 bars, Bass every 11, Lead every 9. The full combination cycle before the pattern repeats is therefore the product of those prime-ish numbers—thousands of bars, far longer than any actual song. The variation a listener perceives emerges from the phasing of loops past each other, not from any moment-by-moment compositional decision. Brian Eno arrived at this same principle using two tape loops of different lengths in the 1970s. I arrived at it by asking what structural property explains why his music feels like it never repeats.

## AI as Specification Engine

Here is where the development process took an unusual turn, and one I think is worth describing in some detail.

Before writing a single line of Swift code for the generator, I used Claude to help write the genre specification documents. These are effectively product requirement documents—the kind a software team writes before building any significant feature—except in this case the "product" is a set of musical rules that a code generator will apply probabilistically.

The workflow was roughly as follows: I provided raw evidence—song measurements, listening notes, web sources, MIDI analysis output from my Logic Pro sessions—and asked Claude to synthesize it into a structured specification. A representative prompt:

> *"Here are audio analysis measurements from 13 Motorik tracks, including six of my own Electric Buddha Band songs exported from Logic Pro as MIDI. Based on this data, what are the universal rules for the bass generator? I need concrete, implementable rules—not aesthetic descriptions. Each rule should be nameable, have a specific rationale, and be directly translatable into code."*

The output was a structured list of named rules with rationale: *BASS-004 Berlin School Pulse* (root note on beat 1, fifth on beat 3, held through 8th-note feel—directly observed in multiple reference tracks); *BASS-007 Syncopated Walk* (root with off-beat approach notes, occasional octave jump—extracted from the Electric Buddha set); *BASS-001 Root Lock* (root only, held for the full bar—stylistically correct for the most hypnotic passages in canonical Motorik).

The process repeated for each style and each track type, producing documents I called style plans—roughly 1,000 lines each, covering genre history, artist-by-artist analysis, universal rules, instrument palettes, effect configurations, and the complete implemented specification. A similar prompt for the Ambient style's tonal architecture:

> *"Brian Eno's tape loop technique creates the sense that the music never exactly repeats. How do I encode this property in a MIDI generator where each of seven tracks generates a fixed loop? What mathematical property of the loop lengths guarantees maximum cycle time within a practical song length?"*

The answer was the co-prime loop design: choose lengths with no common factors, and the full cycle is their least common multiple—a number so large it exceeds any plausible song length.

What AI was genuinely useful for: organizing evidence into consistent structures across three parallel style documents, cross-referencing genre literature, synthesizing raw measurements into named rules with rationale, and maintaining terminology consistency across specifications written over months. What I had to provide: all the musical judgments, all the listening, all the final approval. Claude can tell you that two rules produce similar note-pool behavior; only a musician can tell you which one sounds *right*. It is a formidable research assistant and specification writer. It cannot play bass.

## From Specification to Architecture

The generation pipeline that resulted runs in ten sequential steps:

1. **Musical Frame** — key, mode, tempo, mood, and total song length
2. **Song Structure** — sections (intro, A, B, bridge, outro) with lengths and intensity profiles
3. **Tonal Map** — every bar assigned a chord window containing three note pools: chord tones (safest), scale tensions (colorful), avoid tones (chromatic non-scale pitches)
4. **Per-track generation** — each of seven tracks (Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums) runs its own generator, drawing from the tonal map and selecting from its rule set
5. **Post-processing** — dynamic arcs, density gating, breath silences, mid-song harmonic excursions
6. **SongState assembly** — all of the above packaged into a single immutable Swift struct
7. **Playback load** — the playback engine pre-computes its note-off map and starts the step sequencer

The Tonal Governance Map is the central architectural decision. Rather than letting generators freely choose pitches, every generator draws from pre-computed pools of acceptable pitches for its functional role. Bass and Rhythm generators draw only from chord tones—maximum consonance. Lead generators can draw from scale tensions, providing color without producing out-of-scale notes. This means that even with 50+ probabilistic rules per style, the harmonic output stays coherent: the rules govern rhythm, density, contour, and register; the tonal map governs pitch.

Every generation decision is tagged with a named rule ID—*DRUM-001 classic Motorik beat*, *KOS-BASS-002 Moroder drift*, *AMB-LEAD-008 returning motif*—and written to both the in-app status log and a companion text file exported alongside every MIDI file. This traceability turned out to be essential for quality assurance, as described below.

The random number generator is SplitMix64, a fast deterministic pseudo-random number generator. The same seed always produces the same song—the generator behaves like a mathematical function (seed → song, reproducible), not like a stream (unpredictable, non-repeatable). A particularly good song can be noted by its seed and regenerated exactly.

The implementation uses Swift and SwiftUI on macOS, with AVAudioEngine and AVAudioUnitSampler for audio. The native Apple stack was chosen for its absence of third-party dependencies, App Store compatibility, and direct portability to iOS without changes to the audio layer.

## The First Songs Were Terrible

There is a phase in any generative music project that I think of as the humbling. You have done the research. You have written the specifications. You have implemented the generators. You press Generate for the first time. And what comes out sounds like a MIDI file from 1994 being played through the wrong soundbank at the wrong tempo.

Zudio was no exception. The early Motorik output had the right tempo and the right drum pattern, but the bass was wandering outside the key, the lead melody was random noise masquerading as a phrase, and the harmonic structure—theoretically governed by the tonal map—was producing note choices that bore no audible relationship to the mode of the song. Technically, notes were being played. Musically, nothing was happening.

What happened next was the most iterative part of the project. I generated a batch of songs, exported the MIDI and log files, and analyzed them—first manually, then with Claude running Python scripts against the exported data. The findings were specific and actionable.

The first major bug discovered was what I came to call the *Aeolian lock*. The function that selected chord roots was hardcoded to use Aeolian (natural minor) scale degree weights regardless of the actual mode of the song. Songs generated in Ionian or Dorian were selecting chord roots appropriate to a natural minor key—a systematic harmonic mismatch across the entire song. When I asked Claude to analyze a batch of eleven songs and compute modal consonance scores per track, songs in non-Aeolian modes came back at 28–40% consonance—fewer than half the generated notes were in the scale of the song. This was a single-function bug affecting every generated song in every style. Once fixed, consonance scores jumped above 90%.

The second memorable bug was less subtle but equally damaging to the music. Drum fills in the Motorik generator were firing every four bars. A 120-bar Motorik song was accumulating up to 22 drum fills. Neu!'s *Hallogallo*—ten minutes of Motorik orthodoxy—probably has three. The trance-inducing quality of Motorik depends on the groove not being interrupted constantly. The fix was straightforward once identified (fire fills every eight bars instead), but finding it required looking at aggregate statistics across a batch. No individual song revealed it clearly; looking at the fill-count distribution across ten songs made it obvious.

This cycle—generate batch, export data, analyze, identify bugs, fix, repeat—ran through multiple rounds for each style. Each round revealed a new class of problem. Some were code bugs. Some were rule design errors: a bass rule with zero randomization, producing identical output in every song. Some were probability weighting errors: a single rule dominating 45% of generations, starving the others. The key clustering bug was genuinely surprising: the key and mood override values were incorrectly written back to app state after each generation, locking all subsequent songs to the first-generated key. Five of eleven songs in one analysis batch came back as E Dorian—a 0.1% random-chance outcome that was practically certain given the bug.

Each fix produced a measurable improvement, and frequently an audible one—the kind of moment where a code change results in the next generated song suddenly sounding like it belongs to the right genre.

## Quality Assurance as Computational Musicology

After the initial stabilization phase, the quality assurance process settled into a systematic analytical loop. Generate a batch of ten to twelve songs. Export MIDI and companion log files. Run analysis scripts computing:

- *Modal consonance per track*: what fraction of note events belong to the active scale? Bass target: greater than 92%. Lead target: greater than 72%.
- *Lead overlap rate*: what fraction of steps have both Lead 1 and Lead 2 playing simultaneously? Target: less than 30%.
- *Density arc shape*: do notes-per-bar increase from intro to body and fall in outro? A flat arc indicates the song has no dynamic shape.
- *Chord window length*: how many bars does each chord sustain? Kosmic target: four bars minimum average.

The log files, which contain every rule ID applied and every generation decision made, allow problems to be traced to specific rules. A consonance anomaly in one Kosmic song—62% rhythm track consonance, well below the 90%+ of other songs—traced back to rule *KOS-RTHM-004 Electric Buddha pentatonic groove*, which was computing its note pool relative to the local chord root rather than the song tonic. When Modal Drift had selected a non-tonic chord root, the note pool shifted to a scale that didn't match the key. The fix was a one-line change; identifying that the fix was needed required both the metric and the rule log from the same song.

A typical analysis prompt at this phase looked like:

> *"Here are eleven log files and MIDI analysis outputs from a Kosmic generation batch. Identify the top five issues by severity, trace each to specific rule IDs or code functions, and suggest targeted fixes."*

The response would identify, for instance, that Lead 1 was producing fewer than 0.8 notes per bar in eight of eleven songs against a target of 2–5, trace this to specific rule weight distributions, and recommend adjustments. Systematic batch analysis that would have taken many hours manually could be completed in under an hour. What AI cannot contribute to this phase: whether the music actually sounds Kosmic. That determination requires ears.

## An Honest Assessment

The music Zudio generates is not as good as what I produce on my own. I say that as someone who plays bass, composes in these genres, and has strong opinions about what Motorik is supposed to sound like—not as false modesty.

Sometimes a generated song is genuinely interesting. A Kosmic piece lands on an unusual mode with a very slow harmonic drift, and the arpeggio sequencer locks into a rhythm against the pads that sounds like something worth developing. I export the MIDI, open it in Logic Pro, and start editing. In those moments the generator functions as a sketch tool—a way of producing raw structural material faster than I could assemble it manually.

More often the output is competent but predictable. The rules are followed correctly. The bass is consonant, the drum fill rate is appropriate, the lead density arc has the right shape. But there is no surprise. A real musician knows when to break a rule for expressive effect—to play the note that theory says is wrong but the ear says is right, to hold a phrase one bar longer than expected because the tension has somewhere to go. Rules-following is necessary for musical coherence; it is not sufficient for musical intelligence.

The generator also lacks what might be called local memory. A human composer developing a motif across a seven-minute piece is aware of everything that has come before and can make decisions that reference that history. The current generator, operating track-by-track within a tonal map, has no such awareness. It produces musical events that are locally coherent but cannot make large-scale compositional choices.

With additional rules, more careful probability weighting, and better inter-track awareness, the output will improve. But there is likely a ceiling below what a skilled human musician produces, because the thing that makes skilled musicians compelling is precisely their ability to understand *and then selectively violate* the rules of their genre.

## Future Work

The rule set for each style is genuinely incomplete—not by oversight but by structural necessity. Fifty Motorik rules sounds like a lot until you sit with a professional session musician who can name fifty variations on a single bass pattern from memory, each with different expressive implications. My rules are a first approximation derived by a software engineer with musician-level knowledge. What the project needs at this stage is a professional musician with serious music theory training to audit what exists, identify what is missing, and contribute rules in the areas where the generator is weakest.

The areas of greatest weakness are also the areas of greatest theoretical depth: secondary dominants and modal interchange (deliberately borrowing chords from parallel modes), voice leading across sustained chord windows, motivic development over long song timelines. These are things a trained musician can describe formally and precisely. Encoding them as probabilistic generation rules is an engineering problem I know how to solve. The missing ingredient is the specification.

Beyond rules, the development roadmap includes an iOS and iPad port (the Swift and AVAudioEngine stack is already iOS-compatible; the work is in adapting the layout and controls to touch interaction), an upgraded soundbank replacing the current GS MIDI samples with a higher-quality open-source alternative, and a continuous play mode in which songs evolve in real time over extended periods rather than generating a fixed-length piece and stopping.

That last item is architecturally the most interesting. The best ambient music does not have a beginning and an end; it has a slow drift across parameter space that gives the impression of continuous change without ever arriving anywhere in particular. Encoding that as a generative system—with harmonic centers shifting over tens of minutes, rules fading in and out, loops gradually changing length—is closer to what Eno was doing with tape loops than anything a fixed-song generator can achieve.

## Conclusion

Zudio is a demonstration that genre is knowable, and that knowable things can be encoded. A musical genre is not only an aesthetic feeling; it is a set of measurable constraints on tempo, rhythm, harmony, melodic density, and structure. Identify those constraints carefully enough, encode them as probabilistic rules operating within a tonal framework, and you can build a generator that produces music recognizably in the right genre—most of the time, and sometimes compellingly so.

The role of AI in this project was as a collaborator on specification and analysis, not as a creator. It helped translate measurements into structured rules, maintain consistency across three large specification documents, and analyze batches of generated songs for specific metric violations. It did not compose. It did not make musical judgments. It cannot tell you whether a particular generated song is interesting. Those remain human functions.

Whether what Zudio generates counts as music may depend on your definition. By most criteria—harmonic coherence, rhythmic consistency, stylistic recognizability—it qualifies. Whether it has the thing that makes music worth listening to more than once is a question I leave to the listener, and one the generator answers differently every time.

---

*Zack Urlocker is a computer scientist, software executive, and amateur musician. He co-founded Electric Buddha Band with his longtime collaborator Rob. Zudio is available at github.com/ZUrlocker1/Zudio.*
