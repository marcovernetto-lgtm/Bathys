import SwiftUI
import AppKit

// MARK: - Design System Tokens (Refined Oceanic Slate — Zero Purple/Pink, Zero Fluorescent Borders)

enum BathysPalette {
    static let abyssDark = Color(red: 0.024, green: 0.043, blue: 0.075)       // #060B13
    static let abyssSurface = Color(red: 0.055, green: 0.125, blue: 0.220)    // #0E2038
    static let abyssSky = Color(red: 0.035, green: 0.075, blue: 0.135)        // #091322

    // Right Workspace Unified Atmospheric Gradient
    static let workspaceTop = Color(red: 0.048, green: 0.088, blue: 0.148)    // #0C1626
    static let workspaceBottom = Color(red: 0.028, green: 0.052, blue: 0.092) // #070D17

    // Matte Surfaces & Neutral Hairlines (No Fluorescent Outlines)
    static let surfaceFill = Color.white.opacity(0.048)
    static let surfaceFillHover = Color.white.opacity(0.082)
    static let surfaceFillSelected = Color.white.opacity(0.105)
    static let hairline = Color.white.opacity(0.068)
    static let hairlineHover = Color.white.opacity(0.135)

    // Natural Marine & Warm Accents (Strictly No Purple, No Pink, No Neon)
    static let sky = Color(red: 0.24, green: 0.68, blue: 0.94)                // #3DADF0 (Oceanic Azure)
    static let teal = Color(red: 0.19, green: 0.75, blue: 0.68)               // #30BFAE (Seafoam Teal)
    static let amber = Color(red: 0.94, green: 0.68, blue: 0.26)              // #F0AD42 (Warm Amber)
    static let emerald = Color(red: 0.24, green: 0.76, blue: 0.53)            // #3DC287 (Kelp Green)
    static let coral = Color(red: 0.90, green: 0.45, blue: 0.36)              // #E6735C (Terracotta Coral)
    static let steel = Color(red: 0.42, green: 0.58, blue: 0.78)              // #6B94C7 (Steel Blue)
    static let yellow = Color(red: 0.96, green: 0.78, blue: 0.28)             // #F5C747 (Submarine Gold)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.64)
    static let textTertiary = Color.white.opacity(0.40)
    static let textMuted = Color.white.opacity(0.35)

    static func chartColor(for index: Int) -> Color {
        switch index % 7 {
        case 0: return sky
        case 1: return teal
        case 2: return amber
        case 3: return emerald
        case 4: return steel
        case 5: return coral
        default: return yellow
        }
    }
}

// MARK: - Asset Helper with In-Memory Static Cache

enum BathysAsset {
    private static let cache: [String: Image] = {
        let names = [
            "algae_blue_wavy", "algae_green_mid", "algae_green_tall", "algae_ribbon_center", "algae_teal_small",
            "coral_orange_anemone", "coral_orange_branch", "coral_purple_fan", "coral_red_fingers",
            "fish_blue_1", "fish_blue_2", "fish_orange_1", "fish_orange_2", "fish_pink_1", "fish_pink_2",
            "submarine_yellow", "submarine_hull", "seafloor_sand_bed", "seafloor_sand_foreground",
            "trash_oil_drum", "trash_tire", "trash_wood_crate", "trash_glass_bottle", "trash_plastic_bottle", "trash_plastic_bag",
            "bathys_periscope_logo"
        ]
        var map: [String: Image] = [:]
        for name in names {
            var nsImg: NSImage?
            // 1. Try Bundle.module (SwiftPM target resource bundle)
            if let bundleUrl = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Assets")
                ?? Bundle.module.url(forResource: name, withExtension: "png") {
                nsImg = NSImage(contentsOf: bundleUrl)
            }
            // 2. Try Bundle.main
            if nsImg == nil, let mainUrl = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Assets")
                ?? Bundle.main.url(forResource: name, withExtension: "png")
                ?? Bundle.main.resourceURL?.appendingPathComponent("Assets/\(name).png") {
                nsImg = NSImage(contentsOf: mainUrl)
            }
            // 3. Fallback for live development execution relative to source file
            if nsImg == nil {
                let devUrl = URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .appendingPathComponent("Assets/\(name).png")
                if FileManager.default.fileExists(atPath: devUrl.path) {
                    nsImg = NSImage(contentsOf: devUrl)
                }
            }
            if let img = nsImg {
                map[name] = Image(nsImage: img)
            }
        }
        return map
    }()

    static func image(named name: String) -> Image {
        if let cached = cache[name] {
            return cached
        }
        // Fallback dinamico immediato
        if let bundleUrl = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Assets")
            ?? Bundle.module.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: bundleUrl) {
            return Image(nsImage: img)
        }
        if let mainUrl = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Assets")
            ?? Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.main.resourceURL?.appendingPathComponent("Assets/\(name).png"),
           let img = NSImage(contentsOf: mainUrl) {
            return Image(nsImage: img)
        }
        let devUrl = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Assets/\(name).png")
        if let img = NSImage(contentsOf: devUrl) {
            return Image(nsImage: img)
        }
        return Image(systemName: "photo")
    }
}

// MARK: - Main ContentView Shell

struct ContentView: View {
    var autoScan: Bool = false
    var initialMode: BathysMode? = nil

    @State private var activeMode: BathysMode? = nil
    @State private var scanner = Scanner()
    @State private var sonar = SonarEngine()
    @State private var uninstaller = UninstallerEngine()
    @State private var optimizer = OptimizerEngine()
    @State private var permissionManager = PermissionManager()
    @State private var showPrivacySheet = false
    @State private var showSettingsSheet = false
    @State private var settings = AppSettings.shared

    init(autoScan: Bool = false, initialMode: BathysMode? = nil) {
        self.autoScan = autoScan
        self.initialMode = initialMode
        self._activeMode = State(initialValue: initialMode)
    }

    var body: some View {
        HStack(spacing: 0) {
            // LEFT: Pure Thematic Ocean Scene (410px, Crisp Viewport)
            LeftThemedOceanPane(
                mode: activeMode,
                scanner: scanner,
                sonar: sonar,
                uninstaller: uninstaller,
                optimizer: optimizer
            )
            .frame(width: 410)
            .frame(maxHeight: .infinity)
            .clipped()
            .overlay(alignment: .trailing) {
                // Subtle inner viewport bezel shadow before the nautical divider
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.32)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 10)
                .allowsHitTesting(false)
            }

            // THEMED NAUTICAL DEPTH-GAUGE DIVIDER
            BathysNauticalDivider()

