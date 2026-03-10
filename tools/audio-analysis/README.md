# Audio Analysis Tools

This folder contains reproducible local analysis scripts for MP3 music analysis and rule calibration.

## Requirements

- macOS with Apple Swift toolchain (`xcrun swift`)
- Local readable audio files (`.mp3` recommended)

## Main script

- `analyze-mp3-music.swift`

It computes:

- duration
- tempo proxy (`bpm_est`)
- intro/outro envelope points
- coarse section boundaries
- density and dynamic-range proxies
- pulse regularity and subdivision regularity

## Run with file paths

```bash
xcrun swift /Users/urlocker/Downloads/Zudio/tools/audio-analysis/analyze-mp3-music.swift \
  --json /path/to/analysis/neu-set.json \
  "/path/to/track1.mp3" \
  "/path/to/track2.mp3"
```

## Run with a list file

Create a plain text file with one file path per line:

```text
/path/to/track1.mp3
/path/to/track2.mp3
```

Then run:

```bash
xcrun swift /Users/urlocker/Downloads/Zudio/tools/audio-analysis/analyze-mp3-music.swift \
  --list /path/to/input-files.txt \
  --json /path/to/analysis/output.json
```

## Notes

- These are full-mix feature proxies, not stem-level transcription.
- Use outputs as calibration guidance for probability/rule tuning in Motorik, Ambient, Cosmic, or hybrid styles.
