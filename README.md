# Zudio

Zudio is a personal research prototype for generative music on macOS. 
This was built using CLaude with 3 days work on the docs and then a week of vibe-coding. 

It generates Ambient, Cosmik and Motorik insopired songs with multi-track structure based on style specific rules. Rules were built by analyzing tracks from artists including Brian Eno, Jean Michel Jarre, Tangerine Dream, Neu!, Kraftwerk, Electric Buddha Band, Loscil, Craven Faults and more. Then I had Claude analyze the songs and make improvements to the rules. There are built-in effects (reverb, delay, auto-pan, sweep, etc) for each track. You can save a MIDI version of the songs or expert audio to an M4A file. 

This repository currently contains product research, implementation notes as well as Swift source code and a compiled binary. 

[Download for macOS](https://github.com/ZUrlocker1/Zudio/releases/download/v0.91a/Zudio-0.91a.dmg)

Current release: `0.91a (alpha)`. This build is unsigned, so macOS Gatekeeper will likely show warnings the first time you open it.

To run it anyway, download the DMG, install the app, then right-click the app in Finder and choose `Open`. macOS will show a warning dialog, but that path lets you bypass the initial block and launch the app.