            // RIGHT: Breathable Workspace (2x2 Hub at Opening, or Selected Module)
            ZStack {
                LinearGradient(
                    colors: [BathysPalette.workspaceTop, BathysPalette.workspaceBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let mode = activeMode {
                    activeModuleContainer(for: mode)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else {
                    homeGridHub
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(BathysPalette.abyssDark)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .sheet(isPresented: $showPrivacySheet) {
            PrivacyOnboardingSheet(
                permissionManager: permissionManager,
                onDismiss: { showPrivacySheet = false }
            )
            .presentationBackground(BathysPalette.workspaceBottom)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheetView()
                .presentationBackground(BathysPalette.workspaceBottom)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionManager.checkPermissions()
        }
        .onAppear {
            permissionManager.checkPermissions()
            if !permissionManager.hasSeenPrivacyOnboarding || CommandLine.arguments.contains("--privacy-sheet") {
                showPrivacySheet = true
            }

            activeMode = initialMode
            if let initialMode {
                triggerModeInitialLoad(for: initialMode)
                if autoScan && initialMode == .deepClean {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        scanner.scan()
                    }
                }
            }

            if CommandLine.arguments.contains("--auto-clean") {
                activeMode = .deepClean
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    scanner.scan()
                    while scanner.isScanning || !scanner.hasScanned {
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                    try? await Task.sleep(for: .milliseconds(900))
                    scanner.cleanSelectedItems()
                }
            }
        }
    }

    // MARK: - HOME HUB: Symmetrical 2x2 Grid (2 Above, 2 Below)

    private var homeGridHub: some View {
        VStack(alignment: .center, spacing: 0) {
            // 1. Hero Brand Zone — Positioned higher up with completely open sky above it
            VStack(alignment: .center, spacing: 10) {
                BathysAsset.image(named: "bathys_periscope_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 104)
                    .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 6)

                Text(L10n.homeSubtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(BathysPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 26)
            .onAppear {
                optimizer.refreshTelemetry()
            }

            // 2. Symmetrical 2x2 Grid (Centered & Enlarged Minimal Icons)
            VStack(spacing: 18) {
                HStack(spacing: 18) {
                    HomeModuleCard(mode: .deepClean) {
                        openMode(.deepClean)
                    }
                    HomeModuleCard(mode: .sonar) {
                        openMode(.sonar)
                    }
                }

                HStack(spacing: 18) {
                    HomeModuleCard(mode: .uninstaller) {
                        openMode(.uninstaller)
                    }
                    HomeModuleCard(mode: .optimizer) {
                        openMode(.optimizer)
                    }
                }
            }

            Spacer(minLength: 20)

            // 3. Unified Bottom Bar: Telemetry + Privacy & Permissions + Settings Gear
            HStack(spacing: 10) {
                // System Telemetry Pill (Click to open Optimizer)
                Button {
                    openMode(.optimizer)
                } label: {
                    HStack(spacing: 16) {
                        // Free Disk Space + Mini Bar
                        HStack(spacing: 7) {
                            Image(systemName: "internaldrive.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(BathysPalette.sky)

                            Text("\(L10n.lang == .italian ? "Disco libero:" : "Free disk:") \(ByteCountFormatter.string(fromByteCount: optimizer.diskFreeBytes, countStyle: .file))")
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(BathysPalette.textSecondary)

                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 40, height: 4)
                                Capsule()
                                    .fill(BathysPalette.sky)
                                    .frame(width: max(4, 40 * CGFloat(min(max(optimizer.diskUsedFraction, 0.05), 1.0))), height: 4)
                            }
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 1, height: 12)

                        // RAM Usage + Mini Bar
                        HStack(spacing: 7) {
                            Circle()
                                .fill(optimizer.ramUsedFraction > 0.80 ? BathysPalette.amber : BathysPalette.emerald)
                                .frame(width: 6, height: 6)

                            Text(String(format: "RAM: %.0f%%", optimizer.ramUsedFraction * 100))
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(BathysPalette.textSecondary)

                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 40, height: 4)
                                Capsule()
                                    .fill(optimizer.ramUsedFraction > 0.80 ? BathysPalette.amber : BathysPalette.emerald)
                                    .frame(width: max(4, 40 * CGFloat(min(max(optimizer.ramUsedFraction, 0.05), 1.0))), height: 4)
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 7)
                    .frame(height: 34)
                    .background(Capsule().fill(BathysPalette.surfaceFill))
                    .overlay(Capsule().strokeBorder(BathysPalette.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(L10n.lang == .italian ? "Stato disco e memoria del Mac (Clicca per Prestazioni)" : "Mac disk and memory status (Click for Optimizer)")

                // Privacy & Full Disk Access Pill
                Button {
                    showPrivacySheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: permissionManager.hasFullDiskAccess ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(permissionManager.hasFullDiskAccess ? BathysPalette.emerald : BathysPalette.amber)
                        Text(permissionManager.hasFullDiskAccess ? L10n.protectionActive : L10n.grantFullDiskAccess)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(permissionManager.hasFullDiskAccess ? BathysPalette.textSecondary : BathysPalette.amber)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .frame(height: 34)
                    .background(Capsule().fill(permissionManager.hasFullDiskAccess ? BathysPalette.surfaceFill : BathysPalette.amber.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(permissionManager.hasFullDiskAccess ? BathysPalette.hairline : BathysPalette.amber.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // Circular Settings Button
                BathysRoundIconButton(
                    icon: "gearshape.fill",
                    size: 34,
                    iconSize: 13.5,
                    tint: BathysPalette.sky,
                    rotatesOnHover: true,
                    helpText: L10n.settingsTitle
                ) {
                    showSettingsSheet = true
                }
            }
        }
        .padding(.horizontal, 56)
        .padding(.top, 22)
        .padding(.bottom, 22)
    }

    private func openMode(_ mode: BathysMode) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            activeMode = mode
        }
        triggerModeInitialLoad(for: mode)
    }

    private func returnToHomeHub() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            activeMode = nil
        }
    }

    private func triggerModeInitialLoad(for mode: BathysMode) {
        switch mode {
        case .deepClean:
            break
        case .sonar:
            sonar.refreshVolumes()
            if sonar.rootNode == nil && !sonar.isScanning {
                sonar.scan()
            }
        case .uninstaller:
            if uninstaller.apps.isEmpty && !uninstaller.isLoadingApps {
                uninstaller.loadInstalledApps()
            }
        case .optimizer:
            optimizer.refreshTelemetry()
            if optimizer.launchAgents.isEmpty && !optimizer.isScanningAgents {
                optimizer.scanLaunchAgents()
            }
        }
    }

    // MARK: - Active Module Container

    @ViewBuilder
    private func activeModuleContainer(for mode: BathysMode) -> some View {
        switch mode {
        case .deepClean:
            DeepCleanModuleView(
                scanner: scanner,
                onBack: returnToHomeHub
            )
        case .sonar:
            SonarDiskWorkspace(
                sonar: sonar,
                onBack: returnToHomeHub
            )
        case .uninstaller:
            UninstallerWorkspace(
                uninstaller: uninstaller,
                onBack: returnToHomeHub
            )
        case .optimizer:
            OptimizationWorkspace(
                optimizer: optimizer,
                onBack: returnToHomeHub
            )
        }
    }
}

// MARK: - 2x2 Home Grid Equal Button Card (Centered Enlarged Minimal Icon + Balanced Typography)

struct HomeModuleCard: View {
    let mode: BathysMode
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Subtle Top-Right Launch Indicator
                ZStack {
                    Circle()
                        .fill(isHovered ? tintColor : Color.white.opacity(0.045))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isHovered ? Color.white.opacity(0.35) : BathysPalette.hairline,
                                    lineWidth: 1
                                )
                        )

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isHovered ? Color(red: 0.03, green: 0.06, blue: 0.10) : BathysPalette.textTertiary)
                        .offset(x: isHovered ? 0.5 : 0, y: isHovered ? -0.5 : 0)
                }
                .padding(16)

                // Centered Icon + Title + Subtitle
                VStack(alignment: .center, spacing: 14) {
                    BespokeModuleIcon(mode: mode, isHovered: isHovered)
                        .frame(width: 72, height: 72)

                    VStack(alignment: .center, spacing: 5) {
                        Text(mode.title)
                            .font(.system(size: 18, weight: .semibold))
                            .tracking(-0.2)
                            .foregroundStyle(isHovered ? .white : BathysPalette.textPrimary)

                        Text(mode.shortDescription)
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(BathysPalette.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.vertical, 18)
            }
            .frame(maxWidth: .infinity, minHeight: 192, maxHeight: 192)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                isHovered ? Color.white.opacity(0.088) : Color.white.opacity(0.048),
                                isHovered ? Color.white.opacity(0.052) : Color.white.opacity(0.028)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                isHovered ? Color.white.opacity(0.24) : Color.white.opacity(0.09),
                                isHovered ? tintColor.opacity(0.32) : Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.42 : 0.20),
                radius: isHovered ? 16 : 8,
                x: 0,
                y: isHovered ? 8 : 4
            )
            .offset(y: isHovered ? -2 : 0)
        }
        .buttonStyle(TactileCardButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                isHovered = hovering
            }
        }
    }

    private var tintColor: Color {
        switch mode {
        case .deepClean: return BathysPalette.sky
        case .sonar: return BathysPalette.amber
        case .uninstaller: return BathysPalette.coral
        case .optimizer: return BathysPalette.emerald
        }
    }
}

struct TactileCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

// MARK: - Bespoke Minimal Circular Icon (72x72 Clean Symmetrical Medallion)

struct BespokeModuleIcon: View {
    let mode: BathysMode
    let isHovered: Bool

    var body: some View {
        ZStack {
            // 1. Clean Matte Circular Medallion (72x72)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.032, green: 0.060, blue: 0.108),
                            Color(red: 0.052, green: 0.095, blue: 0.162)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    tintColor.opacity(isHovered ? 0.22 : 0.10),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 34
                            )
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.32 : 0.14),
                                    tintColor.opacity(isHovered ? 0.45 : 0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.25
                        )
                )
                .shadow(color: Color.black.opacity(0.30), radius: 6, x: 0, y: 3)

            // 2. Single Minimal Inner Ring (52x52 — zero ticks, zero crosshairs)
            Circle()
                .strokeBorder(tintColor.opacity(isHovered ? 0.38 : 0.20), lineWidth: 1.2)
                .frame(width: 52, height: 52)

            // 3. Clean Minimal Symmetrical Core Vector
            switch mode {
            case .deepClean:
                DeepCleanAnimatedVector(isHovered: isHovered, tint: tintColor)
            case .sonar:
                SonarAnimatedVector(isHovered: isHovered, tint: tintColor)
            case .uninstaller:
                UninstallerAnimatedVector(isHovered: isHovered, tint: tintColor)
            case .optimizer:
                OptimizerAnimatedVector(isHovered: isHovered, tint: tintColor)
            }
        }
    }

    private var tintColor: Color {
        switch mode {
        case .deepClean: return BathysPalette.sky
        case .sonar: return BathysPalette.amber
        case .uninstaller: return BathysPalette.coral
        case .optimizer: return BathysPalette.emerald
        }
    }
}

// MARK: - 1. Deep Clean Minimal Vector (Pure Symmetrical Dual Fluid Waves)

struct DeepCleanAnimatedVector: View {
    let isHovered: Bool
    let tint: Color

    @State private var wavePhase: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let midX = size.width / 2
            let midY = size.height / 2

            // Secondary Parallel Wave (Lower, Tinted)
            var wave2 = Path()
            wave2.move(to: CGPoint(x: midX - 15, y: midY + 4.5))
            wave2.addCurve(
                to: CGPoint(x: midX + 15, y: midY + 4.5),
                control1: CGPoint(x: midX - 5 + wavePhase, y: midY - 3.5),
                control2: CGPoint(x: midX + 5 - wavePhase, y: midY + 12.5)
            )
            context.stroke(
                wave2,
                with: .color(tint.opacity(isHovered ? 0.90 : 0.65)),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
            )

            // Primary Parallel Wave (Upper, Luminous White)
            var wave1 = Path()
            wave1.move(to: CGPoint(x: midX - 15, y: midY - 3.5))
            wave1.addCurve(
                to: CGPoint(x: midX + 15, y: midY - 3.5),
                control1: CGPoint(x: midX - 5 + wavePhase, y: midY - 11.5),
                control2: CGPoint(x: midX + 5 - wavePhase, y: midY + 4.5)
            )
            context.stroke(
                wave1,
                with: .color(.white.opacity(isHovered ? 1.0 : 0.92)),
                style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
            )
        }
        .frame(width: 48, height: 48)
        .onChange(of: isHovered) { _, hovering in
            if hovering {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    wavePhase = 3.5
                }
            } else {
                withAnimation(.easeOut(duration: 0.28)) {
                    wavePhase = 0
                }
            }
        }
    }
}

// MARK: - 2. Sonar Minimal Vector (Clean Concentric Ring + Sweep Needle + Target Dot)

struct SonarAnimatedVector: View {
    let isHovered: Bool
    let tint: Color

    @State private var sweepAngle: Double = -45.0

    var body: some View {
        ZStack {
            // Single Clean Inner Range Circle (26x26)
            Circle()
                .stroke(tint.opacity(isHovered ? 0.55 : 0.35), lineWidth: 1.6)
                .frame(width: 26, height: 26)

            // Minimal Radar Sweep Sector + Needle
            ZStack {
                AngularGradient(
                    gradient: Gradient(colors: [
                        tint.opacity(isHovered ? 0.38 : 0.18),
                        tint.opacity(0.0)
                    ]),
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(60)
                )
                .clipShape(Circle())
                .frame(width: 46, height: 46)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white, tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 19, height: 2.2)
                    .offset(x: 9.5)
            }
            .rotationEffect(.degrees(sweepAngle))

            // Single Luminous Sonar Target Dot
            Circle()
                .fill(Color.white)
                .frame(width: 4.2, height: 4.2)
                .shadow(color: tint, radius: isHovered ? 4 : 1.5)
                .offset(x: 8.5, y: -8.5)

            // Center Pivot
            Circle()
                .fill(Color.white)
                .frame(width: 5.0, height: 5.0)
        }
        .frame(width: 72, height: 72)
        .onChange(of: isHovered) { _, hovering in
            if hovering {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    sweepAngle = -45.0 + 360.0
                }
            } else {
                withAnimation(.easeOut(duration: 0.35)) {
                    sweepAngle = -45.0
                }
            }
        }
    }
}

// MARK: - 3. Uninstaller Minimal Vector (Clean 2x2 Rounded Square Grid)

struct UninstallerAnimatedVector: View {
    let isHovered: Bool
    let tint: Color

    @State private var ejectOffset: CGFloat = 0.0

