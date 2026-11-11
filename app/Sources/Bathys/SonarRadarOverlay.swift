import SwiftUI

/// Radar unico a tutta finestra del Sonar: compare all'apertura per scegliere il disco e durante la mappatura;
/// a scansione finita si dissolve e resta solo il grafico.
struct SonarRadarOverlay: View {
    @Bindable var sonar: SonarEngine
    let onBack: () -> Void

    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showOtherDisks = false

    private var it: Bool { L10n.lang == .italian }

    private var systemVolume: DiskVolume? {
        sonar.availableVolumes.first { $0.id == "/" } ?? sonar.availableVolumes.first
    }

    private var otherVolumes: [DiskVolume] {
        sonar.availableVolumes.filter { $0.id != systemVolume?.id }
    }

    var body: some View {
        GeometryReader { geo in
            let reserved: CGFloat = showOtherDisks && !sonar.isMappingVolume ? 400 : 300
            let diameter = max(220, min(geo.size.height - reserved, geo.size.width - 120, 460))

            ZStack {
                // Fondo abissale a tutta finestra con un alone ambra al centro
                LinearGradient(
                    colors: [BathysPalette.abyssSky, BathysPalette.abyssDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [BathysPalette.amber.opacity(0.10), BathysPalette.sky.opacity(0.05), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.42),
                    startRadius: 0,
                    endRadius: max(geo.size.width, geo.size.height) * 0.6
                )

                VStack(spacing: 0) {
                    HStack {
                        WorkspaceTopBar(onBack: onBack) { EmptyView() }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 38)

                    Spacer(minLength: 12)

                    // Il radar
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || (controlActiveState == .inactive && !sonar.isMappingVolume))) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.02, green: 0.05, blue: 0.10).opacity(0.98))
                                .frame(width: diameter + 4, height: diameter + 4)
                                .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 14)
                            AzimuthCompassRing(diameter: diameter + 4)
                            SonarRadarInstrument(time: time, sonar: sonar, diameter: diameter)
                        }
                        .frame(width: diameter + 8, height: diameter + 8)
                    }
                    .blurReveal()

                    Spacer(minLength: 20)

                    // In basso al centro: stato della mappatura oppure scelta del disco
                    ZStack(alignment: .bottom) {
                        if sonar.isMappingVolume {
                            VStack(spacing: 8) {
                                Text(it ? "Esploro \(sonar.selectedVolume?.name ?? "il disco")…" : "Exploring \(sonar.selectedVolume?.name ?? "the disk")…")
                                    .font(.system(size: 21, weight: .medium))
                                    .foregroundStyle(BathysPalette.textPrimary)
                                Text(it ? "\(sonar.scannedFilesCount) elementi" : "\(sonar.scannedFilesCount) items")
                                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                                    .foregroundStyle(BathysPalette.amber)
                                    .contentTransition(.numericText())
                                    .animation(.easeOut(duration: 0.2), value: sonar.scannedFilesCount)
                            }
                            .transition(.blurFade)
                        } else if let system = systemVolume {
                            VStack(spacing: 14) {
                                PrimaryDiskButton(volume: system) {
                                    sonar.selectVolume(system)
                                }
                                .blurReveal(delay: 0.15)

                                if !otherVolumes.isEmpty {
                                    Button {
                                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                            showOtherDisks.toggle()
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Text(showOtherDisks
                                                 ? (it ? "Nascondi altri dischi" : "Hide other disks")
                                                 : (it ? "Altri dischi (\(otherVolumes.count))" : "Other disks (\(otherVolumes.count))"))
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 9.5, weight: .bold))
                                                .rotationEffect(.degrees(showOtherDisks ? 180 : 0))
                                        }
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundStyle(BathysPalette.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .blurReveal(delay: 0.25)

                                    if showOtherDisks {
                                        CenteredFlowLayout(spacing: 10, lineSpacing: 10) {
                                            ForEach(Array(otherVolumes.enumerated()), id: \.element.id) { index, volume in
                                                DiskChip(volume: volume) {
                                                    sonar.selectVolume(volume)
                                                }
                                                .blurReveal(delay: Double(index) * 0.03)
                                            }
                                        }
                                        .frame(maxWidth: min(geo.size.width - 80, 900))
                                        .transition(.blurFade)
                                    }
                                }
                            }
                            .transition(.blurFade)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.easeOut(duration: 0.35), value: sonar.isMappingVolume)

                    Spacer(minLength: 36)
                        .frame(maxHeight: 36)
                }
            }
        }
        .onAppear {
            sonar.refreshVolumes()
            // Opzione di avvio per i test visivi
            if CommandLine.arguments.contains("--show-other-disks") { showOtherDisks = true }
        }
    }
}

