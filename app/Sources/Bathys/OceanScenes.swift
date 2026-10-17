import SwiftUI
import AppKit

enum BathysMode: String, CaseIterable, Identifiable {
    case deepClean = "Scansione Profonda"
    case sonar = "Sonar Spazio"
    case uninstaller = "Disinstalla App"
    case optimizer = "Prestazioni"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deepClean: return L10n.deepScanTitle
        case .sonar: return L10n.sonarTitle
        case .uninstaller: return L10n.uninstallerTitle
        case .optimizer: return L10n.optimizerTitle
        }
    }

    var shortDescription: String {
        switch self {
        case .deepClean: return L10n.deepScanDesc
        case .sonar: return L10n.sonarDesc
        case .uninstaller: return L10n.uninstallerDesc
        case .optimizer: return L10n.optimizerDesc
        }
    }
}

// MARK: - Master Left Pane Switcher (Pure Atmospheric Illustration — Zero HUD Clutter)

struct LeftThemedOceanPane: View {
    let mode: BathysMode?
    let scanner: Scanner
    let sonar: SonarEngine
    let uninstaller: UninstallerEngine
    let optimizer: OptimizerEngine

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            let isHighActivity = scanner.isScanning || scanner.isCleaning || scanner.isResurfacing || sonar.isScanning || uninstaller.isLoadingApps || optimizer.isRunningTasks
            TimelineView(.animation(minimumInterval: isHighActivity ? (1.0 / 60.0) : (1.0 / 30.0))) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    // 1. Sfondo Abissale Marino Naturale (Zero Viola/Rosa)
                    LinearGradient(
                        stops: [
                            .init(color: BathysPalette.abyssSky, location: 0.0),
                            .init(color: BathysPalette.abyssSurface, location: 0.22),
                            .init(color: Color(red: 0.030, green: 0.068, blue: 0.125), location: 0.58),
                            .init(color: BathysPalette.abyssDark, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // 2. Particelle marine leggere
                    MarineParticlesLayer(time: time, width: w, height: h)

                    // 3. Scena Tematica Specifica per Modalità (Senza Testi o Box Sovrapposti)
                    switch mode {
                    case .none, .some(.deepClean):
                        VolumetricSunRaysView(time: time, width: w, height: h)
                        WaterCausticsLayer(time: time, width: w, height: h)
                        AnimatedWaterSurfaceWave(time: time, width: w, height: h)
                        DistantReefLayer(time: time, width: w, height: h)
                        BackgroundFishLayer(time: time, containerSize: proxy.size)
                        if mode == nil || mode == .deepClean {
                            FloatingPlasticDebrisLayer(
                                time: time,
                                width: w,
                                height: h,
                                junkBytes: scanner.totalBytes,
                                isCleaning: scanner.isCleaning,
                                hasCleaned: scanner.hasCleaned
                            )
                        }
                        SeafloorReefLayer(
                            time: time,
                            width: w,
                            height: h,
                            debris: (mode == nil || mode == .deepClean) ? AnyView(
                                SeafloorDebrisLayer(
                                    time: time,
                                    width: w,
                                    height: h,
                                    junkBytes: scanner.totalBytes,
                                    isCleaning: scanner.isCleaning,
                                    hasCleaned: scanner.hasCleaned
                                )
                            ) : nil
                        )
                        MidgroundFishLayer(time: time, containerSize: proxy.size)
                        DynamicDivingSubmarine(
                            time: time,
                            containerSize: proxy.size,
                            isScanning: mode == .deepClean ? scanner.isScanning : false,
                            hasScanned: mode == .deepClean ? scanner.hasScanned : false,
                            isCleaning: mode == .deepClean ? scanner.isCleaning : false,
                            isResurfacing: mode == .deepClean ? scanner.isResurfacing : false,
                            scanStartedAt: mode == .deepClean ? scanner.startedAt : nil,
                            resurfaceStartedAt: mode == .deepClean ? scanner.resurfaceStartedAt : nil,
                            depth: mode == .deepClean ? scanner.depth : 0.0
                        )
                        ForegroundFishLayer(time: time, containerSize: proxy.size)

                    case .some(.sonar):
                        SonarRadarScene(
                            time: time,
                            width: w,
                            height: h,
                            sonar: sonar
                        )

                    case .some(.uninstaller):
                        VolumetricSunRaysView(time: time, width: w, height: h)
                        DistantReefLayer(time: time, width: w, height: h)
                        SeafloorReefLayer(time: time, width: w, height: h)
                        DecompressionUninstallerScene(
                            time: time,
                            width: w,
                            height: h,
                            uninstaller: uninstaller
                        )

                    case .some(.optimizer):
                        VolumetricSunRaysView(time: time, width: w, height: h)
                        DistantReefLayer(time: time, width: w, height: h)
                        BackgroundFishLayer(time: time, containerSize: proxy.size)
                        SeafloorReefLayer(time: time, width: w, height: h)
                        PropulsionTelemetryScene(
                            time: time,
                            width: w,
                            height: h,
                            optimizer: optimizer
                        )
                    }
                }
            }
        }
    }
}