    var body: some View {
        ZStack {
            // 3 Symmetrical Outlined App Squares (Top-Left, Bottom-Left, Bottom-Right)
            RoundedRectangle(cornerRadius: 3.4, style: .continuous)
                .strokeBorder(tint.opacity(isHovered ? 0.85 : 0.65), lineWidth: 2.0)
                .frame(width: 12, height: 12)
                .offset(x: -7.5, y: -7.5)

            RoundedRectangle(cornerRadius: 3.4, style: .continuous)
                .strokeBorder(tint.opacity(isHovered ? 0.85 : 0.65), lineWidth: 2.0)
                .frame(width: 12, height: 12)
                .offset(x: -7.5, y: 7.5)

            RoundedRectangle(cornerRadius: 3.4, style: .continuous)
                .strokeBorder(tint.opacity(isHovered ? 0.85 : 0.65), lineWidth: 2.0)
                .frame(width: 12, height: 12)
                .offset(x: 7.5, y: 7.5)

            // Top-Right Luminous Ejecting Square
            ZStack {
                RoundedRectangle(cornerRadius: 3.4, style: .continuous)
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: tint.opacity(isHovered ? 0.60 : 0.25), radius: isHovered ? 5 : 2)

                Image(systemName: "xmark")
                    .font(.system(size: 6.5, weight: .black))
                    .foregroundStyle(Color(red: 0.04, green: 0.07, blue: 0.12))
            }
            .offset(x: 7.5 + ejectOffset, y: -7.5 - ejectOffset)
        }
        .frame(width: 72, height: 72)
        .onChange(of: isHovered) { _, hovering in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                ejectOffset = hovering ? 2.5 : 0.0
            }
        }
    }
}

// MARK: - 4. Optimizer Minimal Vector (Clean Centered Speedometer Arc + Needle)

struct OptimizerAnimatedVector: View {
    let isHovered: Bool
    let tint: Color

    @State private var needleAngle: Double = -45.0

    var body: some View {
        ZStack {
            // Minimal 240° Gauge Arc Centered at (0,0)
            Canvas { context, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r: CGFloat = 15.0

                // Track Arc (150° to 30°)
                var trackArc = Path()
                trackArc.addArc(
                    center: c,
                    radius: r,
                    startAngle: .degrees(150),
                    endAngle: .degrees(30),
                    clockwise: false
                )
                context.stroke(
                    trackArc,
                    with: .color(tint.opacity(isHovered ? 0.65 : 0.45)),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )

                // Luminous Boost Tip (310° to 30°)
                var boostArc = Path()
                boostArc.addArc(
                    center: c,
                    radius: r,
                    startAngle: .degrees(310),
                    endAngle: .degrees(30),
                    clockwise: false
                )
                context.stroke(
                    boostArc,
                    with: .color(.white.opacity(isHovered ? 1.0 : 0.90)),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                )
            }
            .frame(width: 48, height: 48)

            // Clean Needle
            Capsule()
                .fill(.white)
                .frame(width: 14, height: 2.2)
                .offset(x: 7.0)
                .rotationEffect(.degrees(needleAngle))

            // Center Pivot
            Circle()
                .fill(Color.white)
                .frame(width: 5.0, height: 5.0)
        }
        .frame(width: 72, height: 72)
        .onChange(of: isHovered) { _, hovering in
            withAnimation(.spring(response: 0.34, dampingFraction: 0.56)) {
                needleAngle = hovering ? 25.0 : -45.0
            }
        }
    }
}

// MARK: - Shared Back Button Bar ("‹ Strumenti")

struct WorkspaceTopBar<Trailing: View>: View {
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing
    @State private var hoverBack = false

    var body: some View {
        HStack(alignment: .center) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.toolsBack)
                        .font(.system(size: 13.5, weight: .medium))
                }
                .foregroundStyle(hoverBack ? .white : BathysPalette.textSecondary)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(hoverBack ? BathysPalette.surfaceFillHover : BathysPalette.surfaceFill)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(BathysPalette.hairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { hoverBack = $0 }

            Spacer()

            trailing()
        }
    }
}

// MARK: - Bathys Machined Round Controls (Zero Glossy AI Bubble, Zero Neon Blur, High-Craft Instrument Precision)

struct BathysRoundIconButton: View {
    let icon: String
    var size: CGFloat = 28
    var iconSize: CGFloat = 12
    var tint: Color = BathysPalette.sky
    var isDestructive: Bool = false
    var rotatesOnHover: Bool = false
    var helpText: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    private var activeColor: Color {
        isDestructive ? BathysPalette.coral : tint
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isHovered
                            ? activeColor.opacity(isDestructive ? 0.18 : 0.14)
                            : Color.white.opacity(0.045)
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        isHovered ? activeColor.opacity(0.55) : Color.white.opacity(0.14),
                                        isHovered ? activeColor.opacity(0.22) : Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                    )

                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(isHovered ? (isDestructive ? BathysPalette.coral : .white) : BathysPalette.textSecondary)
                    .rotationEffect(.degrees(rotatesOnHover && isHovered ? 45 : 0))
            }
            .contentShape(Circle())
        }
        .buttonStyle(TactileRoundMicroButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                isHovered = hovering
            }
        }
        .help(helpText ?? "")
    }
}

struct BathysRoundCheckButton: View {
    @Binding var isSelected: Bool
    var tint: Color = BathysPalette.sky
    var size: CGFloat = 20

    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.70)) {
                isSelected.toggle()
            }
        } label: {
            ZStack {
                // Outer machined bezel ring
                Circle()
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [tint, tint.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.09 : 0.035),
                                    Color.black.opacity(0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected
                                    ? Color.white.opacity(0.38)
                                    : (isHovered ? tint.opacity(0.55) : Color.white.opacity(0.20)),
                                lineWidth: 1.15
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(0.30),
                        radius: 2,
                        x: 0,
                        y: 1
                    )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.48, weight: .bold))
                        .foregroundStyle(Color(red: 0.024, green: 0.043, blue: 0.075))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: size + 4, height: size + 4)
            .contentShape(Circle())
        }
        .buttonStyle(TactileRoundMicroButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }
}

struct TactileRoundMicroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Bathys Machined Bathymetric Instrument Button (Zero Glossy Bubble, Precision Gauge Bezel)

struct CircularActionOrbButton: View {
    let label: String
    var iconName: String? = nil
    var tint: Color = BathysPalette.sky
    var isDisabled: Bool = false
    var shortcutHint: String? = nil
    let action: () -> Void

    @State private var isHovered = false
    @State private var dialRotation: Double = 0.0

    var body: some View {
        Button(action: action) {
            ZStack {
                // 1. Recessed Anodized Instrument Socket (126pt)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.020, green: 0.038, blue: 0.068),
                                Color(red: 0.045, green: 0.082, blue: 0.138)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 126, height: 126)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.65),
                                        Color.white.opacity(0.14)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.55), radius: 12, x: 0, y: 6)

                // 2. Precision 60-Tick Bathymetric Compass Ring & Active Sector Arc
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let outerR: CGFloat = 58.5
                    let tickCount = 60

                    for i in 0..<tickCount {
                        let isMajor = (i % 5 == 0)
                        let isCardinal = (i % 15 == 0)
                        let angle = Double(i) * (2.0 * .pi / Double(tickCount))
                        let innerR = outerR - (isCardinal ? 5.5 : (isMajor ? 4.0 : 2.2))

                        let p1 = CGPoint(
                            x: center.x + innerR * CGFloat(cos(angle)),
                            y: center.y + innerR * CGFloat(sin(angle))
                        )
                        let p2 = CGPoint(
                            x: center.x + outerR * CGFloat(cos(angle)),
                            y: center.y + outerR * CGFloat(sin(angle))
                        )

                        var tick = Path()
                        tick.move(to: p1)
                        tick.addLine(to: p2)

                        let tickOpacity: Double = isCardinal
                            ? (isHovered ? 0.90 : 0.55)
                            : (isMajor ? (isHovered ? 0.55 : 0.30) : (isHovered ? 0.28 : 0.14))
                        let tickColor = isCardinal ? tint.opacity(tickOpacity) : Color.white.opacity(tickOpacity)

                        context.stroke(
                            tick,
                            with: .color(tickColor),
                            style: StrokeStyle(lineWidth: isCardinal ? 1.5 : 1.0, lineCap: .round)
                        )
                    }
                }
                .frame(width: 126, height: 126)
                .rotationEffect(.degrees(dialRotation))

                // 3. Illuminated Perimeter Gauge Ring on Hover
                Circle()
                    .trim(from: 0.0, to: isHovered ? 1.0 : 0.25)
                    .stroke(
                        AngularGradient(
                            colors: [
                                tint.opacity(0.05),
                                tint.opacity(isHovered ? 0.85 : 0.35),
                                Color.white.opacity(isHovered ? 0.90 : 0.45),
                                tint.opacity(0.05)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .frame(width: 108, height: 108)
                    .rotationEffect(.degrees(isHovered ? 15 : -90))

                // 4. Tactile Matte-Satin Actuator Core (102pt — Zero Glossy Bubble, Machined Metallic Step)
                Circle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: isHovered ? tint.opacity(0.32) : tint.opacity(0.20), location: 0.0),
                                .init(color: Color(red: 0.058, green: 0.112, blue: 0.188), location: 0.55),
                                .init(color: Color(red: 0.035, green: 0.068, blue: 0.120), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 102, height: 102)
                    .overlay(
                        // Subtle top-down physical illumination (no off-center radial blob)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(isHovered ? 0.26 : 0.12),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    )
                    .overlay(
                        // Crisp 1px Machined Chamfer Rim
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(isHovered ? 0.55 : 0.32), location: 0.0),
                                        .init(color: tint.opacity(isHovered ? 0.65 : 0.35), location: 0.45),
                                        .init(color: Color.black.opacity(0.55), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.25
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(0.55),
                        radius: 8,
                        x: 0,
                        y: 4
                    )

                // 5. Crisp Instrument Icon, Typography & Monospaced Shortcut Tag
                VStack(spacing: 5) {
                    if let icon = iconName {
                        ZStack {
                            Circle()
                                .fill(tint.opacity(isHovered ? 0.24 : 0.14))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(tint.opacity(isHovered ? 0.55 : 0.28), lineWidth: 1.0)
                                )

                            Image(systemName: icon)
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(isHovered ? .white : tint)
                        }
                    }

                    Text(label.uppercased())
                        .font(.system(size: label.count > 9 ? 10.0 : 11.0, weight: .bold))
                        .tracking(label.count > 9 ? 0.9 : 1.4)
                        .foregroundStyle(.white)

                    if let hint = shortcutHint {
                        Text(hint)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.38))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(tint.opacity(0.30), lineWidth: 0.8)
                            )
                    }
                }
                .offset(y: shortcutHint != nil ? 1 : 0)
            }
            .scaleEffect(isHovered && !isDisabled ? 1.025 : 1.0)
        }
        .buttonStyle(TactileOrbButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.38 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) {
                isHovered = hovering
                dialRotation = hovering ? 18.0 : 0.0
            }
        }
    }
}

