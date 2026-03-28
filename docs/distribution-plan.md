# Distribution Plan

## Do you need an Apple Developer account?

Yes, for TestFlight and formal distribution. The Apple Developer Program costs $99/year and is required
for TestFlight, App Store distribution, and proper code signing. Without it you can still build and run
on your own Mac via Xcode, but distribution to others has limits.

---

## Options

### 1. Zip and send the .app (free, works immediately)

Since Zudio is a macOS app, a fully built `.app` is already produced in the Downloads folder on each
release. Zip it and send via AirDrop, email, or Dropbox.

Caveat: macOS Gatekeeper will block unsigned apps. Recipients need to right-click → Open the first
time, then click "Open Anyway" in System Settings → Privacy & Security.

Works well for technically savvy friends. No account needed, no review, instant.

### 2. TestFlight for macOS (requires $99/year Apple Developer account)

- Upload a build to App Store Connect (Apple's portal)
- Invite testers by email — they install the free TestFlight app on their Mac and get a notification
- Up to 100 internal testers (immediate, no review) or 10,000 external testers (requires a quick Apple
  review, usually 1–2 days)
- Builds expire after 90 days; push new builds as you iterate
- Much cleaner experience for non-technical testers — one tap to install and update

### 3. Developer ID + Notarization (requires $99/year, for wider distribution)

- Sign the app with a Developer ID certificate, submit to Apple for notarization (automated, usually
  minutes)
- Result: a `.dmg` or `.zip` that installs on any Mac with no Gatekeeper warnings at all
- Best for sharing broadly or with users who aren't comfortable with security prompts

---

## Recommendation

**Short term**: Zip the latest release app and share it directly. Right-click → Open handles Gatekeeper
for a small group of friends. Zero cost, works today.

**When ready for a proper beta**: Get the $99 Apple Developer account and use TestFlight. Testers get
update notifications, you get crash reports, and the install experience is polished.

The $99/year also covers notarization for frictionless direct distribution and is required for any
future App Store release.

---

## Current release approach (Apple Developer account active)

Releases are built as a **universal binary** (arm64 + x86_64), so the same app runs natively on both Apple Silicon and Intel Macs. As of 2025/2026 roughly 35-40% of Macs in active use are still Intel — a large enough share to be worth supporting, especially among creative/professional users who tend to keep hardware longer. A universal binary adds negligible size overhead and requires no separate build or download. The app is signed with a Developer ID certificate, notarized by Apple, and distributed as a `.dmg` file. Users can open it without any Gatekeeper prompts.

---

## Future Enhancement: Custom Document Type (.zudio)

### Background

Zudio currently saves song data as a plain `.txt` log file. This file contains the seed number, style, key, tempo, and all generation parameters — enough to fully reconstruct a song. Because it's plain text it's human-readable, shareable, and trivially small. The seed-based reload feature was a natural evolution from the debug log.

### The tradeoff: .txt vs. a custom extension

Keeping `.txt` has real advantages — any text editor opens it, users can read and copy seeds, share files in forum posts, and understand what a song is made of without any special tool. There is no proprietary or binary format to worry about.

The main limitation is that macOS has no way to associate `.txt` files with Zudio, so double-clicking a saved song in Finder does nothing useful. Users must use the Load button inside the app and navigate to the file manually.

A custom extension such as `.zudio` would solve this:

- Double-clicking a `.zudio` file anywhere in Finder opens it directly in Zudio
- A custom Finder icon makes saved songs visually distinct from generic text files
- It signals clearly to users that the file "belongs to" Zudio — less likely to be accidentally deleted
- Consistent with how other Mac creative apps handle document formats (GarageBand `.band`, Logic `.logicx`, Ableton `.als`)

The file format itself stays identical plain text — the extension is purely cosmetic from a data standpoint.

### How macOS document type registration works

The UTI (Uniform Type Identifier) declaration lives in `Info.plist`. macOS reads it at **install time** — when Launch Services scans the app bundle after it is copied into Applications, or when `lsregister` is run explicitly (already part of the Zudio release script). No runtime code is needed for the association itself.

The actual file-open handling requires a small addition: the app delegate needs to respond to the `application(_:open:)` callback that macOS sends when a user double-clicks an associated file. If Zudio is already running, macOS routes the open to the existing instance rather than launching a second copy.

### Implementation when ready

- Register `.zudio` as a document type in `Info.plist` with a UTI such as `com.zudio.song`
- Implement `application(_:open:)` in the app delegate to call the existing `loadFromLogURL` path
- Support both `.txt` and `.zudio` extensions in `loadFromLog` so existing saved files continue to work
- New saves can default to `.zudio`, or offer both as options in the save panel
- Optionally add a custom document icon (a variant of the Zudio app icon) for Finder display

This is a polish item appropriate for a wider public release, not an urgent correctness fix.

---

## iPad/iOS Distribution (future)

- **Testing on simulator**: Xcode includes iPad simulators (Pro, Air, mini, multiple iOS versions) — just change the build target. Good for layout; real device is better for audio.
- **Testing on a real iPad**: connect via USB, select it as the Xcode target, click Run. Direct install, no App Store or TestFlight needed. First time requires trusting your developer certificate on the iPad under Settings → General → VPN & Device Management.
- **iPads cannot open DMG files** — that format is macOS only.
- **Sharing with testers**: use TestFlight (free with Developer account). Testers install the TestFlight app and accept an email invite. Much simpler than any alternative.
- **Public release**: App Store, requires Apple review (typically 1–2 days for a new app).