// MARK: - SCENE 2: SONAR (Command Bridge Tactical Sonar Console)

// MARK: - SCENE 2: SONAR (Command Deck Nautical Console Housing)

struct ConsoleCornerScrews: View {
    let size: CGFloat
    let inset: CGFloat = 14.0
    let screwDiameter: CGFloat = 8.0

    var body: some View {
        Canvas { context, _ in
            let corners: [(CGPoint, Double)] = [
                (CGPoint(x: inset, y: inset), 35.0),
                (CGPoint(x: size - inset, y: inset), 115.0),
                (CGPoint(x: inset, y: size - inset), -40.0),
                (CGPoint(x: size - inset, y: size - inset), 70.0)
            ]

            for (pos, angleDeg) in corners {
                let r = screwDiameter / 2.0
                let rect = CGRect(x: pos.x - r, y: pos.y - r, width: screwDiameter, height: screwDiameter)

                // 1. Recessed bezel shadow
                context.stroke(
                    Path(ellipseIn: rect.insetBy(dx: -1.0, dy: -1.0)),
                    with: .color(Color.black.opacity(0.80)),
                    lineWidth: 1.0
                )

                // 2. Machined titanium screw head
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color(red: 0.18, green: 0.24, blue: 0.32))
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(0.28)),
                    lineWidth: 0.7
                )

                // 3. Realistic screw slot
                let rad = angleDeg * Double.pi / 180.0
                let slotLen = r * 0.72
                let dx = cos(rad) * slotLen
                let dy = sin(rad) * slotLen

                // Shadow line
                var shadowSlot = Path()
                shadowSlot.move(to: CGPoint(x: pos.x - dx, y: pos.y - dy + 0.6))
                shadowSlot.addLine(to: CGPoint(x: pos.x + dx, y: pos.y + dy + 0.6))
                context.stroke(shadowSlot, with: .color(Color.black.opacity(0.90)), lineWidth: 1.0)

                // Highlight line
                var highlightSlot = Path()
                highlightSlot.move(to: CGPoint(x: pos.x - dx, y: pos.y - dy))
                highlightSlot.addLine(to: CGPoint(x: pos.x + dx, y: pos.y + dy))
                context.stroke(highlightSlot, with: .color(Color(red: 0.08, green: 0.12, blue: 0.18)), lineWidth: 0.9)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

struct NauticalConsolePanel<Content: View>: View {
    let size: CGFloat
    let content: () -> Content

    init(size: CGFloat = 292, @ViewBuilder content: @escaping () -> Content) {
        self.size = size
        self.content = content
    }