struct TactileOrbButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .animation(.spring(response: 0.16, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - MODULE 1: SCANSIONE PROFONDA (Native Bathys Deep Clean)

struct DeepCleanModuleView: View {
    @Bindable var scanner: Scanner
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top bar
            WorkspaceTopBar(onBack: onBack) {
                if scanner.hasScanned && !scanner.isScanning {
                    Button {
                        scanner.scan()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                            Text(L10n.lang == .italian ? "Riscansiona" : "Rescan")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(BathysPalette.textSecondary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(BathysPalette.surfaceFill))
                        .overlay(Capsule().strokeBorder(BathysPalette.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 52)
            .padding(.top, 30)

            ZStack {
                if scanner.isScanning {
                    scanningProgressBody
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if scanner.hasScanned {
                    scannedResultsBody
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    preScanHeroBody
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: scanner.isScanning)
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: scanner.hasScanned)
        }
        .sheet(isPresented: $scanner.showCleanConfirmation) {
            let trashCat = scanner.categories.first(where: { $0.id == "trash" })
            let hasPermanentTrash = (trashCat?.isSelected == true) && ((trashCat?.selectedBytes ?? 0) > 0)
            let previewItems: [TrashPreviewItem] = scanner.categories
                .filter { $0.isSelected && $0.selectedBytes > 0 }
                .map { cat in
                    let firstPath = cat.topItems.first(where: { $0.isSelected })?.path
                    return TrashPreviewItem(
                        name: cat.title,
                        detail: cat.subtitle,
                        bytes: cat.selectedBytes,
                        path: firstPath
                    )
                }

            TrashConfirmationSheet(
                title: L10n.lang == .italian ? "Spostare i file selezionati nel Cestino?" : "Move selected files to Trash?",
                subtitle: L10n.lang == .italian
                    ? "I file temporanei e le cache selezionate verranno spostati nel Cestino. Le cartelle strutturali di macOS e le sessioni delle app aperte restano protette."
                    : "Selected temporary files and caches will be moved to the Trash. macOS structural folders and active app sessions remain protected.",
                bytes: scanner.selectedBytes,
                confirmLabel: L10n.lang == .italian ? "Pulisci" : "Clean",
                includesPermanentTrash: hasPermanentTrash,
                previewItems: previewItems,
                onCancel: { scanner.showCleanConfirmation = false },
                onConfirm: { scanner.cleanSelectedItems() }
            )
            .presentationBackground(BathysPalette.workspaceBottom)
        }
    }

    // 1A. Pre-Scan State (Real Interactive Inspection Targets — Zero AI Pill Badges or Fake Feature Lists)
    private var preScanHeroBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(L10n.lang == .italian ? "Scansione Profonda" : "Deep Clean")
                            .font(.system(size: 34, weight: .light))
                            .tracking(-0.5)
                            .foregroundStyle(BathysPalette.textPrimary)

                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(BathysPalette.emerald)
                            Text(L10n.lang == .italian
                                 ? "\(scanner.protectedRunningAppsCount) app aperte protette"
                                 : "\(scanner.protectedRunningAppsCount) open apps protected")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(BathysPalette.emerald)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(BathysPalette.emerald.opacity(0.11)))
                        .overlay(Capsule().strokeBorder(BathysPalette.emerald.opacity(0.28), lineWidth: 1))
                    }

                    Text(L10n.lang == .italian
                         ? "Seleziona le aree di sistema da ispezionare. Nessun file viene rimosso senza conferma."
                         : "Select the system areas to inspect. No files are removed without confirmation.")
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(BathysPalette.textSecondary)
                }

                Spacer()

                let allSelected = scanner.categories.allSatisfy { $0.isSelected }
                Button {
                    let target = !allSelected
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.75)) {
                        for i in scanner.categories.indices {
                            scanner.categories[i].isSelected = target
                        }
                    }
                } label: {
                    Text(allSelected ? L10n.deselectAll : L10n.selectAll)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(BathysPalette.sky)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 52)
            .padding(.top, 18)
            .padding(.bottom, 14)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 7) {
                    ForEach($scanner.categories) { $cat in
                        SpaciousCategoryCard(category: $cat, hasScanned: false)
                    }
                }
                .padding(.horizontal, 52)
                .padding(.vertical, 2)
            }

            // Bottom Machined Scan Instrument Button
            HStack {
                Spacer()
                CircularActionOrbButton(
                    label: L10n.scanBtn,
                    iconName: "waveform.path.ecg",
                    tint: BathysPalette.sky,
                    isDisabled: !scanner.categories.contains(where: { $0.isSelected })
                ) {
                    scanner.scan()
                }
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 22)
        }
    }

    // 1B. Calm Scanning State
    private var scanningProgressBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(BathysPalette.sky)
                        .frame(width: 6, height: 6)
                    Text(L10n.scanningInProgress)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(BathysPalette.sky)
                }

                Text(ByteCountFormatter.string(fromByteCount: scanner.selectedBytes, countStyle: .file))
                    .font(.system(size: 56, weight: .light))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: scanner.selectedBytes)
                    .foregroundStyle(BathysPalette.textPrimary)

                Text(scanner.currentPath.isEmpty ? "Controllo cartelle di sistema…" : scanner.currentPath)
                    .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(BathysPalette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 480, alignment: .leading)
            }
            .padding(.bottom, 28)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 4)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [BathysPalette.sky, BathysPalette.teal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(16, geo.size.width * CGFloat(scanner.depth)), height: 4)
                        .animation(.easeOut(duration: 0.22), value: scanner.depth)
                }
            }
            .frame(height: 4)
            .frame(maxWidth: 440)

            Spacer()
        }
        .padding(.horizontal, 52)
    }

    // 1C. Clean, Breathable Post-Scan Results
    private var scannedResultsBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Summary
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        if scanner.lastCleanedBytes > 0 {
                            Text("\(L10n.cleanupComplete) • \(ByteCountFormatter.string(fromByteCount: scanner.lastCleanedBytes, countStyle: .file))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(BathysPalette.emerald)
                        } else {
                            Text(L10n.lang == .italian ? "Risultati della scansione" : "Scan Results")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(BathysPalette.textSecondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(BathysPalette.emerald)
                            Text(L10n.lang == .italian
                                 ? "\(scanner.protectedRunningAppsCount) app in uso protette"
                                 : "\(scanner.protectedRunningAppsCount) active apps protected")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(BathysPalette.emerald)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(BathysPalette.emerald.opacity(0.11)))
                        .overlay(Capsule().strokeBorder(BathysPalette.emerald.opacity(0.28), lineWidth: 1))
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(ByteCountFormatter.string(fromByteCount: scanner.selectedBytes, countStyle: .file))
                            .font(.system(size: 38, weight: .light))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: scanner.selectedBytes)
                            .foregroundStyle(BathysPalette.textPrimary)

                        Text(L10n.readyForCleanup)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(BathysPalette.textSecondary)
                    }
                }

                Spacer()

                let allSelected = scanner.categories.allSatisfy { $0.isSelected }
                Button {
                    let target = !allSelected
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.75)) {
                        for i in scanner.categories.indices {
                            scanner.categories[i].isSelected = target
                        }
                    }
                } label: {
                    Text(allSelected ? L10n.deselectAll : L10n.selectAll)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BathysPalette.sky)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 52)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Clean Category List (Fits non-zero categories cleanly with breathing room)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 7) {
                    ForEach($scanner.categories) { $cat in
                        if cat.bytes > 0 || scanner.categories.allSatisfy({ $0.bytes == 0 }) {
                            SpaciousCategoryCard(category: $cat, hasScanned: true)
                        }
                    }
                }
                .padding(.horizontal, 52)
                .padding(.vertical, 2)
            }

            // Bottom Action Bar with Breathing Room
            HStack {
                Spacer()
                CircularActionOrbButton(
                    label: L10n.cleanBtn,
                    iconName: "sparkles",
                    tint: BathysPalette.teal,
                    isDisabled: scanner.selectedBytes == 0
                ) {
                    if AppSettings.shared.confirmBeforeClean {
                        scanner.showCleanConfirmation = true
                    } else {
                        scanner.cleanSelectedItems()
                    }
                }
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 22)
        }
    }
}

// MARK: - Clean Category Row (Tactile Round Controls, Zero Fluorescent Borders)

