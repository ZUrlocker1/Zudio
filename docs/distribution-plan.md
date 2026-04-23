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

## Custom Document Type (.zudio) — Implemented in 0.95

Zudio saves song data as a `.zudio` file. The format is plain text — it contains the seed number, style, key, tempo, and all generation parameters needed to fully reconstruct a song. Any text editor can open it, seeds can be read and copied directly, and files can be shared in forum posts or emails without any special tool. There is no proprietary or binary format.

### What the .zudio extension provides

- Double-clicking a `.zudio` file in Finder opens it directly in Zudio
- macOS associates the file type with the app automatically when the app is installed
- Files are visually distinct from generic text files in Finder
- Consistent with how other Mac creative apps handle document formats (GarageBand `.band`, Logic `.logicx`, Ableton `.als`)

The file format itself is identical plain text — the extension is purely cosmetic from a data standpoint.

### Backwards compatibility

The Load Song button and file picker accept both `.zudio` and legacy `.txt` files. Users with existing `.txt` song files can rename them to `.zudio` in Finder and double-click to open — no conversion needed, the content is identical.

### How registration works

The UTI (Uniform Type Identifier) declaration lives in `Info.plist` with identifier `com.zudio.song`, conforming to `public.plain-text`. macOS registers the association at install time when Launch Services scans the app
 bundle after it is copied into Applications, or when `lsregister` is run explicitly (part of the Zudio release script). The `.onOpenURL` SwiftUI handler routes Finder double-clicks to the existing `loadFromLogURL` path, whether the app is already running or is being launched fresh.

### Document icon

A custom document icon (`zudio-doc.icns`) showing a styled "Z!" is implemented and ships with the app. `.zudio` files display with this icon in Finder rather than a generic text file icon.

---

## Pricing Strategy

### Comparable apps

- **Brian Eno's Reflection** — single generative ambient style, priced around $30 (fan/artist premium)
- **Jean Michel Jarre's EON** — single generative style, ~$9 at launch, possibly higher previously
- Both are single-style apps with a famous artist's name driving the price

### Zudio's position

Zudio is a continuous background music app in the same category — generative, non-looping, intended for focus/ambient listening. It has no famous name attached but offers four distinct styles (Ambient, Chill, Kosmic, Motorik) vs the single-style approach of the comp apps. Target audience is casual listeners who want interesting background music, not music production professionals.

### Conclusion: $4.99 universal purchase

- One purchase covers iPhone + iPad + Mac (Apple Universal Purchase)
- $4.99 is an impulse buy — no hesitation for someone browsing ambient apps
- Leaves room for promotional sales at $1.99 to spike the App Store algorithm
- At 30% Apple cut, net per sale is ~$3.50; need ~29 sales to clear the $99/year developer fee
- Subscription pricing is wrong for a "set it and forget it" background music app
- Mac version sold separately via DMG on a landing page avoids App Store cut and sandboxing restrictions

---

## TestFlight Beta Status

TestFlight is active for both iOS (iPhone/iPad) and Mac. External testing is underway — approximately a dozen testers have been invited so far. Additional testers are expected after a conference appearance on Thursday April 17, 2026.

External TestFlight requires a one-time Apple review per build (typically a few hours). Once approved, testers receive a public link — no Apple Developer team membership required.

---

## App Store Release Checklist

No dedicated website is required. The App Store listing is fully self-contained in App Store Connect. However two URLs are mandatory:

- **Support URL** — can be a GitHub repo, a simple one-page site (Carrd.co is free), or even a mailto: link. Many indie apps just use their GitHub repo URL.
- **Privacy Policy URL** — mandatory even if the app collects zero data. Use a free generator (iubenda, termsfeed) and host on GitHub Pages or Notion. Content is simple: "this app collects no personal data."

### Already done
- Apple Developer account ✓
- Bundle ID registered ✓
- TestFlight working ✓
- App icons (no alpha channel) ✓
- Version string valid (integers only) ✓
- LSHandlerRank for .zudio document type ✓

### Still needed before App Store submission

- **Support URL** — any publicly accessible URL
- **Privacy Policy URL** — required, even for zero-data apps
- **App Store screenshots** — specific sizes required: iPhone 6.5" and 6.7" displays at minimum; iPad sizes if listing as universal. These are different from TestFlight screenshots.
- **Age rating questionnaire** — short form in App Store Connect; Zudio is almost certainly 4+ (no objectionable content)
- **App Review notes** — add a note for the reviewer explaining the app is generative: "Tap Generate to create a song, then tap Play. The app generates original music each time — this is expected behavior, not a bug." Without this a reviewer may think the app is broken.
- **App description and keywords** — written by you; keywords affect search discoverability
- **Pricing** — set to $4.99, select territories

### App Store hook / key differentiator

**Tagline:** "One generative app, four moods — Ambient, Chill, Kosmic, Motorik. Always different, never loops."

**Visualizer hook:** "Generative music with a real-time visualizer that responds to every note."

The visualizer is a graphic representation of the music as it plays — you can watch the notes unfold in real time and get a sense of which instruments are active and how busy the arrangement is. It is not a full interactive instrument, but it gives you a visual connection to the music that most background music apps don't offer.


### App Store keyword strategy

The 100-character keyword field in App Store Connect is the primary lever, but title and subtitle carry more search weight than keywords.

**Title and subtitle (most important):**
- "Zudio" is unique but ungoogled — the subtitle should carry genre terms like "Generative Ambient Music" or "Focus Music Generator"
- Subtitle text is fully indexed and gets nearly title-level search weight

**The 100-character keyword field** (no spaces after commas, no repeating words from title/subtitle):
- `generative,ambient,focus,background,procedural,motorik,krautrock,electronic,meditation,lofi,study,work,chill,instrumental,drone`
- Don't repeat words in title or subtitle — they're already indexed there, wasting the 100 chars
- Commas only, no spaces — `ambient,focus` not `ambient, focus`
- No competitor names — Apple will reject for it

**What actually moves ranking after keywords are set:**
- Conversion rate (ratio of taps vs. scrolls past) — first screenshot is enormous
- Ratings volume and recency — prompt for review after a successful generate+play cycle, not on first launch
- Download velocity in the first week

**Categories:** Primary = Music, Secondary = Entertainment or Productivity. Some ambient apps list in Productivity to rank in a smaller pond.

**Localization:** Keywords can be submitted in multiple languages even for an English-only app. Spanish and German locales for "ambient music" expand search surface with no extra work.

### Review timeline

New apps typically take 1–3 days for Apple review. Music/generative apps rarely get rejected unless there is a crash on launch or a content issue. The reviewer note above is important — generative apps have been rejected in the past because reviewers didn't understand that the output is supposed to vary.

---
Copyright (c) 2026 Zack Urlocker