    var body: some View {
        ZStack {
            // Dark machined marine console panel
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.09, blue: 0.15).opacity(0.96),
                            Color(red: 0.02, green: 0.05, blue: 0.10).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.14),
                                    Color.white.opacity(0.04),
                                    BathysPalette.sky.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.55), radius: 18, y: 8)

            // 4 Corner Screws
            ConsoleCornerScrews(size: size)

            // The Radar or Sunburst Instrument inside
            content()
        }
        .frame(width: size, height: size)
    }
}

struct AzimuthCompassRing: View {
    let diameter: CGFloat

    var body: some View {
        let radius = diameter / 2
        let innerR = radius - 10

        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerR = radius - 1

            // Outer and inner hairline circles
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - outerR, y: center.y - outerR, width: outerR * 2, height: outerR * 2)),
                with: .color(Color.white.opacity(0.12)),
                lineWidth: 1
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)),
                with: .color(Color.white.opacity(0.08)),
                lineWidth: 0.8
            )

            // Azimuth tick marks every 10 degrees (clean, zero text labels)
            for deg in stride(from: 0, to: 360, by: 10) {
                let rad = Double(deg) * Double.pi / 180.0
                let isMajor = deg % 30 == 0
                let isCardinal = deg % 90 == 0
                let tickLen: CGFloat = isCardinal ? 8 : (isMajor ? 5.5 : 3.0)

                let x0 = center.x + cos(rad) * innerR
                let y0 = center.y + sin(rad) * innerR
                let x1 = center.x + cos(rad) * (innerR + tickLen)
                let y1 = center.y + sin(rad) * (innerR + tickLen)

                var tick = Path()
                tick.move(to: CGPoint(x: x0, y: y0))
                tick.addLine(to: CGPoint(x: x1, y: y1))

                context.stroke(
                    tick,
                    with: .color(isCardinal ? BathysPalette.sky.opacity(0.70) : (isMajor ? Color.white.opacity(0.35) : Color.white.opacity(0.15))),
                    lineWidth: isCardinal ? 1.2 : (isMajor ? 0.9 : 0.6)
                )
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
    }
}


struct SonarRadarInstrument: View {
    let time: Double
    let sonar: SonarEngine
    let diameter: CGFloat