struct SpaciousCategoryCard: View {
    @Binding var category: ScanCategory
    var hasScanned: Bool = true
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                BathysRoundCheckButton(
                    isSelected: $category.isSelected,
                    tint: accentColor,
                    size: 19
                )

                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .strokeBorder(accentColor.opacity(0.24), lineWidth: 1)
                        )

                    Image(systemName: category.symbol)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(category.title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(category.isSelected ? BathysPalette.textPrimary : BathysPalette.textSecondary)

                    Text(category.subtitle)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(BathysPalette.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                if !hasScanned {
                    Text(category.isSelected
                         ? (L10n.lang == .italian ? "Incluso" : "Included")
                         : (L10n.lang == .italian ? "Escluso" : "Skipped"))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(category.isSelected ? BathysPalette.textSecondary : BathysPalette.textTertiary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.04)))
                        .overlay(Capsule().strokeBorder(BathysPalette.hairline, lineWidth: 1))
                } else if category.bytes > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: category.selectedBytes, countStyle: .file))
                        .font(.system(size: 13.5, weight: .medium))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(category.isSelected ? BathysPalette.textPrimary : BathysPalette.textTertiary)
                } else {
                    Text("Zero KB")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(BathysPalette.textTertiary)
                }

                if hasScanned && !category.topItems.isEmpty {
                    BathysRoundIconButton(
                        icon: category.isExpanded ? "chevron.down" : "chevron.right",
                        size: 24,
                        iconSize: 10,
                        tint: accentColor
                    ) {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.80)) {
                            category.isExpanded.toggle()
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .onTapGesture {
                if hasScanned && !category.topItems.isEmpty {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.80)) {
                        category.isExpanded.toggle()
                    }
                } else if !hasScanned {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                        category.isSelected.toggle()
                    }
                }
            }

            if hasScanned && category.isExpanded && !category.topItems.isEmpty {
                VStack(spacing: 4) {
                    ForEach($category.topItems) { $item in
                        HStack(spacing: 10) {
                            BathysRoundCheckButton(
                                isSelected: $item.isSelected,
                                tint: accentColor,
                                size: 16
                            )

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.system(size: 12.5, weight: .regular))
                                    .foregroundStyle(item.isSelected ? BathysPalette.textSecondary : BathysPalette.textTertiary)
                                    .lineLimit(1)

                                if let safetyNote = item.safetyNote {
                                    Text(safetyNote)
                                        .font(.system(size: 10.5, weight: .regular))
                                        .foregroundStyle(BathysPalette.textTertiary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Text(item.formattedSize)
                                .font(.system(size: 12.5, weight: .regular))
                                .monospacedDigit()
                                .foregroundStyle(BathysPalette.textSecondary)

                            BathysRoundIconButton(
                                icon: "magnifyingglass",
                                size: 24,
                                iconSize: 10.5,
                                tint: accentColor,
                                helpText: L10n.lang == .italian ? "Mostra nel Finder" : "Reveal in Finder"
                            ) {
                                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                    }
                }
                .padding(.leading, 40)
                .padding(.trailing, 14)
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hover ? BathysPalette.surfaceFillHover : BathysPalette.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(hover ? BathysPalette.hairlineHover : BathysPalette.hairline, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                hover = hovering
            }
        }
    }

    private var accentColor: Color {
        switch category.id {
        case "caches": return BathysPalette.sky
        case "temp": return BathysPalette.amber
        case "dev": return BathysPalette.teal
        case "logs": return BathysPalette.steel
        case "xcode": return BathysPalette.emerald
        case "orphans": return BathysPalette.yellow
        case "trash": return BathysPalette.coral
        default: return BathysPalette.sky
        }
    }
}

// MARK: - Dynamic Diving Submarine (Surface to Seafloor — Strictly Synchronized to Scan Progress)

struct VacuumRecoveryBeam: View {
    let time: Double

    var body: some View {
        Canvas { context, size in
            var cone = Path()
            let topW: CGFloat = 34.0
            let bottomW: CGFloat = 130.0
            let h = size.height

            cone.move(to: CGPoint(x: size.width * 0.5 - topW * 0.5, y: 0))
            cone.addLine(to: CGPoint(x: size.width * 0.5 + topW * 0.5, y: 0))
            cone.addLine(to: CGPoint(x: size.width * 0.5 + bottomW * 0.5, y: h))
            cone.addLine(to: CGPoint(x: size.width * 0.5 - bottomW * 0.5, y: h))
            cone.closeSubpath()

            let pulse = 0.55 + sin(time * 8.0) * 0.16
            context.opacity = pulse
            context.fill(
                cone,
                with: .linearGradient(
                    Gradient(colors: [
                        BathysPalette.teal.opacity(0.85),
                        BathysPalette.sky.opacity(0.35),
                        Color.clear
                    ]),
                    startPoint: CGPoint(x: size.width * 0.5, y: 0),
                    endPoint: CGPoint(x: size.width * 0.5, y: h)
                )
            )

            // Ascending energy / bubble particles inside the suction beam
            for i in 0..<7 {
                let tSpeed = 65.0
                let yPos = h - CGFloat(fmod(time * tSpeed + Double(i * 15), Double(h)))
                let spread = (yPos / h) * (bottomW * 0.42)
                let xOffset = sin(time * 4.5 + Double(i)) * spread
                let pSize: CGFloat = 3.5 + CGFloat(i % 3)
                let pRect = CGRect(x: size.width * 0.5 + xOffset - pSize * 0.5, y: yPos - pSize * 0.5, width: pSize, height: pSize)
                context.opacity = 0.80
                context.fill(Path(ellipseIn: pRect), with: .color(.white))
            }
        }
        .frame(width: 150, height: 110)
    }
}

struct DynamicDivingSubmarine: View {
    let time: Double
    let containerSize: CGSize
    let isScanning: Bool
    let hasScanned: Bool
    var isCleaning: Bool = false
    var isResurfacing: Bool = false
    var scanStartedAt: Date? = nil
    var resurfaceStartedAt: Date? = nil
    let depth: Double

    private var continuousProgress: Double {
        if isCleaning {
            return 1.0
        } else if isResurfacing {
            if let start = resurfaceStartedAt {
                let elapsed = max(0.0, Date.now.timeIntervalSince(start))
                let r = min(1.0, elapsed / 2.0)
                // Quintic smoothstep per risalita continua e morbida (C2 continuity)
                let smooth = r * r * r * (r * (r * 6.0 - 15.0) + 10.0)
                return max(0.0, 1.0 - smooth)
            }
            return 0.0
        } else if hasScanned {
            // Se la scansione è terminata, staziona stabilmente a fondale (1.0)
            return 1.0
        } else if isScanning {
            // DISCESA CONTINUA & FLUIDA:
            // Non segue gli scatti a gradini della barra o delle singole cartelle,
            // ma effettua un'immersione idrodinamica organica e ininterrotta a 60/120 FPS.
            let elapsed = max(0.0, Date.now.timeIntervalSince(scanStartedAt ?? .now))
            let diveDuration: Double = 3.5 // Secondi per completare la discesa fluida (sincronizzata con le 6 categorie)
            let t = min(1.0, elapsed / diveDuration)
            // Curva C2-continua quintica (accelerazione fluida iniziale, crociera e planata sul fondale)
            let smooth = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
            return min(1.0, smooth)
        } else {
            return 0.0
        }
    }

    var body: some View {
        let w = containerSize.width
        let h = containerSize.height

        let surfaceY: CGFloat = 95.0
        let seafloorY: CGFloat = max(surfaceY + 80, h - 145.0)

        let u = continuousProgress
        let currentBaseY = surfaceY + CGFloat(u) * (seafloorY - surfaceY)
        let bobY = sin(time * 1.3) * (isScanning ? 1.5 : 3.5)

        // Assetto del batiscafo: inclinazione idrodinamica continua (+8.0° in discesa, -7.5° in risalita)
        let diveTilt: Double = {
            if isResurfacing && u > 0.02 && u < 0.98 {
                return -sin(u * .pi) * 7.5
            } else if isScanning && u > 0.01 && u < 0.99 {
                return sin(u * .pi) * 8.0
            } else {
                return 0.0
            }
        }()
        let currentPitch = diveTilt + sin(time * 1.5) * 1.0

        let headlightAlpha = (isScanning || isCleaning || (hasScanned && u > 0.08)) ? min(1.0, max(0.0, (u - 0.08) * 2.5)) : 0.0
        let bubblesAlpha = ((isScanning || isResurfacing) && u > 0.02 && u < 0.98) ? sin(u * .pi) : 0.0
        let rippleAlpha = max(0.0, 1.0 - u * 2.8)

        ZStack {
            SurfaceBoatRipple(time: time)
                .position(x: w * 0.50, y: 115)
                .opacity(rippleAlpha)

            ZStack {
                if isCleaning {
                    VacuumRecoveryBeam(time: time)
                        .position(x: 175 * 0.5 - 6, y: 140 * 0.5 + 85)
                }

                VolumetricHeadlightCone(isScanning: isScanning)
                    .position(x: 175 * 0.5 - 90, y: 140 * 0.5 + 16)
                    .opacity(headlightAlpha)

                PropellerBubblesView(time: time)
                    .position(x: 175 * 0.5 + 75, y: 140 * 0.5 + 12)
                    .opacity(bubblesAlpha)

                BathysAsset.image(named: "submarine_yellow")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 175, height: 140)
                    .shadow(color: Color.black.opacity(0.35), radius: 12, y: 8)
            }
            .frame(width: 175, height: 140)
            .rotationEffect(.degrees(currentPitch))
            .position(x: w * 0.50, y: currentBaseY + bobY)
        }
        .frame(width: w, height: h)
        .allowsHitTesting(false)
    }
}

// MARK: - Animated Water Surface Waves & Meniscus

struct AnimatedWaterSurfaceWave: View {
    let time: Double
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let waterlineY: CGFloat = 115.0

        Canvas { context, size in
            var bodyPath = Path()
            bodyPath.move(to: CGPoint(x: 0, y: waterlineY))
            for x in stride(from: 0, through: size.width, by: 10) {
                let wave = sin(x * 0.025 + time * 1.8) * 4.0
                         + cos(x * 0.045 - time * 1.2) * 2.5
                bodyPath.addLine(to: CGPoint(x: x, y: waterlineY + wave))
            }
            bodyPath.addLine(to: CGPoint(x: size.width, y: size.height))
            bodyPath.addLine(to: CGPoint(x: 0, y: size.height))
            bodyPath.closeSubpath()

            context.opacity = 0.26
            context.fill(
                bodyPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.1, green: 0.5, blue: 0.85),
                        Color.clear
                    ]),
                    startPoint: CGPoint(x: 0, y: waterlineY),
                    endPoint: CGPoint(x: 0, y: waterlineY + 80)
                )
            )

            var crestPath = Path()
            crestPath.move(to: CGPoint(x: 0, y: waterlineY))
            for x in stride(from: 0, through: size.width, by: 10) {
                let wave = sin(x * 0.025 + time * 1.8) * 4.0
                         + cos(x * 0.045 - time * 1.2) * 2.5
                crestPath.addLine(to: CGPoint(x: x, y: waterlineY + wave))
            }

            context.opacity = 0.68
            context.stroke(crestPath, with: .color(Color(red: 0.32, green: 0.80, blue: 0.96)), lineWidth: 1.6)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

struct SurfaceBoatRipple: View {
    let time: Double

    var body: some View {
        Canvas { context, size in
            let ripplePhase = (time.truncatingRemainder(dividingBy: 1.8)) / 1.8
            let rW = 60.0 + CGFloat(ripplePhase) * 45.0
            let rH = 8.0 + CGFloat(ripplePhase) * 6.0
            let alpha = (1.0 - ripplePhase) * 0.45

            let rect = CGRect(x: -rW / 2, y: -rH / 2, width: rW, height: rH)
            context.opacity = alpha
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(Color(red: 0.4, green: 0.85, blue: 0.98)),
                lineWidth: 1.2
            )
        }
        .frame(width: 120, height: 30)
    }
}

// MARK: - Volumetric Sun Rays & Caustics

struct VolumetricSunRaysView: View {
    let time: Double
    let width: CGFloat
    let height: CGFloat

    // Beam configuration: (relative start X, top width, bottom width, drift speed, spread angle, max alpha)
    private struct RaySpec {
        let xFrac: CGFloat
        let topWidth: CGFloat
        let botWidth: CGFloat
        let speed: Double
        let spread: CGFloat
        let maxAlpha: Double
    }

    private static let rays: [RaySpec] = [
        RaySpec(xFrac: 0.08, topWidth: 26, botWidth: 130, speed: 0.14, spread: 110, maxAlpha: 0.15),
        RaySpec(xFrac: 0.28, topWidth: 18, botWidth: 95, speed: 0.18, spread: 95, maxAlpha: 0.18),
        RaySpec(xFrac: 0.48, topWidth: 32, botWidth: 155, speed: 0.12, spread: 120, maxAlpha: 0.14),
        RaySpec(xFrac: 0.68, topWidth: 20, botWidth: 110, speed: 0.16, spread: 105, maxAlpha: 0.16),
        RaySpec(xFrac: 0.85, topWidth: 30, botWidth: 140, speed: 0.13, spread: 115, maxAlpha: 0.13),
    ]

