# Bathys ⚓️
### Deep Ocean Mac Exploration, Telemetry & Disk Optimization

**Bathys** is a native, ultra-modern macOS application built entirely in SwiftUI and Swift 5.10 / Swift 6. Designed for macOS Sonoma and macOS Sequoia, Bathys is compiled as a **Universal 2 Binary** (`arm64` Apple Silicon + `x86_64` Intel) and pairs surgical disk cleaning and intelligent residual uninstallation with a nautical abyss aesthetic and zero data compromise.

---

## Key Features

1. **Scansione Profonda (Deep Ocean Scan)**
   - Algorithmic analysis of stale caches, temporary build artifacts (Xcode, Node, SPM, Cargo, Homebrew, pip), and orphaned user logs.
   - Real-time telemetry synchronized with a dynamic bathyscaphe diving visualization.
   - **Hardware-Grade Safety Guarantee:** Absolute immunity for macOS system files, user document libraries (`~/Documents`, `~/Desktop`, `~/Pictures`, etc.), and Darwin container structures (`/var/folders/.../0`, `X`, `Keychains`).

2. **Sonar Spazio (Radial Disk Telemetry)**
   - Hierarchical multi-ring sunburst visualization of disk space distribution.
   - Seamless drill-down navigation across volumes and directories.
   - Instant identification of oversized files, orphaned containers, and disk bloat.

3. **Disinstalla App (Deep Application Uninstaller)**
   - Complete application lifecycle cleaner with drag & drop support.
   - Deep correlation algorithm scanning `~/Library` and `/Library` (`Application Support`, `Containers`, `Group Containers`, `Caches`, `Preferences`, `LaunchAgents`, `Saved Application State`).
   - Clean deletion with direct movement to macOS Trash (recoverable at any time).

4. **Ottimizzazione Sistema (System Telemetry & Launch Agents Audit)**
   - Real-time CPU, RAM, and disk utilization monitoring.
   - Audit of orphaned or broken `LaunchAgents` and `LaunchDaemons`.
   - Native maintenance routines: DNS cache flushing, QuickLook thumbnail rebuild, orphaned state pruning, `.DS_Store` cleanup.

---

## Privacy & Security Manifesto

- **100% On-Device:** Zero telemetry, zero analytics, zero external network requests.
- **Trash-Only Philosophy:** Bathys **never** runs `rm -rf` permanently without user intervention. All cleaned items are moved safely to the native macOS Trash (`FileManager.default.trashItem`).
- **Apple Silicon & TCC Native:** Respects macOS Transparency, Consent, and Control (TCC) and Full Disk Access permissions.

---

## Building from Source

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0 (Sequoia)
- Xcode 15.3+ or Swift 5.10+ toolchain

```bash
cd app
swift build -c release
```

To run directly:
```bash
cd app
swift run Bathys
```

---

## License
MIT License. Crafted with precision for macOS.