    var body: some View {
        let radius = diameter / 2
        let sweepSpeed = sonar.isScanning ? 2.0 : 0.85
        let sweepAngle = fmod(time * sweepSpeed, Double.pi * 2.0)

        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // 1. CRT Sonar screen backdrop
                let screenCircle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                context.fill(screenCircle, with: .color(Color(red: 0.02, green: 0.06, blue: 0.12).opacity(0.88)))

                // 2. Range concentric distance rings
                for i in 1...4 {
                    let r = radius * (CGFloat(i) / 4.0)
                    let ringRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                    context.opacity = i == 4 ? 0.35 : 0.14
                    context.stroke(
                        Path(ellipseIn: ringRect),
                        with: .color(BathysPalette.sky),
                        lineWidth: i == 4 ? 1.2 : 0.8
                    )
                }

                // 3. Precision Cardinal Crosshairs with graduation ticks
                context.opacity = 0.22
                var axes = Path()
                axes.move(to: CGPoint(x: center.x - radius, y: center.y))
                axes.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                axes.move(to: CGPoint(x: center.x, y: center.y - radius))
                axes.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                context.stroke(axes, with: .color(BathysPalette.sky), lineWidth: 0.8)

                // Graduation ticks along the axes
                for step in stride(from: -Int(radius) + 20, through: Int(radius) - 20, by: 20) {
                    if step == 0 { continue }
                    var xTick = Path()
                    xTick.move(to: CGPoint(x: center.x + CGFloat(step), y: center.y - 2.5))
                    xTick.addLine(to: CGPoint(x: center.x + CGFloat(step), y: center.y + 2.5))
                    context.stroke(xTick, with: .color(BathysPalette.sky), lineWidth: 0.6)

                    var yTick = Path()
                    yTick.move(to: CGPoint(x: center.x - 2.5, y: center.y + CGFloat(step)))
                    yTick.addLine(to: CGPoint(x: center.x + 2.5, y: center.y + CGFloat(step)))
                    context.stroke(yTick, with: .color(BathysPalette.sky), lineWidth: 0.6)
                }

                // 4. Acoustic ping expansion wave
                let pingPhase = fmod(time * (sonar.isScanning ? 0.75 : 0.35), 1.0)
                let pingR = radius * CGFloat(pingPhase)
                context.opacity = (1.0 - pingPhase) * 0.35
                context.stroke(
                    Path(ellipseIn: CGRect(x: center.x - pingR, y: center.y - pingR, width: pingR * 2, height: pingR * 2)),
                    with: .color(BathysPalette.sky),
                    lineWidth: 1.4
                )

                // 5. Phosphor persistence cone (24 wedges)
                let trailSteps = 24
                let totalTrailAngle = 0.80
                for step in 0..<trailSteps {
                    let frac = Double(step) / Double(trailSteps)
                    let a0 = sweepAngle - frac * totalTrailAngle
                    let a1 = sweepAngle - (Double(step + 1) / Double(trailSteps)) * totalTrailAngle
                    var wedge = Path()
                    wedge.move(to: center)
                    wedge.addArc(center: center, radius: radius - 1, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: true)
                    wedge.closeSubpath()
                    context.opacity = (1.0 - frac) * 0.035
                    context.fill(wedge, with: .color(BathysPalette.sky))
                }

                // 6. Active front sweep beam
                var sweepLine = Path()
                sweepLine.move(to: center)
                sweepLine.addLine(to: CGPoint(
                    x: center.x + cos(sweepAngle) * radius,
                    y: center.y + sin(sweepAngle) * radius
                ))
                context.opacity = 0.75
                context.stroke(sweepLine, with: .color(BathysPalette.sky), lineWidth: 1.5)

                // 7. Live storage cluster blips
                for (index, blip) in sonar.liveRadarBlips.prefix(12).enumerated() {
                    let bx = center.x + cos(blip.angle) * (radius * CGFloat(blip.distance))
                    let by = center.y + sin(blip.angle) * (radius * CGFloat(blip.distance))

                    var angleDiff = fmod(sweepAngle - blip.angle, Double.pi * 2.0)
                    if angleDiff < 0 { angleDiff += Double.pi * 2.0 }
                    let glow = max(0.30, 1.0 - (angleDiff / (Double.pi * 2.0)) * 0.75)

                    let blipColor = BathysPalette.chartColor(for: index)
                    let dotRadius: CGFloat = index < 3 ? 5.0 : 3.5

                    context.opacity = glow * 0.35
                    context.fill(
                        Path(ellipseIn: CGRect(x: bx - dotRadius * 2.2, y: by - dotRadius * 2.2, width: dotRadius * 4.4, height: dotRadius * 4.4)),
                        with: .color(blipColor)
                    )

                    context.opacity = glow * 0.95
                    context.fill(
                        Path(ellipseIn: CGRect(x: bx - dotRadius, y: by - dotRadius, width: dotRadius * 2, height: dotRadius * 2)),
                        with: .color(blipColor)
                    )
                }
            }
            .frame(width: diameter, height: diameter)
            .allowsHitTesting(false)

            // Center targeting reticle + Bathyscaphe Submarine
            Circle()
                .strokeBorder(BathysPalette.sky.opacity(0.40), lineWidth: 1)
                .frame(width: 44, height: 44)

            BathysAsset.image(named: "submarine_yellow")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 54, height: 42)
                .shadow(color: Color.black.opacity(0.60), radius: 6, y: 3)
        }
        .frame(width: diameter, height: diameter)
    }
}

struct SonarRadarScene: View {
    let time: Double
    let width: CGFloat
    let height: CGFloat
    let sonar: SonarEngine