    var body: some View {
        let startY: CGFloat = 116.0

        // Single Zero-Offscreen-Buffer Canvas Pass (Clipped directly to the dynamic wave path)
        Canvas { context, size in
            let waterlineY: CGFloat = 115.0
            var maskPath = Path()
            maskPath.move(to: CGPoint(x: 0, y: waterlineY))
            for x in stride(from: 0, through: size.width, by: 10) {
                let wave = sin(x * 0.025 + time * 1.8) * 4.0
                         + cos(x * 0.045 - time * 1.2) * 2.5
                maskPath.addLine(to: CGPoint(x: x, y: waterlineY + wave))
            }
            maskPath.addLine(to: CGPoint(x: size.width, y: size.height))
            maskPath.addLine(to: CGPoint(x: 0, y: size.height))
            maskPath.closeSubpath()

            context.clip(to: maskPath)
            context.blendMode = .plusLighter

            // 1. Soft Volumetric Sun Beams
            for (i, ray) in Self.rays.enumerated() {
                let rayTime = time * ray.speed + Double(i) * 1.618
                let sway = sin(rayTime) * 14.0
                let intensity = (sin(rayTime * 1.25) * 0.35 + 0.65) * ray.maxAlpha

                let startX = size.width * ray.xFrac + sway
                let endX = startX + ray.spread + sway * 1.3

                var path = Path()
                path.move(to: CGPoint(x: startX - ray.topWidth * 0.45, y: startY))
                path.addLine(to: CGPoint(x: startX + ray.topWidth * 0.45, y: startY))
                path.addLine(to: CGPoint(x: endX + ray.botWidth * 0.45, y: size.height * 0.85))
                path.addLine(to: CGPoint(x: endX - ray.botWidth * 0.45, y: size.height * 0.85))
                path.closeSubpath()

                context.opacity = intensity * 0.42
                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: Color(red: 0.55, green: 0.88, blue: 0.99).opacity(0.32), location: 0.0),
                            .init(color: Color(red: 0.22, green: 0.68, blue: 0.94).opacity(0.16), location: 0.30),
                            .init(color: Color(red: 0.06, green: 0.42, blue: 0.78).opacity(0.05), location: 0.65),
                            .init(color: Color.clear, location: 1.0)
                        ]),
                        startPoint: CGPoint(x: startX, y: startY),
                        endPoint: CGPoint(x: endX, y: size.height * 0.85)
                    )
                )
            }

            // 2. Marine Sunlit Motes
            let moteCount = 14
            for j in 0..<moteCount {
                let seed = Double(j)
                let moteTime = time * 0.18 + seed * 1.618
                let normX = (fmod(seed * 0.173 + moteTime * 0.038, 1.0) + 1.0).truncatingRemainder(dividingBy: 1.0)
                let normY = (fmod(seed * 0.241 + moteTime * 0.060, 1.0) + 1.0).truncatingRemainder(dividingBy: 1.0)

                let px = normX * size.width + sin(moteTime * 1.4) * 8.0
                let py = 135.0 + normY * (size.height * 0.65)

                let radius = 1.0 + (fmod(seed * 3.7, 1.6))
                let alpha = (sin(moteTime * 2.4) * 0.30 + 0.70) * 0.20

                let rect = CGRect(x: px - radius, y: py - radius, width: radius * 2, height: radius * 2)
                context.opacity = alpha
                context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.65, green: 0.92, blue: 1.0)))
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

struct WaterCausticsLayer: View {
    let time: Double
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            context.opacity = 0.035
            for i in 0..<5 {
                let yPos = 140.0 + CGFloat(i) * 65.0
                if yPos > size.height - 80 { continue }
                var path = Path()
                path.move(to: CGPoint(x: 0, y: yPos))
                for x in stride(from: 0, through: size.width, by: 18) {
                    let wave = sin(x * 0.035 + time * 1.4 + Double(i)) * 5.0
                             + cos(x * 0.05 - time * 1.1) * 3.5
                    path.addLine(to: CGPoint(x: x, y: yPos + wave))
                }
                context.stroke(path, with: .color(BathysPalette.sky), lineWidth: 2.0)
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

struct VolumetricHeadlightCone: View {
    let isScanning: Bool

    var body: some View {
        Canvas { context, size in
            let beamLength: CGFloat = 140
            let beamWidth: CGFloat = 65

            var path = Path()
            path.move(to: CGPoint(x: size.width, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width - beamLength, y: size.height / 2 - beamWidth / 2))
            path.addLine(to: CGPoint(x: size.width - beamLength, y: size.height / 2 + beamWidth / 2))
            path.closeSubpath()

            context.opacity = isScanning ? 0.30 : 0.16
            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        BathysPalette.sky.opacity(0.75),
                        BathysPalette.sky.opacity(0.15),
                        Color.clear
                    ]),
                    startPoint: CGPoint(x: size.width, y: size.height / 2),
                    endPoint: CGPoint(x: size.width - beamLength, y: size.height / 2)
                )
            )
        }
        .frame(width: 160, height: 80)
        .allowsHitTesting(false)
    }
}

struct PropellerBubblesView: View {
    let time: Double

    var body: some View {
        Canvas { context, size in
            for i in 0..<6 {
                let seed = Double(i) * 17.5
                let t = (time * 1.8 + seed).truncatingRemainder(dividingBy: 1.0)
                let x = CGFloat(t) * 45.0
                let y = sin(t * 8.0) * 6.0
                let alpha = (1.0 - t) * 0.5
                let r = 2.0 + CGFloat(i % 2) * 1.5

                context.opacity = alpha
                context.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(Color(red: 0.6, green: 0.9, blue: 1.0))
                )
            }
        }
        .frame(width: 60, height: 20)
    }
}

