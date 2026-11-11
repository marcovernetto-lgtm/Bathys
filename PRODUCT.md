# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

Native macOS app (SwiftUI, Swift Package Manager), minimum macOS 14 Sonoma (Intel legacy build targets macOS 13). Universal binary, ad-hoc signed, distributed as DMG.

## Users
Everyone with a Mac, pro and non-pro alike: simple and safe by default for someone whose Mac is full or slow, with detail and fine control available for power users (video/motion creatives using After Effects, Premiere, DaVinci Resolve; developers using Xcode, npm, Cargo, Homebrew).

## Product Purpose
Bathys recovers disk space and keeps a Mac healthy: deep scan of caches, temporary files and developer artifacts; a radial disk map (Sonar) to find large folders; a deep app uninstaller that finds leftovers; maintenance tasks and startup-item audit. Success: the user frees real space quickly, never loses anything important, and enjoys doing it.

## Positioning
A free, private, safety-first alternative to CleanMyMac that is better on four fronts the user named as binding: safety and transparency (never deletes the wrong thing, always shows what and why, everything goes to the Trash), caches of pro apps (Adobe media caches, After Effects disk cache, Resolve CacheClip, Electron/sandboxed apps) that generic cleaners ignore, lightness and privacy (small, fast, no subscription, no data collection), and character (a playful, memorable ocean-themed experience instead of another grey utility).

## Operating Context
Used occasionally, in short sessions, often when the disk is nearly full. Window minimum 1120×680, dark appearance. Modules: Scansione Profonda, Sonar Spazio, Disinstalla App, Prestazioni, plus Settings and a Privacy/Full Disk Access onboarding sheet. Italian and English UI.

## Capabilities and Constraints
- All destructive actions move items to the macOS Trash (except an opt-in, always-confirmed empty-Trash category); confirmations before cleaning are on by default.
- Never touches files of apps that are currently open; system and personal folders are protected.
- Requires Full Disk Access for complete results; works in a reduced mode without it.
- Only network use: update check against the GitHub repository's version.json.
- App logic and module flows are settled; visual work must not change them.

## Brand Commitments
- Name: Bathys. Ocean / submarine theme, playful and themed but never heavy.
- The original visual identity is approved and binding: 3D-rendered yellow submarine mascot, fish, corals, seabed and debris (PNG assets in `app/Sources/Bathys/Assets`), periscope "BATHYS" logo, machined round action buttons, nautical console panels. A flat-vector redesign with a new design system was tried and explicitly rejected by the user ("graficamente era molto meglio prima").
- Fixes must keep this look: no truncated, clipped or cramped text; custom controls rather than stock ones.

## Evidence on Hand
No testimonials, press, user counts or benchmarks exist; do not invent any. Real measured facts available: self-test suite (22 checks) and on-device measurements from development.

## Product Principles
1. Safety is visible: the user always sees what will be removed, why it is safe, and that it goes to the Trash.
2. Calm first, depth on demand: one clear primary action per screen; details expand for those who want them.
3. Light by design: animation and decoration must cost little CPU and pause when not visible.
4. Delight with purpose: the ocean world reflects real state (depth = scan progress, debris = junk found).
5. Honest copy: no claims the app cannot back up.

## Accessibility & Inclusion
Respect Reduce Motion; keep text legible on dark surfaces (WCAG AA contrast); full keyboard operation of primary flows.