    var body: some View {
        ZStack {
            NauticalConsolePanel(size: 292) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.02, green: 0.05, blue: 0.10).opacity(0.98))
                        .frame(width: 252, height: 252)
                    AzimuthCompassRing(diameter: 252)
                    SonarRadarInstrument(time: time, sonar: sonar, diameter: 248)
                }
            }
            .position(x: width / 2, y: 65.0 + height / 2.0)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - SCENE 3: DISINSTALLA APP (Clean Underwater Bubble — Zero Orbiting Text Pills)

struct DecompressionUninstallerScene: View {
    let time: Double
    let width: CGFloat
    let height: CGFloat
    let uninstaller: UninstallerEngine

    var body: some View {
        let subX = width * 0.36
        let subY: CGFloat = height * 0.28 + sin(time * 1.3) * 3.5
        let bubbleX = width * 0.56
        let bubbleY = height * 0.58 + cos(time * 1.1) * 4.0

        ZStack {
            // 1. Fascio di luce morbido dal sottomarino alla sfera
            Canvas { context, size in
                var beam = Path()
                let startPt = CGPoint(x: subX + 38, y: subY + 18)
                beam.move(to: startPt)
                beam.addLine(to: CGPoint(x: bubbleX - 58, y: bubbleY - 26))
                beam.addLine(to: CGPoint(x: bubbleX + 58, y: bubbleY + 26))
                beam.closeSubpath()

                context.opacity = 0.20
                context.fill(
                    beam,
                    with: .linearGradient(
                        Gradient(colors: [
                            BathysPalette.sky.opacity(0.70),
                            BathysPalette.teal.opacity(0.22),
                            Color.clear
                        ]),
                        startPoint: startPt,
                        endPoint: CGPoint(x: bubbleX, y: bubbleY)
                    )
                )

                // Micro-bolle organiche ascendenti attorno alla capsula
                for i in 0..<8 {
                    let seed = Double(i) * 1.37
                    let progress = fmod(time * 0.45 + seed, 1.0)
                    let riseY = (1.0 - progress) * 120.0 - 60.0
                    let swayX = sin(time * 1.8 + seed * 2.5) * 16.0
                    let baseAngle = seed * 2.0
                    let bx = bubbleX + cos(baseAngle) * 64.0 + swayX
                    let by = bubbleY + riseY

                    let bSize = 3.5 + CGFloat(i % 3) * 2.0
                    let bRect = CGRect(x: bx - bSize / 2, y: by - bSize / 2, width: bSize, height: bSize)
                    let bAlpha = (1.0 - abs(progress - 0.5) * 2.0) * 0.45

                    context.opacity = bAlpha
                    context.fill(Path(ellipseIn: bRect), with: .color(BathysPalette.teal.opacity(0.75)))
                    context.opacity = bAlpha * 0.8
                    context.stroke(Path(ellipseIn: bRect), with: .color(.white), lineWidth: 0.8)
                }
            }
            .allowsHitTesting(false)

            // 2. Sottomarino Ispettore
            BathysAsset.image(named: "submarine_yellow")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 145, height: 116)
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(10 + sin(time * 1.2) * 1.2))
                .position(x: subX, y: subY)
                .shadow(color: Color.black.opacity(0.38), radius: 10, y: 6)

            // 3. Capsula di Decompressione & Ispezione ad Alta Fedeltà (High-Craft Bathysphere)
            ZStack {
                // Glow d'ambiente cromatico
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                BathysPalette.teal.opacity(0.24),
                                BathysPalette.sky.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 35,
                            endRadius: 85
                        )
                    )
                    .frame(width: 170, height: 170)

                // Anello esterno sonico pulsante
                Circle()
                    .strokeBorder(
                        BathysPalette.teal.opacity(0.20 + sin(time * 2.0) * 0.08),
                        lineWidth: 1.0
                    )
                    .frame(width: 132, height: 132)

                // Sfera di cristallo pressurizzata
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.12, green: 0.22, blue: 0.35).opacity(0.75),
                                Color(red: 0.04, green: 0.08, blue: 0.16).opacity(0.88),
                                Color.black.opacity(0.55)
                            ],
                            center: .topLeading,
                            startRadius: 8,
                            endRadius: 65
                        )
                    )
                    .frame(width: 118, height: 118)
                    .overlay(
                        // Riflesso speculare superiore a lunetta
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.65),
                                        BathysPalette.teal.opacity(0.40),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .overlay(
                        // Lunetta di luce interna superiore
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.22), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 70, height: 26)
                            .offset(y: -42)
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 20, y: 10)

                // Icona App Sospesa nel Fluido Iperbarico
                if let app = uninstaller.selectedApp {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.black.opacity(0.50), radius: 10, y: 6)
                        .offset(y: sin(time * 1.5) * 2.0)
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
            .position(x: bubbleX, y: bubbleY)
        }
    }
}