struct MarineParticlesLayer: View {
    let time: Double
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            for i in 0..<14 {
                let seed = Double(i) * 27.1
                let speedY = 8.0 + (Double(i % 4) * 3.5)
                let xBase = (sin(seed * 1.3) * 0.5 + 0.5) * size.width
                let yOffset = fmod(time * speedY + seed * 15.0, size.height + 40.0)
                let currentY = size.height - yOffset + 20.0

                let swayX = sin(time * 0.7 + seed) * 8.0
                let particleSize = 1.6 + Double(i % 3) * 0.8
                let alpha = (sin(time * 1.2 + seed) * 0.3 + 0.5) * 0.38

                let rect = CGRect(x: xBase + swayX, y: currentY, width: particleSize, height: particleSize)
                context.opacity = alpha
                context.fill(Path(ellipseIn: rect), with: .color(i % 2 == 0 ? BathysPalette.sky : Color.white))
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

// MARK: - Reef & Fish Layers (Zero Per-Frame Offscreen Blur Filters)

struct DistantReefLayer: View {
    let time: Double
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack {
            Spacer()

            HStack(alignment: .bottom, spacing: 25) {
                BathysAsset.image(named: "algae_ribbon_center")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 70)
                    .colorMultiply(Color(red: 0.05, green: 0.15, blue: 0.25))
                    .opacity(0.32)
                    .rotationEffect(.degrees(sin(time * 0.9) * 2.0), anchor: .bottom)

                Spacer()

                BathysAsset.image(named: "algae_green_tall")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 34, height: 80)
                    .colorMultiply(Color(red: 0.05, green: 0.15, blue: 0.25))
                    .opacity(0.28)
                    .rotationEffect(.degrees(cos(time * 0.8) * 1.8), anchor: .bottom)

                Spacer()

                BathysAsset.image(named: "coral_orange_branch")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .colorMultiply(Color(red: 0.04, green: 0.12, blue: 0.22))
                    .opacity(0.26)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

struct SeafloorReefLayer: View {
    let time: Double
    let width: CGFloat
    let height: CGFloat
    var debris: AnyView? = nil

    var body: some View {
        VStack {
            Spacer()

            ZStack(alignment: .bottom) {
                // MARK: - LAYER 0: Z-DEEP REEF (Dietro le dune di sabbia, immerso nella nebbia oceanica)
                ZStack(alignment: .bottom) {
                    // Gruppo profondo 1: Centro-Sinistra (Ventaglio viola profondo + alga verde alta)
                    HStack(alignment: .bottom, spacing: 6) {
                        BathysAsset.image(named: "coral_purple_fan")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 46)
                            .colorMultiply(Color(red: 0.35, green: 0.52, blue: 0.78))
                            .opacity(0.82)
                            .offset(y: -4)

                        SwayingPlant(name: "algae_green_tall", width: 44, height: 110, swayAngle: sin(time * 0.95) * 1.8)
                            .colorMultiply(Color(red: 0.22, green: 0.50, blue: 0.68))
                            .opacity(0.76)
                    }
                    .position(x: width * 0.38, y: 38)

                    // Gruppo profondo 2: Centro-Destra (Alga nastro + alga blu ondulata)
                    HStack(alignment: .bottom, spacing: 6) {
                        SwayingPlant(name: "algae_ribbon_center", width: 40, height: 105, swayAngle: cos(time * 0.9) * 2.0)
                            .colorMultiply(Color(red: 0.20, green: 0.46, blue: 0.64))
                            .opacity(0.72)

                        SwayingPlant(name: "algae_blue_wavy", width: 42, height: 112, swayAngle: sin(time * 1.05 + 0.6) * 1.9)
                            .colorMultiply(Color(red: 0.22, green: 0.48, blue: 0.66))
                            .opacity(0.75)
                    }
                    .position(x: width * 0.70, y: 40)
                }
                .frame(width: width, height: 140)
                .zIndex(0)

                // MARK: - LAYER 1: Z-MIDGROUND DUNES (Fondale sabbioso oceanico 3D — Solo sabbia superficiale)
                BathysAsset.image(named: "seafloor_sand_bed")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: 98)
                    .clipped()
                    .zIndex(1)

                // MARK: - LAYER 1.5: Z-SEABED DEBRIS (Infilati organicamente nella sabbia)
                if let debris = debris {
                    debris
                        .zIndex(1.5)
                }

                // MARK: - LAYER 1.8: Z-FOREGROUND SAND CREST (Nasconde parzialmente la base dei rifiuti facendoli apparire infilati nella sabbia)
                BathysAsset.image(named: "seafloor_sand_foreground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: 98)
                    .clipped()
                    .allowsHitTesting(false)
                    .zIndex(1.8)

                // MARK: - LAYER 2: Z-ORGANIC REEF ACCENTS (Senza sovrapposizioni sgraziate con i rifiuti)
                ZStack(alignment: .bottom) {
                    // Unico anemone arancio adagiato nell'avvallamento centrale tra gomma e cassa (x: 0.505)
                    BathysAsset.image(named: "coral_orange_anemone")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 28)
                        .shadow(color: Color(red: 0.35, green: 0.24, blue: 0.12).opacity(0.35), radius: 3, x: 0, y: 2)
                        .position(x: width * 0.505, y: 66)
                }
                .frame(width: width, height: 98)
                .zIndex(2)

                // MARK: - LAYER 3: Z-FOREGROUND HERO REEF (Incorniciatura perimetrale elegante a bordo schermo)
                HStack(alignment: .bottom, spacing: 0) {
                    // Ancora di primo piano SINISTRA (Coral Red Fingers + Kelp, senza toccare il bidone)
                    ZStack(alignment: .bottomLeading) {
                        SwayingPlant(name: "algae_green_tall", width: 44, height: 104, swayAngle: sin(time * 1.25) * 2.2)
                            .offset(x: -8, y: 6)

                        BathysAsset.image(named: "coral_red_fingers")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 52, height: 52)
                            .shadow(color: Color(red: 0.35, green: 0.22, blue: 0.10).opacity(0.35), radius: 5, x: 1, y: 3)
                            .offset(x: 0, y: 8)
                    }

                    Spacer()

                    // Ancora di primo piano DESTRA (Coral Orange Branch + Blue Algae, con respiro dal bordo)
                    ZStack(alignment: .bottomTrailing) {
                        SwayingPlant(name: "algae_blue_wavy", width: 38, height: 94, swayAngle: sin(time * 1.2 + 1.1) * 2.2)
                            .offset(x: -14, y: 6)

                        BathysAsset.image(named: "coral_orange_branch")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 48)
                            .shadow(color: Color(red: 0.35, green: 0.22, blue: 0.10).opacity(0.35), radius: 5, x: -1, y: 3)
                            .offset(x: 0, y: 8)
                    }
                }
                .padding(.leading, 6)
                .padding(.trailing, 18)
                .padding(.bottom, 0)
                .zIndex(3)
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

// MARK: - Sleek Architectural Ocean Viewport Seam (Zero Jagged Ticks)

struct BathysNauticalDivider: View {
    var body: some View {
        HStack(spacing: 0) {
            // 1. Crisp dark inner recess (1pt) separating the ocean water/sand from the bezel
            Rectangle()
                .fill(Color.black.opacity(0.60))
                .frame(width: 1)

            // 2. Continuous Depth-Toned Specular Rib (1.5pt) — mirrors sky, waterline, abyss, and warm sand
            LinearGradient(
                stops: [
                    .init(color: BathysPalette.steel.opacity(0.16), location: 0.0),
                    .init(color: BathysPalette.sky.opacity(0.50), location: 0.17),
                    .init(color: BathysPalette.sky.opacity(0.28), location: 0.30),
                    .init(color: BathysPalette.teal.opacity(0.20), location: 0.65),
                    .init(color: BathysPalette.steel.opacity(0.18), location: 0.84),
                    .init(color: BathysPalette.amber.opacity(0.38), location: 0.91),
                    .init(color: BathysPalette.amber.opacity(0.24), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 1.5)

            // 3. Whisper-subtle outer highlight into the dark workspace (0.5pt)
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 0.5)
        }
        .frame(width: 3)
        .frame(maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

// MARK: - Floating Marine Plastic Layer (In Mid-Water Column)

struct FloatingPlasticSpec: Identifiable {
    let id: Int
    let assetName: String
    let width: CGFloat
    let height: CGFloat
    let xRatio: CGFloat
    let yRatio: CGFloat
    let floatSpeed: Double
    let driftRangeX: CGFloat
    let bobRangeY: CGFloat
    let maxRockDeg: Double
    let thresholdGB: Double
}

struct FloatingPlasticDebrisLayer: View {
    let time: Double
    let width: CGFloat
    let height: CGFloat
    let junkBytes: Int64
    let isCleaning: Bool
    let hasCleaned: Bool

    // Visual catalog of floating plastics drifting in mid-water
    // Progressive thresholds: pochi MB = 1 o 2 pezzetti leggeri; tanti GB = compaiono tutti
    private static let catalog: [FloatingPlasticSpec] = [
        FloatingPlasticSpec(id: 0, assetName: "trash_plastic_bag", width: 44, height: 38, xRatio: 0.28, yRatio: 0.38, floatSpeed: 0.8, driftRangeX: 8.0, bobRangeY: 6.0, maxRockDeg: 9.0, thresholdGB: 0.08), // 80 MB
        FloatingPlasticSpec(id: 1, assetName: "trash_plastic_bottle", width: 36, height: 40, xRatio: 0.72, yRatio: 0.50, floatSpeed: 0.9, driftRangeX: 6.5, bobRangeY: 5.0, maxRockDeg: 7.5, thresholdGB: 0.35), // 350 MB
        FloatingPlasticSpec(id: 2, assetName: "trash_plastic_bag", width: 34, height: 30, xRatio: 0.52, yRatio: 0.32, floatSpeed: 0.75, driftRangeX: 6.0, bobRangeY: 4.5, maxRockDeg: -7.0, thresholdGB: 3.5)   // 3.5 GB
    ]

    @State private var visibleCount: Int = 0
    @State private var suctionProgress: Double = 0.0

    private var eligibleItems: [FloatingPlasticSpec] {
        if hasCleaned || (junkBytes == 0 && !isCleaning) {
            return []
        }
        let gb = Double(junkBytes) / 1_073_741_824.0
        return Self.catalog.filter { gb >= $0.thresholdGB }
    }

    var body: some View {
        let activeItems = Array(eligibleItems.prefix(visibleCount))

        ZStack {
            ForEach(activeItems) { item in
                let idleDriftX = sin(time * item.floatSpeed + Double(item.id) * 1.7) * item.driftRangeX
                let idleBobY = cos(time * (item.floatSpeed * 1.15) + Double(item.id) * 2.1) * item.bobRangeY
                let idleRock = sin(time * (item.floatSpeed * 0.9) + Double(item.id)) * item.maxRockDeg

                let initialX = width * item.xRatio + idleDriftX
                let initialY = height * item.yRatio + idleBobY

                let targetX = width * 0.50
                let surfaceY: CGFloat = 95.0
                let seafloorY = max(surfaceY + 80, height - 145.0)
                let targetY = seafloorY + 38.0

                let p = suctionProgress
                let currX = (1.0 - p) * initialX + p * targetX + sin(p * .pi * 3.0 + Double(item.id)) * 14.0 * (1.0 - p)
                let currY = (1.0 - p) * initialY + p * targetY
                let currScale = max(0.01, 1.0 - p * 0.95)
                let currOpacity = max(0.0, 1.0 - p * 1.15)
                let currRot = idleRock + p * 240.0

                BathysAsset.image(named: item.assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: item.width, height: item.height)
                    .colorMultiply(Color(red: 0.86, green: 0.94, blue: 1.0))
                    .shadow(color: Color(red: 0.02, green: 0.08, blue: 0.16).opacity(0.35 * (1.0 - p)), radius: 4, x: 0, y: 2)
                    .rotationEffect(.degrees(currRot))
                    .scaleEffect(currScale)
                    .opacity(currOpacity)
                    .position(x: currX, y: currY)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.7)), removal: .opacity))
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
        .onAppear {
            syncVisibleCount(target: eligibleItems.count)
        }
        .onChange(of: eligibleItems.count) { _, newCount in
            syncVisibleCount(target: newCount)
        }
        .onChange(of: isCleaning) { _, cleaning in
            if cleaning {
                suctionProgress = 0.0
                withAnimation(.easeInOut(duration: 1.25)) {
                    suctionProgress = 1.0
                }
            } else {
                suctionProgress = 0.0
            }
        }
        .onChange(of: hasCleaned) { _, cleaned in
            if cleaned {
                visibleCount = 0
            }
        }
    }

    private func syncVisibleCount(target: Int) {
        if target <= visibleCount {
            visibleCount = target
            return
        }
        for step in (visibleCount + 1)...target {
            let delay = Double(step - visibleCount) * 0.35
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.72, dampingFraction: 0.75)) {
                    if target >= step {
                        visibleCount = max(visibleCount, step)
                    }
                }
            }
        }
    }
}

// MARK: - Marine Debris & Trash Layer (Proportional to Gigabytes Found, Staggered Reveal)

struct SeafloorDebrisSpec: Identifiable {
    let id: Int
    let assetName: String
    let width: CGFloat
    let height: CGFloat
    let xRatio: CGFloat
    let yBottomOffset: CGFloat
    let rotationDegrees: Double
    let thresholdGB: Double
}

struct SeafloorDebrisLayer: View {
    let time: Double
    let width: CGFloat
    let height: CGFloat
    let junkBytes: Int64
    let isCleaning: Bool
    let hasCleaned: Bool

    // Visual catalog of seabed debris nestled naturally into the warm sand dunes
    // Progressive thresholds: pochi MB = 0; >800 MB = bottiglia; >2 GB = cassa; >5 GB = pneumatico; >9 GB = bidone
    private static let catalog: [SeafloorDebrisSpec] = [
        SeafloorDebrisSpec(id: 0, assetName: "trash_glass_bottle", width: 45, height: 58, xRatio: 0.78, yBottomOffset: 32, rotationDegrees: 24, thresholdGB: 0.80),
        SeafloorDebrisSpec(id: 1, assetName: "trash_wood_crate", width: 58, height: 55, xRatio: 0.62, yBottomOffset: 35, rotationDegrees: 6, thresholdGB: 2.2),
        SeafloorDebrisSpec(id: 2, assetName: "trash_tire", width: 63, height: 58, xRatio: 0.385, yBottomOffset: 33, rotationDegrees: -8, thresholdGB: 5.5),
        SeafloorDebrisSpec(id: 3, assetName: "trash_oil_drum", width: 59, height: 64, xRatio: 0.21, yBottomOffset: 34, rotationDegrees: -14, thresholdGB: 9.0),
        SeafloorDebrisSpec(id: 4, assetName: "trash_tire", width: 52, height: 50, xRatio: 0.88, yBottomOffset: 32, rotationDegrees: 16, thresholdGB: 15.0),
        SeafloorDebrisSpec(id: 5, assetName: "trash_oil_drum", width: 50, height: 56, xRatio: 0.12, yBottomOffset: 33, rotationDegrees: -20, thresholdGB: 22.0)
    ]

    @State private var visibleCount: Int = 0
    @State private var suctionProgress: Double = 0.0

    private var eligibleItems: [SeafloorDebrisSpec] {
        if hasCleaned || (junkBytes == 0 && !isCleaning) {
            return []
        }
        let gb = Double(junkBytes) / 1_073_741_824.0
        return Self.catalog.filter { gb >= $0.thresholdGB }
    }

    var body: some View {
        let activeItems = Array(eligibleItems.prefix(visibleCount))

        ZStack {
            ForEach(activeItems) { item in
                let initialX = width * item.xRatio
                let initialY = height - item.yBottomOffset - item.height * 0.5
                let targetX = width * 0.50
                let surfaceY: CGFloat = 95.0
                let seafloorY = max(surfaceY + 80, height - 145.0)
                let targetY = seafloorY + 38.0

                let p = suctionProgress
                // Gentle vortex interpolation towards submarine vacuum intake
                let currX = (1.0 - p) * initialX + p * targetX + sin(p * .pi * 3.0 + Double(item.id)) * 14.0 * (1.0 - p)
                let currY = (1.0 - p) * initialY + p * targetY
                let currScale = max(0.01, 1.0 - p * 0.94)
                let currOpacity = max(0.0, 1.0 - p * 1.15)
                let idleSway = sin(time * 0.8 + Double(item.id)) * 0.8
                let currRot = item.rotationDegrees + idleSway + p * 220.0

                BathysAsset.image(named: item.assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: item.width, height: item.height)
                    .colorMultiply(Color(red: 0.88, green: 0.94, blue: 0.98))
                    .shadow(color: Color(red: 0.28, green: 0.16, blue: 0.06).opacity(0.42 * (1.0 - p)), radius: 3, x: 0, y: 2)
                    .rotationEffect(.degrees(currRot))
                    .scaleEffect(currScale)
                    .opacity(currOpacity)
                    .position(x: currX, y: currY)
                    .zIndex(p > 0.02 ? 5.0 : 1.5)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 12)), removal: .opacity))
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
        .onAppear {
            syncVisibleCount(target: eligibleItems.count)
        }
        .onChange(of: eligibleItems.count) { _, newCount in
            syncVisibleCount(target: newCount)
        }
        .onChange(of: isCleaning) { _, cleaning in
            if cleaning {
                suctionProgress = 0.0
                withAnimation(.easeInOut(duration: 1.25)) {
                    suctionProgress = 1.0
                }
            } else {
                suctionProgress = 0.0
            }
        }
        .onChange(of: hasCleaned) { _, cleaned in
            if cleaned {
                visibleCount = 0
            }
        }
    }

