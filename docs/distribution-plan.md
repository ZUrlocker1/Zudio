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