// MARK: - SCENE 4: PRESTAZIONI (Dynamic Acceleration & High-Velocity Propeller Vortex)

struct PropulsionTelemetryScene: View {
    let time: Double
    let width: CGFloat
    let height: CGFloat
    let optimizer: OptimizerEngine
    @State private var accelerationFactor: Double = 0.0

    var body: some View {
        let isOptimizing = optimizer.isRunningTasks
        let progress = accelerationFactor
        let centerX = width * 0.50
        let subY = height * 0.45 + sin(time * 1.6) * (3.5 - progress * 1.5)
        let currentSpeed = 0.8 + progress * 3.6
        let pitchAngle = -0.6 - progress * 3.2
        let throttleVibration = progress > 0.05 ? sin(time * 36.0) * (progress * 0.65) : 0.0

        ZStack {
            // Linee di corrente idrodinamica: attive SOLO durante l'accelerazione dell'ottimizzazione
            if progress > 0.04 {
                Canvas { context, size in
                    let speed = 2.0 + currentSpeed * 2.5
                    for i in 0..<7 {
                        let baseY = height * 0.22 + CGFloat(i) * 38.0
                        var stream = Path()
                        stream.move(to: CGPoint(x: 16, y: baseY))
                        for x in stride(from: 16, through: size.width - 16, by: 10) {
                            let offset = sin(x * 0.024 - time * speed + Double(i) * 1.5) * (3.0 + CGFloat(progress) * 3.5)
                            stream.addLine(to: CGPoint(x: x, y: baseY + offset))
                        }
                        context.opacity = progress * 0.24
                        context.stroke(stream, with: .color(BathysPalette.sky), lineWidth: 1.0 + CGFloat(progress) * 0.5)
                    }
                }
                .allowsHitTesting(false)
            }

            // Sottomarino: andatura normale a riposo (prima e dopo), veloce durante l'ottimizzazione attiva
            ZStack {
                // Faro volumetrico anteriore
                VolumetricHeadlightCone(isScanning: isOptimizing)
                    .position(x: 175 * 0.5 - 90, y: 140 * 0.5 + 16)
                    .opacity(0.55 + progress * 0.35)

                // Scia di bolle (normale a riposo, vortice potente durante l'ottimizzazione)
                HighVelocityBubbleVortexView(time: time, speedFactor: currentSpeed, isTurbo: isOptimizing)
                    .position(x: 175 * 0.5 + 77.0 + 160.0, y: 140 * 0.5 + 24.5)

                // Fusoliera sottomarino
                BathysAsset.image(named: "submarine_hull")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 175, height: 140)
                    .shadow(color: Color.black.opacity(0.38), radius: 12, y: 8)

                // Elica posteriore (rotazione normale a riposo, altissima velocità solo durante l'ottimizzazione)
                HighSpeedPropellerView(time: time, speedFactor: currentSpeed, isTurbo: isOptimizing)
                    .position(x: 175 * 0.5 + 77.0, y: 140 * 0.5 + 24.5)
            }
            .frame(width: 175, height: 140)
            .rotationEffect(.degrees(pitchAngle))
            .offset(y: throttleVibration)
            .position(x: centerX, y: subY)
        }
        .onAppear {
            accelerationFactor = isOptimizing ? 1.0 : 0.0
        }
        .onChange(of: isOptimizing) { running in
            withAnimation(running ? .easeInOut(duration: 0.8) : .easeOut(duration: 1.2)) {
                accelerationFactor = running ? 1.0 : 0.0
            }
        }
    }
}