    private func syncVisibleCount(target: Int) {
        if target <= visibleCount {
            visibleCount = target
            return
        }
        for step in (visibleCount + 1)...target {
            let delay = Double(step - visibleCount) * 0.35
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.72, dampingFraction: 0.75)) {
                    if target >= step {
                        visibleCount = max(visibleCount, step)
                    }
                }
            }
        }
    }
}

struct SwayingPlant: View {
    let name: String
    let width: CGFloat
    let height: CGFloat
    let swayAngle: Double

    var body: some View {
        BathysAsset.image(named: name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
            .rotationEffect(.degrees(swayAngle), anchor: .bottom)
            .shadow(color: Color.black.opacity(0.35), radius: 4, y: 3)
    }
}

struct BackgroundFishLayer: View {
    let time: Double
    let containerSize: CGSize

    var body: some View {
        let w = max(100.0, containerSize.width)
        let h = max(100.0, containerSize.height)

        ZStack {
            SwimmingFishInstance(
                time: time,
                assetName: "fish_blue_2",
                width: 20, height: 13,
                swimSpeed: 15.0, swimOffset: 50.0,
                swimY: h * 0.32 + sin(time * 1.5) * 3.0,
                containerWidth: w, swimRight: true,
                opacity: 0.45, blur: 0.8
            )

            SwimmingFishInstance(
                time: time,
                assetName: "fish_blue_1",
                width: 22, height: 14,
                swimSpeed: 17.0, swimOffset: 160.0,
                swimY: h * 0.48 + cos(time * 1.4) * 3.5,
                containerWidth: w, swimRight: false,
                opacity: 0.40, blur: 0.9
            )
        }
    }
}

struct MidgroundFishLayer: View {
    let time: Double
    let containerSize: CGSize

    var body: some View {
        let w = max(100.0, containerSize.width)
        let h = max(100.0, containerSize.height)

        ZStack {
            SwimmingFishInstance(
                time: time,
                assetName: "fish_orange_1",
                width: 34, height: 24,
                swimSpeed: 26.0, swimOffset: 110.0,
                swimY: h * 0.58 + sin(time * 1.8) * 4.5,
                containerWidth: w, swimRight: true,
                opacity: 1.0, blur: 0.0
            )

            SwimmingFishInstance(
                time: time,
                assetName: "fish_orange_2",
                width: 32, height: 20,
                swimSpeed: 22.0, swimOffset: 220.0,
                swimY: h * 0.70 + cos(time * 1.9) * 4.0,
                containerWidth: w, swimRight: false,
                opacity: 1.0, blur: 0.0
            )

            SwimmingFishInstance(
                time: time,
                assetName: "fish_blue_2",
                width: 30, height: 21,
                swimSpeed: 24.0, swimOffset: 150.0,
                swimY: h * 0.78 + sin(time * 1.7) * 3.5,
                containerWidth: w, swimRight: true,
                opacity: 1.0, blur: 0.0
            )
        }
    }
}

struct ForegroundFishLayer: View {
    let time: Double
    let containerSize: CGSize

    var body: some View {
        let w = max(100.0, containerSize.width)
        let h = max(100.0, containerSize.height)

        ZStack {
            SwimmingFishInstance(
                time: time,
                assetName: "fish_blue_1",
                width: 34, height: 24,
                swimSpeed: 20.0, swimOffset: 70.0,
                swimY: h * 0.85 + sin(time * 2.1) * 3.0,
                containerWidth: w, swimRight: false,
                opacity: 0.92, blur: 0.0
            )
        }
    }
}

struct SwimmingFishInstance: View {
    let time: Double
    let assetName: String
    let width: CGFloat
    let height: CGFloat
    let swimSpeed: Double
    let swimOffset: Double
    let swimY: CGFloat
    let containerWidth: Double
    let swimRight: Bool
    let opacity: Double
    let blur: CGFloat

    var body: some View {
        let totalSpan = containerWidth + 80.0
        let progress = (time * swimSpeed + swimOffset).truncatingRemainder(dividingBy: totalSpan)
        let posX: CGFloat = swimRight ? CGFloat(-40.0 + progress) : CGFloat(containerWidth + 40.0 - progress)
        let tailWag = sin(time * 5.5 + swimOffset) * 2.5

        BathysAsset.image(named: assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
            .scaleEffect(x: swimRight ? 1 : -1, y: 1)
            .rotationEffect(.degrees(swimRight ? tailWag : -tailWag))
            .opacity(opacity)
            .blur(radius: blur)
            .position(x: posX, y: swimY)
            .shadow(color: Color.black.opacity(opacity * 0.35), radius: 4, y: 3)
    }
}

// MARK: - Permission Manager (Full Disk Access Detection & macOS Security)

@MainActor @Observable
final class PermissionManager {
    var hasFullDiskAccess: Bool = false
    var hasSeenPrivacyOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenPrivacyOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenPrivacyOnboarding") }
    }

    init() {
        checkPermissions()
    }

    func checkPermissions() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default
        let canaries = [
            home.appendingPathComponent("Library/Safari"),
            home.appendingPathComponent("Library/Mail"),
            home.appendingPathComponent("Library/Cookies"),
            home.appendingPathComponent("Library/Messages"),
            home.appendingPathComponent("Library/Suggestions")
        ]
        var granted = false
        for canary in canaries {
            if (try? fm.contentsOfDirectory(at: canary, includingPropertiesForKeys: nil)) != nil {
                granted = true
                break
            }
        }
        hasFullDiskAccess = granted
    }

    func openSystemSettingsFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let appUrl = Bundle.main.bundleURL
            NSWorkspace.shared.activateFileViewerSelecting([appUrl])
        }
    }
}

// MARK: - Sheet Window Customizer (Eliminates AppKit Gray Window Chrome)

struct SheetWindowCustomizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.backgroundColor = NSColor(red: 0.028, green: 0.052, blue: 0.092, alpha: 1.0)
                window.isOpaque = true
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.contentView?.wantsLayer = true
                window.contentView?.layer?.backgroundColor = NSColor(red: 0.028, green: 0.052, blue: 0.092, alpha: 1.0).cgColor
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            window.backgroundColor = NSColor(red: 0.028, green: 0.052, blue: 0.092, alpha: 1.0)
            window.contentView?.layer?.backgroundColor = NSColor(red: 0.028, green: 0.052, blue: 0.092, alpha: 1.0).cgColor
        }
    }
}

// MARK: - High-Craft Privacy & Permission Onboarding Sheet

struct PrivacyOnboardingSheet: View {
    @Bindable var permissionManager: PermissionManager
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            BathysPalette.workspaceBottom
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                // Header
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BathysPalette.emerald.opacity(0.16))
                            .frame(width: 44, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(BathysPalette.emerald.opacity(0.3), lineWidth: 1)
                            )

                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(BathysPalette.emerald)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trasparenza, Privacy & Sicurezza")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Come Bathys tutela rigorosamente i tuoi dati e il tuo Mac.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(BathysPalette.textSecondary)
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.08))

                // 4 Safety Pillars
                VStack(alignment: .leading, spacing: 14) {
                    PrivacyPillarRow(
                        icon: "network.slash",
                        tint: BathysPalette.sky,
                        title: "Zero Connessioni & Zero Archiviazione Esterna",
                        description: "Bathys opera 100% offline sul tuo processore. Nessun dato, nome di file o statistica viene mai inviato a server esterni né tracciato."
                    )

                    PrivacyPillarRow(
                        icon: "lock.fill",
                        tint: BathysPalette.emerald,
                        title: "Dati Personali Intoccabili",
                        description: "Documenti, Foto, Scrivania, Messaggi, Mail e Portachiavi (Keychains) non vengono mai letti né aperti. Vengono analizzati esclusivamente file temporanei e cache usa-e-getta."
                    )

                    PrivacyPillarRow(
                        icon: "hand.raised.fill",
                        tint: BathysPalette.amber,
                        title: "Nessuna Cancellazione Autonoma",
                        description: "Le scansioni operano in sola lettura. Nessun elemento viene spostato nel Cestino senza la tua esplicita conferma."
                    )

                    // Full Disk Access Row
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(BathysPalette.teal.opacity(0.14))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "internaldrive.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(BathysPalette.teal)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Accesso Completo al Disco (Full Disk Access)")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(.white)

                                Text("Necessario per calcolare le cache applicative in ~/Library e /var/folders.")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(BathysPalette.textTertiary)
                            }

                            Spacer()

                            if permissionManager.hasFullDiskAccess {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 11))
                                    Text("Concesso")
                                        .font(.system(size: 11.5, weight: .medium))
                                }
                                .foregroundStyle(BathysPalette.emerald)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(BathysPalette.emerald.opacity(0.12)))
                            } else {
                                Button {
                                    permissionManager.openSystemSettingsFullDiskAccess()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gearshape")
                                            .font(.system(size: 11))
                                        Text("Apri Impostazioni")
                                            .font(.system(size: 11.5, weight: .medium))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(BathysPalette.surfaceFillHover))
                                    .overlay(Capsule().strokeBorder(BathysPalette.hairline, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !permissionManager.hasFullDiskAccess {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(BathysPalette.amber)
                                Text("Basta una volta sola: premi \"Apri Impostazioni\" e attiva la levetta per Bathys. Da quel momento analizzerà tutto il Mac senza mai più chiederti permessi individuali.")
                                    .font(.system(size: 11.5, weight: .regular))
                                    .foregroundStyle(BathysPalette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(BathysPalette.surfaceFill)
                    )
                }

                // Bottom Buttons
                HStack {
                    Button {
                        permissionManager.checkPermissions()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                            Text("Ricontrolla Permesso")
                                .font(.system(size: 12.5, weight: .regular))
                        }
                        .foregroundStyle(BathysPalette.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        permissionManager.hasSeenPrivacyOnboarding = true
                        onDismiss()
                    } label: {
                        Text("Ho Compreso e Accetto")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(BathysPalette.teal))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .frame(width: 580)
        .background(BathysPalette.workspaceBottom)
        .background(SheetWindowCustomizer())
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

struct PrivacyPillarRow: View {
    let icon: String
    let tint: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(BathysPalette.textTertiary)
                    .lineSpacing(2)
            }
        }
    }
}