/// Pulsante principale: esplora il disco di sistema
private struct PrimaryDiskButton: View {
    let volume: DiskVolume
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .semibold))
                Text(L10n.lang == .italian ? "Esplora \(volume.name)" : "Explore \(volume.name)")
                    .font(.system(size: 15, weight: .semibold))
                Text(ByteCountFormatter.string(fromByteCount: volume.availableBytes, countStyle: .file) + (L10n.lang == .italian ? " liberi" : " free"))
                    .font(.system(size: 12.5, weight: .medium).monospacedDigit())
                    .opacity(0.7)
            }
            .foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.02))
            .fixedSize()
            .padding(.horizontal, 22)
            .frame(height: 46)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [BathysPalette.amber, BathysPalette.amber.opacity(0.80)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(Capsule().fill(Color.white.opacity(isHovered ? 0.14 : 0)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .shadow(color: BathysPalette.amber.opacity(isHovered ? 0.55 : 0.35), radius: isHovered ? 18 : 12, x: 0, y: 6)
            .scaleEffect(isHovered ? 1.03 : 1)
            .contentShape(Capsule())
        }
        .buttonStyle(TactileCardButtonStyle())
        .keyboardShortcut(.defaultAction)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) { isHovered = hovering }
        }
    }
}

/// Pillola compatta di scelta di un disco sotto il radar
private struct DiskChip: View {
    let volume: DiskVolume
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: volume.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BathysPalette.amber)
                Text(volume.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BathysPalette.textPrimary)
                    .lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: volume.availableBytes, countStyle: .file))
                    .font(.system(size: 11.5, weight: .regular).monospacedDigit())
                    .foregroundStyle(BathysPalette.textTertiary)
                    .lineLimit(1)
            }
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                Capsule().fill(isHovered ? BathysPalette.amber.opacity(0.16) : BathysPalette.surfaceFill)
            )
            .overlay(
                Capsule().strokeBorder(isHovered ? BathysPalette.amber.opacity(0.55) : BathysPalette.hairline, lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(TactileCardButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
        .help(L10n.lang == .italian
              ? "\(ByteCountFormatter.string(fromByteCount: volume.availableBytes, countStyle: .file)) liberi su \(ByteCountFormatter.string(fromByteCount: volume.totalBytes, countStyle: .file))"
              : "\(ByteCountFormatter.string(fromByteCount: volume.availableBytes, countStyle: .file)) free of \(ByteCountFormatter.string(fromByteCount: volume.totalBytes, countStyle: .file))")
    }
}

/// Dispone gli elementi su più righe, ciascuna centrata (come parole in un paragrafo centrato)
struct CenteredFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [[(index: Int, size: CGSize)]] {
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var lineWidth: CGFloat = 0
        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].isEmpty ? size.width : lineWidth + spacing + size.width
            if needed > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([(i, size)])
                lineWidth = size.width
            } else {
                rows[rows.count - 1].append((i, size))
                lineWidth = needed
            }
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(CGFloat(0)) { acc, row in
            acc + (row.map(\.size.height).max() ?? 0)
        } + lineSpacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map { row in
            row.reduce(CGFloat(0)) { $0 + $1.size.width } + spacing * CGFloat(max(0, row.count - 1))
        }.max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, maxWidth: bounds.width) {
            let rowWidth = row.reduce(CGFloat(0)) { $0 + $1.size.width } + spacing * CGFloat(max(0, row.count - 1))
            let rowHeight = row.map(\.size.height).max() ?? 0
            var x = bounds.minX + (bounds.width - rowWidth) / 2
            for item in row {
                subviews[item.index].place(at: CGPoint(x: x, y: y + (rowHeight - item.size.height) / 2), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += rowHeight + lineSpacing
        }
    }
}