// MARK: - Elica Posteriore 3D (Velocità normale a riposo, turbo durante ottimizzazione)

struct HighSpeedPropellerView: View {
    let time: Double
    let speedFactor: Double
    let isTurbo: Bool

    var body: some View {
        let spinSpeed = isTurbo ? (22.0 + speedFactor * 18.0) : 6.0
        let spinAngle = time * spinSpeed
        let bladeRadius: CGFloat = 16.5
        let hubRadius: CGFloat = 4.2
        let blurOpacity: Double = isTurbo ? 0.65 : 0.0

        ZStack {
            // 1. Disco di Cavitazione (visibile SOLO ad alta velocità durante l'ottimizzazione attiva)
            if blurOpacity > 0.05 {
                Ellipse()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color.white.opacity(blurOpacity * 0.95), location: 0.0),
                                .init(color: BathysPalette.sky.opacity(blurOpacity * 0.75), location: 0.45),
                                .init(color: BathysPalette.teal.opacity(blurOpacity * 0.40), location: 0.80),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: bladeRadius + 3
                        )
                    )
                    .frame(width: 16, height: (bladeRadius + 3) * 2)
                    .overlay(
                        Ellipse()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(blurOpacity * 0.95),
                                        BathysPalette.sky.opacity(blurOpacity * 0.55),
                                        Color.white.opacity(blurOpacity * 0.85)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.4
                            )
                    )
            }

            // 2. Pale dell'elica in rotazione 3D
            Canvas { context, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)

                for i in 0..<3 {
                    let offsetAngle = Double(i) * (2.0 * .pi / 3.0)
                    let currentAngle = spinAngle + offsetAngle

                    let cosA = cos(currentAngle)
                    let sinA = sin(currentAngle)

                    let tipX = c.x + CGFloat(cosA) * (bladeRadius * 0.28)
                    let tipY = c.y + CGFloat(sinA) * bladeRadius

                    let depth = (cosA + 1.0) * 0.5
                    let bladeColor = Color(
                        red: 0.20 + depth * 0.18,
                        green: 0.26 + depth * 0.20,
                        blue: 0.36 + depth * 0.24
                    )

                    var blade = Path()
                    blade.move(to: CGPoint(x: c.x, y: c.y - 2.5))
                    let midX = c.x + CGFloat(cosA) * (bladeRadius * 0.32) + (sinA > 0 ? 2.5 : -2.5)
                    let midY = c.y + CGFloat(sinA) * (bladeRadius * 0.55)
                    blade.addQuadCurve(to: CGPoint(x: tipX, y: tipY), control: CGPoint(x: midX, y: midY))
                    blade.addQuadCurve(to: CGPoint(x: c.x, y: c.y + 2.5), control: CGPoint(x: midX - 2.0, y: midY))
                    blade.closeSubpath()

                    context.fill(blade, with: .color(bladeColor))
                    context.stroke(blade, with: .color(Color.white.opacity(depth * 0.55)), lineWidth: 0.7)
                }
            }
            .frame(width: 38, height: 42)

            // 3. Ogiva centrale del mozzo
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.38, green: 0.46, blue: 0.58),
                            Color(red: 0.16, green: 0.20, blue: 0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: hubRadius * 2, height: hubRadius * 2)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.60), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.50), radius: 2, x: 1, y: 1)
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Scia di Bolle (Placata a riposo, vortice durante ottimizzazione attiva)

struct HighVelocityBubbleVortexView: View {
    let time: Double
    let speedFactor: Double
    let isTurbo: Bool

    var body: some View {
        Canvas { context, size in
            // 1. Getto d'acqua cavitazionale (visibile SOLO durante l'ottimizzazione attiva)
            if isTurbo {
                let plumeLength: CGFloat = 45.0 + CGFloat(speedFactor) * 30.0
                var jet = Path()
                jet.move(to: CGPoint(x: 0, y: -5))
                jet.addCurve(
                    to: CGPoint(x: plumeLength, y: -16 - CGFloat(sin(time * 18.0) * 2.5)),
                    control1: CGPoint(x: plumeLength * 0.35, y: -8),
                    control2: CGPoint(x: plumeLength * 0.75, y: -14)
                )
                jet.addLine(to: CGPoint(x: plumeLength, y: 16 + CGFloat(cos(time * 18.0) * 2.5)))
                jet.addCurve(
                    to: CGPoint(x: 0, y: 5),
                    control1: CGPoint(x: plumeLength * 0.75, y: 14),
                    control2: CGPoint(x: plumeLength * 0.35, y: 8)
                )
                jet.closeSubpath()

                context.opacity = 0.50
                context.fill(
                    jet,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.90),
                            BathysPalette.sky.opacity(0.45),
                            BathysPalette.teal.opacity(0.20),
                            Color.clear
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: plumeLength, y: 0)
                    )
                )
            }

            // 2. Bolle: rade e calme a riposo (12 bolle lente), vortice intenso durante ottimizzazione (52 bolle veloci)
            let bubbleCount = isTurbo ? 52 : 12
            let maxTravelDist: CGFloat = isTurbo ? (85.0 + CGFloat(speedFactor) * 48.0) : 48.0
            let animSpeed = isTurbo ? (2.0 + speedFactor * 1.5) : 0.8

            for i in 0..<bubbleCount {
                let seed = Double(i) * 11.23
                let progress = fmod(time * animSpeed + seed, 1.0)
                let x = CGFloat(progress) * maxTravelDist

                let y: CGFloat
                if isTurbo {
                    let vortexAngle = seed * 6.28 + progress * (9.0 + speedFactor * 7.0) - time * (11.0 + speedFactor * 13.0)
                    let vortexRadius = 3.0 + CGFloat(progress) * (10.0 + CGFloat(speedFactor) * 7.0)
                    let buoyancyDrift = -CGFloat(progress * progress) * 14.0
                    y = CGFloat(sin(vortexAngle)) * vortexRadius + buoyancyDrift + CGFloat(sin(time * 15.0 + seed) * 1.8)
                } else {
                    let buoyancyDrift = -CGFloat(progress) * 12.0
                    y = CGFloat(sin(time * 2.0 + seed)) * 3.5 + buoyancyDrift
                }

                let baseSize: CGFloat = (i % 6 == 0) ? 5.0 : ((i % 3 == 0) ? 3.4 : 2.0)
                let bSize = baseSize * (0.8 + CGFloat(progress) * 0.6)

                let bAlpha = (1.0 - progress * 0.88) * (isTurbo ? 0.75 : 0.38)
                let bRect = CGRect(x: x - bSize / 2, y: y - bSize / 2, width: bSize, height: bSize)

                // Sfera di bolla con riflesso marino
                context.opacity = bAlpha
                context.fill(
                    Path(ellipseIn: bRect),
                    with: .color(Color(red: 0.74, green: 0.96, blue: 1.0))
                )

                // Bordo bianco rifrangente
                context.opacity = bAlpha * 0.95
                context.stroke(
                    Path(ellipseIn: bRect),
                    with: .color(.white),
                    lineWidth: 0.8
                )

                // Riflesso speculare per le bolle medie e grandi
                if bSize > 3.0 {
                    let glintSize = bSize * 0.30
                    let glintRect = CGRect(
                        x: bRect.minX + bSize * 0.22,
                        y: bRect.minY + bSize * 0.20,
                        width: glintSize,
                        height: glintSize
                    )
                    context.opacity = bAlpha * 0.98
                    context.fill(Path(ellipseIn: glintRect), with: .color(.white))
                }
            }
        }
        .frame(width: 320, height: 90)
        .allowsHitTesting(false)
    }
}
