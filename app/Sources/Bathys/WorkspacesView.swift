import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - MODULE 2: SONAR SPAZIO (Bathys Radial Disk Telemetry)

struct SonarDiskWorkspace: View {
    @Bindable var sonar: SonarEngine
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Top Navigation + Sleek Volume Selector
            WorkspaceTopBar(onBack: onBack) {
                HStack(spacing: 12) {
                    if let selectedVol = sonar.selectedVolume {
                        Menu {
                            ForEach(sonar.availableVolumes) { volume in
                                Button {
                                    sonar.selectVolume(volume)
                                } label: {
                                    HStack {
                                        Text(volume.name + (volume.isInternal ? " (Disco di Sistema)" : ""))
                                        Spacer()
                                        Text(volume.formattedCapacity)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedVol.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(BathysPalette.sky)

                                Text(selectedVol.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(BathysPalette.textPrimary)

                                Text(selectedVol.formattedCapacity)
                                    .font(.system(size: 11.5, weight: .regular))
                                    .foregroundStyle(BathysPalette.textTertiary)

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(BathysPalette.textTertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(BathysPalette.surfaceFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(BathysPalette.hairline, lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .disabled(sonar.isScanning)
                    }

                    Button {
                        sonar.rescanCurrentVolume()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                            Text("Rianalizza disco")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(BathysPalette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(BathysPalette.surfaceFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(BathysPalette.hairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(sonar.isScanning)
                }
            }
            .frame(height: 32)
            .padding(.horizontal, 40)
            .padding(.top, 30)

            // 2. Main Content
            if sonar.isScanning {
                VStack(alignment: .leading, spacing: 14) {
                    Spacer()
                    Text("Scansione spazio su disco…")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BathysPalette.amber)

                    Text("\(sonar.scannedFilesCount) elementi analizzati")
                        .font(.system(size: 44, weight: .light))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: sonar.scannedFilesCount)
                        .foregroundStyle(BathysPalette.textPrimary)

                    Text(sonar.currentScanPath)
                        .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(BathysPalette.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 480, alignment: .leading)
                    Spacer()
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else if let current = sonar.currentNode {
                // Header: Folder Name + Total Size + Safety analysis note
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(localizedFolderName(current))
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(BathysPalette.textPrimary)
                            .lineLimit(1)

                        Text(current.formattedSize)
                            .font(.system(size: 32, weight: .light))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(BathysPalette.textTertiary)

                        Spacer()
                    }

                    Text("Mappa visiva dello spazio • Analisi topologica settori APFS.")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(BathysPalette.textTertiary)
                }
                .frame(height: 58, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.top, 24)
                .padding(.bottom, 14)

                // Symmetrical 2-Column Body: Sunburst Instrument Panel (Left) + Top Folders (Right)
                HStack(alignment: .center, spacing: 28) {
                    NauticalConsolePanel(size: 292) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.02, green: 0.05, blue: 0.10).opacity(0.98))
                                .frame(width: 252, height: 252)
                            AzimuthCompassRing(diameter: 252)
                            BathysSunburstView(sonar: sonar, currentNode: current, diameter: 248)
                                .frame(width: 248, height: 248)
                        }
                    }

                    VStack(spacing: 8) {
                        if sonar.navigationStack.count > 1 {
                            SonarNavigateUpRow(sonar: sonar)
                        }

                        ForEach(orderedDisplayNodes(for: current)) { child in
                            SonarNodeRow(
                                node: child,
                                parentTotalBytes: max(1, current.bytes),
                                isHovered: sonar.hoveredNode?.id == child.id,
                                onHover: { hovering in
                                    sonar.hoveredNode = hovering ? child : nil
                                },
                                onDrillDown: {
                                    sonar.drillDown(into: child)
                                },
                                onTrash: {
                                    guard !child.isSystemFile && child.safetyRule != .systemProtected else { return }
                                    if AppSettings.shared.confirmBeforeClean {
                                        sonar.nodePendingTrash = child
                                    } else {
                                        sonar.moveNodeToTrash(child)
                                    }
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.spring(response: 0.28, dampingFraction: 0.84), value: current.id)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(item: $sonar.nodePendingTrash) { nodeToTrash in
            let isContainer = nodeToTrash.safetyRule == .emptyContentsOnly
            TrashConfirmationSheet(
                title: isContainer
                    ? "Svuotare il contenuto di \"\(nodeToTrash.name)\"?"
                    : "Spostare \"\(nodeToTrash.name)\" nel Cestino?",
                subtitle: isContainer
                    ? "Bathys preserverà la cartella strutturale \"\(nodeToTrash.name)\" richiesta da macOS, spostando nel Cestino solo i file temporanei e le cache al suo interno."
                    : nodeToTrash.displayPath,
                bytes: nodeToTrash.bytes,
                confirmLabel: isContainer ? "Svuota contenuto" : "Sposta nel Cestino",
                onCancel: { sonar.nodePendingTrash = nil },
                onConfirm: { sonar.moveNodeToTrash(nodeToTrash) }
            )
            .presentationBackground(BathysPalette.workspaceBottom)
        }
    }

    private func orderedDisplayNodes(for current: DiskNode) -> [DiskNode] {
        let userNodes = current.children.filter { !$0.isSystemFile }.sorted { $0.bytes > $1.bytes }
        let systemNodes = current.children.filter { $0.isSystemFile }.sorted { $0.bytes > $1.bytes }
        let maxItems = sonar.navigationStack.count > 1 ? 7 : 8
        return Array((userNodes + systemNodes).prefix(maxItems))
    }

    private func localizedFolderName(_ node: DiskNode) -> String {
        if node.path == "/" {
            return sonar.selectedVolume?.name ?? "Macintosh HD"
        }
        if node.path == "/Library" {
            return "Libreria condivisa"
        }
        if node.path == "/System" {
            return "Sistema macOS"
        }
        if let vol = sonar.availableVolumes.first(where: { $0.id == node.path }) {
            return vol.name
        }
        if node.path.contains("/var/folders/") {
            switch node.name {
            case "C": return "Cache Darwin (C)"
            case "T": return "Temporanei Darwin (T)"
            case "0": return "Sistema Darwin (0)"
            case "X": return "Sandbox Darwin (X)"
            default: break
            }
        }
        switch node.name {
        case "Library": return "Libreria"
        case "Applications": return "Applicazioni"
        case "Downloads": return "Download"
        case "Documents": return "Documenti"
        case "Movies": return "Filmati"
        case "Music": return "Musica"
        case "Pictures": return "Immagini"
        case "Desktop": return "Scrivania"
        case "Users": return "Utenti"
        default: return node.name
        }
    }
}

// MARK: - Interactive Bathys Sunburst Chart

struct BathysSunburstView: View {
    @Bindable var sonar: SonarEngine
    let currentNode: DiskNode
    var diameter: CGFloat = 248

    var body: some View {
        let segments = sonar.sunburstSegments
        let scale = diameter / 248.0

        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let center = CGPoint(x: w / 2, y: h / 2)

            ZStack {
                Canvas { context, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)

                    for seg in segments {
                        let (innerR, outerR) = radii(for: seg.ring, scale: scale)
                        let isHovered = sonar.hoveredNode?.id == seg.node.id
                        let effectiveOuterR = isHovered ? outerR + 2.5 : outerR

                        var arc = Path()
                        let gap = 0.010
                        let a0 = seg.startAngle + gap / 2
                        let a1 = max(a0 + 0.004, seg.endAngle - gap / 2)

                        arc.addArc(center: c, radius: innerR, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
                        arc.addArc(center: c, radius: effectiveOuterR, startAngle: .radians(a1), endAngle: .radians(a0), clockwise: true)
                        arc.closeSubpath()

                        let baseColor = seg.node.isSystemFile
                            ? Color(red: 0.22, green: 0.28, blue: 0.36)
                            : BathysPalette.chartColor(for: seg.colorIndex)
                        let ringOpacity: Double = seg.node.isSystemFile
                            ? 0.40
                            : (seg.ring == 0 ? 0.88 : (seg.ring == 1 ? 0.64 : 0.44))

                        context.opacity = isHovered ? 1.0 : ringOpacity
                        context.fill(arc, with: .color(baseColor))
                    }
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let pt):
                        sonar.hoveredNode = hitTestSegment(at: pt, center: center, segments: segments, scale: scale)?.node
                    case .ended:
                        sonar.hoveredNode = nil
                    }
                }
                .onTapGesture { pt in
                    let dx = pt.x - center.x
                    let dy = pt.y - center.y
                    let dist = hypot(dx, dy)
                    if dist < 47 * scale {
                        sonar.navigateUp()
                    } else if let hit = hitTestSegment(at: pt, center: center, segments: segments, scale: scale) {
                        sonar.drillDown(into: hit.node)
                    }
                }

                // Command Deck Center Hub (Enlarged with single-line size display)
                let hubSize: CGFloat = 94 * scale
                VStack(spacing: 3) {
                    if let hovered = sonar.hoveredNode {
                        Text(hovered.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(BathysPalette.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: hubSize * 0.88)

                        Text(hovered.formattedSize)
                            .font(.system(size: 12.5, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.80)
                    } else {
                        let centerTitle: String = {
                            if currentNode.path.contains("/var/folders/") && !["C", "T", "0", "X"].contains(currentNode.name) {
                                return "Darwin (/var)"
                            }
                            return currentNode.name == "Library" ? "Libreria" : currentNode.name
                        }()
                        Text(centerTitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(BathysPalette.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: hubSize * 0.88)

                        Text(currentNode.formattedSize)
                            .font(.system(size: 12.5, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.80)
                    }
                }
                .frame(width: hubSize, height: hubSize)
                .background(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.13, blue: 0.20),
                                    BathysPalette.workspaceBottom
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: hubSize / 2
                            )
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .allowsHitTesting(false)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func radii(for ring: Int, scale: CGFloat) -> (CGFloat, CGFloat) {
        switch ring {
        case 0: return (49 * scale, 74 * scale)
        case 1: return (77 * scale, 98 * scale)
        default: return (101 * scale, 122 * scale)
        }
    }

    private func hitTestSegment(at point: CGPoint, center: CGPoint, segments: [SunburstSegment], scale: CGFloat) -> SunburstSegment? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let dist = hypot(dx, dy)

        let ring: Int
        if dist >= 49 * scale && dist <= 74 * scale {
            ring = 0
        } else if dist > 74 * scale && dist <= 98 * scale {
            ring = 1
        } else if dist > 98 * scale && dist <= 122 * scale {
            ring = 2
        } else {
            return nil
        }

        var angle = atan2(dy, dx)
        if angle < -Double.pi / 2.0 {
            angle += Double.pi * 2.0
        }

        return segments.first { seg in
            seg.ring == ring && angle >= seg.startAngle && angle <= seg.endAngle
        }
    }
}

struct SonarNavigateUpRow: View {
    @Bindable var sonar: SonarEngine
    @State private var isHovered = false

    var body: some View {
        Button {
            sonar.navigateUp()
        } label: {
            HStack(spacing: 12) {
                // Indicatore freccia risalita circolare
                ZStack {
                    Circle()
                        .fill(isHovered ? BathysPalette.sky.opacity(0.24) : BathysPalette.sky.opacity(0.14))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(BathysPalette.sky.opacity(0.32), lineWidth: 1))

                    Image(systemName: "arrow.turn.left.up")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(BathysPalette.sky)
                }

                Text("Cartella superiore")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isHovered ? .white : BathysPalette.sky)

                Spacer(minLength: 8)

                if let parentNode = sonar.navigationStack.dropLast().last {
                    Text(displayParentName(parentNode))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(BathysPalette.textTertiary)
                }

                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(BathysPalette.sky.opacity(0.70))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? BathysPalette.sky.opacity(0.12) : BathysPalette.surfaceFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isHovered ? BathysPalette.sky.opacity(0.42) : BathysPalette.sky.opacity(0.24), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private func displayParentName(_ node: DiskNode) -> String {
        if node.path == "/" {
            return sonar.selectedVolume?.name ?? "Macintosh HD"
        }
        return node.name
    }
}

struct SonarNodeRow: View {
    let node: DiskNode
    let parentTotalBytes: Int64
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onDrillDown: () -> Void
    let onTrash: () -> Void

    var body: some View {
        let isSystem = node.isSystemFile
        let rule = node.safetyRule
        let chartColor = BathysPalette.chartColor(for: node.colorIndex)

        HStack(spacing: 12) {
            // Indicatore circolare
            Circle()
                .fill(isSystem ? Color(red: 0.32, green: 0.38, blue: 0.46).opacity(0.70) : chartColor)
                .frame(width: isSystem ? 8 : 9, height: isSystem ? 8 : 9)

            // Titolo cartella cliccabile con supporto drill-down immediato
            Button {
                if node.isDirectory {
                    onDrillDown()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(displayNodeTitle)
                        .font(.system(size: 14, weight: isSystem ? .regular : .medium))
                        .foregroundStyle(isSystem ? Color(white: 0.62) : BathysPalette.textPrimary)
                        .lineLimit(1)

                    // Badge di stato e sicurezza con icona computer per il sistema
                    if isSystem {
                        HStack(spacing: 3.5) {
                            Image(systemName: "laptopcomputer")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Sistema")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(Color(red: 0.58, green: 0.70, blue: 0.86))
                        .padding(.horizontal, 6.5)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.13, green: 0.18, blue: 0.28).opacity(0.75))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(red: 0.28, green: 0.38, blue: 0.54).opacity(0.40), lineWidth: 0.8)
                        )
                    } else if rule == .emptyContentsOnly {
                        Text("Svuota interno")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(BathysPalette.teal)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(BathysPalette.teal.opacity(0.12)))
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            if isHovered {
                HStack(spacing: 6) {
                    // 1. Mostra nel Finder (Pulsante rotondo lavorato)
                    BathysRoundIconButton(
                        icon: "magnifyingglass",
                        size: 26,
                        iconSize: 11,
                        tint: BathysPalette.sky,
                        helpText: "Mostra \"\(node.name)\" nel Finder"
                    ) {
                        NSWorkspace.shared.selectFile(node.path, inFileViewerRootedAtPath: "")
                    }

                    // 2. Cestino / Svuotamento (Pulsante rotondo lavorato — bloccato per file di sistema)
                    if !isSystem && rule != .systemProtected {
                        BathysRoundIconButton(
                            icon: rule == .emptyContentsOnly ? "sparkles" : "trash.fill",
                            size: 26,
                            iconSize: 11,
                            tint: rule == .emptyContentsOnly ? BathysPalette.teal : BathysPalette.coral,
                            isDestructive: rule != .emptyContentsOnly,
                            helpText: rule == .emptyContentsOnly
                                ? "Svuota il contenuto interno (preserva la cartella \(node.name))"
                                : "Sposta \"\(node.name)\" nel Cestino"
                        ) {
                            onTrash()
                        }
                    }
                }
                .padding(.trailing, 6)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            Text(node.bytes == 0 && isSystem ? "Sistema" : node.formattedSize)
                .font(.system(size: 13.5, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(isSystem ? BathysPalette.textTertiary : BathysPalette.textSecondary)

            if node.isDirectory {
                BathysRoundIconButton(
                    icon: "chevron.right",
                    size: 22,
                    iconSize: 9.5,
                    tint: chartColor
                ) {
                    onDrillDown()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered
                    ? (isSystem ? Color(white: 0.12).opacity(0.55) : BathysPalette.surfaceFillHover)
                    : (isSystem ? Color(white: 0.04).opacity(0.35) : BathysPalette.surfaceFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSystem ? BathysPalette.hairline.opacity(0.55) : (isHovered ? BathysPalette.hairlineHover : BathysPalette.hairline), lineWidth: 1)
        )
        .opacity(isSystem ? (isHovered ? 0.90 : 0.65) : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            if node.isDirectory {
                onDrillDown()
            }
        }
        .onHover(perform: onHover)
    }

    private var displayNodeTitle: String {
        let p = (node.path as NSString).standardizingPath
        if p == "/System" { return "Sistema macOS" }
        if p == "/Library" { return "Libreria condivisa" }
        if p == "/usr" { return "File binari Unix (usr)" }
        if p == "/private" { return "Cartelle protette di sistema (private)" }
        if p == "/bin" { return "Binari base (bin)" }
        if p == "/sbin" { return "Binari di amministrazione (sbin)" }
        if p == "/Users" { return "Utenti & File Personali" }
        if p == "/Applications" { return "Applicazioni installate" }

        if node.path.contains("/var/folders/") {
            switch node.name {
            case "C": return "C — Cache Darwin"
            case "T": return "T — Temporanei Darwin"
            case "0": return "0 — Stato Sistema"
            case "X": return "X — Sandbox Sistema"
            default: break
            }
        }

        switch node.name {
        case "Pictures": return "Immagini"
        case "Movies": return "Filmati"
        case "Music": return "Musica"
        case "Downloads": return "Download"
        case "Documents": return "Documenti"
        case "Desktop": return "Scrivania"
        case "Library": return "Libreria"
        case "Applications": return "Applicazioni"
        case "Public": return "Condivisa"
        default: return node.name
        }
    }
}

// MARK: - MODULE 3: DISINSTALLA APP (Bathys Deep Application Uninstaller)

struct UninstallerWorkspace: View {
    @Bindable var uninstaller: UninstallerEngine
    let onBack: () -> Void
    @State private var isDropTargeted = false
    @State private var keyMonitor: Any? = nil
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Top Bar: Back Button + Clean Search + Browse
            WorkspaceTopBar(onBack: onBack) {
                HStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11.5))
                            .foregroundStyle(BathysPalette.textTertiary)
                        TextField("Cerca applicazione…", text: $uninstaller.searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .frame(width: 155)
                            .focused($isSearchFocused)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(BathysPalette.surfaceFill))
                    .overlay(Capsule().strokeBorder(BathysPalette.hairline, lineWidth: 1))

                    Button {
                        uninstaller.pickAppFromDisk()
                    } label: {
                        Text("Sfoglia…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(BathysPalette.textSecondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(BathysPalette.surfaceFill))
                            .overlay(Capsule().strokeBorder(BathysPalette.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 52)
            .padding(.top, 30)
            .padding(.bottom, 22)

            // 2. Symmetrical 2-Column Layout with Generous Margins
            HStack(alignment: .top, spacing: 26) {
                // Left Column: Installed Apps List with Arrow Navigation and Smooth Auto-Scroll
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 4) {
                            ForEach(uninstaller.filteredApps) { app in
                                let isSelected = uninstaller.selectedApp?.id == app.id
                                Button {
                                    withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                                        uninstaller.inspectApp(app)
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 30, height: 30)

                                         VStack(alignment: .leading, spacing: 1.5) {
                                            HStack(spacing: 6) {
                                                Text(app.name)
                                                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                                                    .foregroundStyle(isSelected ? .white : BathysPalette.textSecondary)
                                                    .lineLimit(1)

                                                if app.isRunning {
                                                    Circle()
                                                        .fill(BathysPalette.amber)
                                                        .frame(width: 6, height: 6)
                                                        .help("Applicazione attualmente in esecuzione")
                                                }
                                            }

                                            if let sub = app.subfolderName {
                                                Text(sub)
                                                    .font(.system(size: 10, weight: .regular))
                                                    .foregroundStyle(isSelected ? Color.white.opacity(0.65) : BathysPalette.textTertiary)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(isSelected ? BathysPalette.surfaceFillSelected : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(isSelected ? Color.white.opacity(0.14) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(app.id)
                            }
                        }
                        .padding(10)
                    }
                    .onChange(of: uninstaller.selectedApp?.id) { _, newId in
                        if let newId {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                scrollProxy.scrollTo(newId, anchor: .center)
                            }
                        }
                    }
                }
                .frame(width: 235)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.028))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(BathysPalette.hairline, lineWidth: 1)
                )

                // Right Column: Selected App & Associated Files
                if let app = uninstaller.selectedApp {
                    VStack(alignment: .leading, spacing: 0) {
                        // App Hero Header
                        HStack(spacing: 14) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(app.name)
                                        .font(.system(size: 26, weight: .light))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    if app.isRunning {
                                        HStack(spacing: 5) {
                                            Circle()
                                                .fill(BathysPalette.amber)
                                                .frame(width: 6, height: 6)
                                            Text(L10n.lang == .italian ? "In esecuzione" : "Running")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(BathysPalette.amber)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(BathysPalette.amber.opacity(0.12)))
                                        .overlay(Capsule().strokeBorder(BathysPalette.amber.opacity(0.28), lineWidth: 1))
                                    }
                                }

                                let subfolderBadge = app.subfolderName.map { " • \($0)" } ?? ""
                                Text("v\(app.version)\(subfolderBadge) • \(uninstaller.residuals.count) elementi")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(BathysPalette.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 5) {
                                Text(ByteCountFormatter.string(fromByteCount: uninstaller.totalSelectedBytes, countStyle: .file))
                                    .font(.system(size: 26, weight: .light))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                    .animation(.spring(response: 0.26, dampingFraction: 0.82), value: uninstaller.totalSelectedBytes)
                                    .foregroundStyle(.white)

                                if uninstaller.residuals.count > 1 {
                                    HStack(spacing: 4) {
                                        Button {
                                            withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                                                uninstaller.setUninstallScope(resetOnly: false)
                                            }
                                        } label: {
                                            Text(L10n.lang == .italian ? "Completa" : "Full")
                                                .font(.system(size: 11, weight: !uninstaller.isResetOnlyMode ? .semibold : .regular))
                                                .foregroundStyle(!uninstaller.isResetOnlyMode ? .white : BathysPalette.textTertiary)
                                                .padding(.horizontal, 9)
                                                .padding(.vertical, 3)
                                                .background(Capsule().fill(!uninstaller.isResetOnlyMode ? BathysPalette.surfaceFillSelected : Color.clear))
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                                                uninstaller.setUninstallScope(resetOnly: true)
                                            }
                                        } label: {
                                            Text(L10n.lang == .italian ? "Solo Reset Dati" : "Reset Data Only")
                                                .font(.system(size: 11, weight: uninstaller.isResetOnlyMode ? .semibold : .regular))
                                                .foregroundStyle(uninstaller.isResetOnlyMode ? BathysPalette.amber : BathysPalette.textTertiary)
                                                .padding(.horizontal, 9)
                                                .padding(.vertical, 3)
                                                .background(Capsule().fill(uninstaller.isResetOnlyMode ? BathysPalette.amber.opacity(0.16) : Color.clear))
                                        }
                                        .buttonStyle(.plain)
                                        .help(L10n.lang == .italian
                                              ? "Mantiene l'app installata ma elimina cache, preferenze e stati corrotti"
                                              : "Keeps the .app bundle installed and removes only caches, preferences, and states")
                                    }
                                    .padding(2)
                                    .background(Capsule().fill(Color.white.opacity(0.035)))
                                    .overlay(Capsule().strokeBorder(BathysPalette.hairline, lineWidth: 1))
                                }
                            }
                        }
                        .padding(.bottom, 16)

                        // Residual Items List (Top 5 visible without clipping, scrollable if more)
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 7) {
                                ForEach($uninstaller.residuals) { $item in
                                    ResidualItemRow(item: $item)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        // Centered Bottom Action Button with Keyboard Shortcut Hint
                        HStack {
                            Spacer()
                            CircularActionOrbButton(
                                label: uninstaller.isResetOnlyMode
                                    ? (L10n.lang == .italian ? "Reset Dati" : "Reset App")
                                    : (L10n.lang == .italian ? "Disinstalla" : "Uninstall"),
                                iconName: uninstaller.isResetOnlyMode ? "arrow.counterclockwise" : "trash.fill",
                                tint: uninstaller.isResetOnlyMode ? BathysPalette.amber : BathysPalette.coral,
                                isDisabled: uninstaller.totalSelectedBytes == 0,
                                shortcutHint: "⌫"
                            ) {
                                if AppSettings.shared.confirmBeforeClean {
                                    uninstaller.showUninstallConfirmation = true
                                } else {
                                    uninstaller.uninstallSelectedItems()
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, 14)
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("Seleziona o trascina un'applicazione")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(BathysPalette.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 52)
            .padding(.bottom, 26)
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) {
            uninstaller.selectPreviousApp()
            return .handled
        }
        .onKeyPress(.downArrow) {
            uninstaller.selectNextApp()
            return .handled
        }
        .onKeyPress(.delete) {
            if uninstaller.selectedApp != nil && uninstaller.totalSelectedBytes > 0 {
                if AppSettings.shared.confirmBeforeClean {
                    uninstaller.showUninstallConfirmation = true
                } else {
                    uninstaller.uninstallSelectedItems()
                }
                return .handled
            }
            return .ignored
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard let first = providers.first else { return false }
            _ = first.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    Task { @MainActor in
                        uninstaller.handleDroppedAppURL(url)
                    }
                }
            }
            return true
        }
        .onAppear {
            if uninstaller.apps.isEmpty {
                uninstaller.loadInstalledApps()
            }

            // Monitor locale tastiera: Frecce Su/Giù e Backspace (51)
            if keyMonitor == nil {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if isSearchFocused {
                        if event.keyCode == 126 { // Freccia Su
                            uninstaller.selectPreviousApp()
                            return nil
                        } else if event.keyCode == 125 { // Freccia Giù
                            uninstaller.selectNextApp()
                            return nil
                        } else if event.keyCode == 53 { // ESC
                            isSearchFocused = false
                            return nil
                        }
                        return event
                    }

                    switch event.keyCode {
                    case 126: // Freccia Su
                        uninstaller.selectPreviousApp()
                        return nil

                    case 125: // Freccia Giù
                        uninstaller.selectNextApp()
                        return nil

                    case 51: // Backspace / Delete
                        if uninstaller.selectedApp != nil && uninstaller.totalSelectedBytes > 0 {
                            if AppSettings.shared.confirmBeforeClean {
                                uninstaller.showUninstallConfirmation = true
                            } else {
                                uninstaller.uninstallSelectedItems()
                            }
                            return nil
                        }
                        return event

                    default:
                        return event
                    }
                }
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
        .sheet(isPresented: $uninstaller.showUninstallConfirmation) {
            if let app = uninstaller.selectedApp {
                let isReset = uninstaller.isResetOnlyMode
                let runningNote = app.isRunning ? " L'applicazione è attualmente aperta e verrà chiusa in sicurezza prima dell'operazione." : ""
                TrashConfirmationSheet(
                    title: isReset ? "Ripristinare i dati di \(app.name)?" : "Disinstallare \(app.name)?",
                    subtitle: (isReset
                        ? "L'applicazione rimarrà installata in /Applications, mentre cache, preferenze e file di stato selezionati verranno spostati nel Cestino."
                        : "L'applicazione e tutti i suoi file di supporto, cache e preferenze selezionati verranno spostati nel Cestino.") + runningNote,
                    bytes: uninstaller.totalSelectedBytes,
                    confirmLabel: isReset ? "Reset Dati" : "Disinstalla",
                    previewItems: uninstaller.residuals.filter(\.isSelected).map {
                        TrashPreviewItem(name: $0.name, detail: $0.kind.rawValue, bytes: $0.bytes, path: $0.path)
                    },
                    onCancel: { uninstaller.showUninstallConfirmation = false },
                    onConfirm: { uninstaller.uninstallSelectedItems() }
                )
                .presentationBackground(BathysPalette.workspaceBottom)
            }
        }
    }
}

struct ResidualItemRow: View {
    @Binding var item: AppResidualItem
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            BathysRoundCheckButton(
                isSelected: $item.isSelected,
                tint: BathysPalette.teal,
                size: 18
            )

            VStack(alignment: .leading, spacing: 1.5) {
                Text(humanKindTitle(for: item.kind, name: item.name))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(item.isSelected ? .white : BathysPalette.textSecondary)
                    .lineLimit(1)

                Text(item.displayPath)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(BathysPalette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isHovered {
                BathysRoundIconButton(
                    icon: "magnifyingglass",
                    size: 24,
                    iconSize: 10.5,
                    tint: BathysPalette.teal,
                    helpText: "Mostra nel Finder"
                ) {
                    NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                }
            }

            Text(item.formattedSize)
                .font(.system(size: 13, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(item.isSelected ? BathysPalette.textSecondary : BathysPalette.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8.5)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isHovered ? BathysPalette.surfaceFillHover : BathysPalette.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(isHovered ? BathysPalette.hairlineHover : BathysPalette.hairline, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }

    private func humanKindTitle(for kind: AppResidualItem.Kind, name: String) -> String {
        switch kind {
        case .appBundle: return "Applicazione (\(name))"
        case .appSupport: return "File di supporto (\(name))"
        case .container: return "Container isolato (\(name))"
        case .cache: return "Cache (\(name))"
        case .preferences: return "Preferenze (\(name))"
        case .launchAgent: return "Agente di avvio (\(name))"
        case .stateAndLogs: return "Stato finestre e log (\(name))"
        case .receipt: return "Ricevuta installazione (\(name))"
        }
    }
}

// MARK: - MODULE 4: PRESTAZIONI (Separated Tabs for Breathability — Zero Crowding)

struct OptimizationWorkspace: View {
    @Bindable var optimizer: OptimizerEngine
    let onBack: () -> Void
    @State private var selectedSection: Int = 0 // 0 = Manutenzione, 1 = Elementi di Avvio

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Top Bar: Back Button + Segmented Switcher (Manutenzione | Elementi di Avvio)
            WorkspaceTopBar(onBack: onBack) {
                HStack(spacing: 4) {
                    sectionTabButton(title: "Manutenzione", index: 0)
                    sectionTabButton(title: "Elementi di Avvio (\(optimizer.launchAgents.count))", index: 1)
                }
                .padding(3)
                .background(Capsule().fill(Color.white.opacity(0.04)))
                .overlay(Capsule().strokeBorder(BathysPalette.hairline, lineWidth: 1))
            }
            .padding(.horizontal, 48)
            .padding(.top, 30)

            // 2. Clean 3-Card Telemetry Summary Strip
            HStack(spacing: 14) {
                TelemetryMetricPill(
                    title: "Memoria RAM",
                    value: String(format: "%.0f%%", optimizer.ramUsedFraction * 100),
                    detail: "\(ByteCountFormatter.string(fromByteCount: Int64(optimizer.ramUsedBytes), countStyle: .memory)) in uso",
                    tint: BathysPalette.amber
                )

                TelemetryMetricPill(
                    title: "Disco APFS",
                    value: ByteCountFormatter.string(fromByteCount: optimizer.diskFreeBytes, countStyle: .file),
                    detail: "Spazio disponibile",
                    tint: BathysPalette.sky
                )

                TelemetryMetricPill(
                    title: "Elementi di Avvio",
                    value: "\(optimizer.launchAgents.count)",
                    detail: optimizer.orphanedAgentsCount > 0 ? "\(optimizer.orphanedAgentsCount) orfani rilevati" : "Servizi attivi",
                    tint: BathysPalette.emerald
                )
            }
            .padding(.horizontal, 48)
            .padding(.top, 22)
            .padding(.bottom, 22)

            // 3. Active Section Body (Full Vertical Breathing Room)
            ZStack {
                if selectedSection == 0 {
                    maintenanceSectionBody
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else {
                    startupAgentsSectionBody
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
            .animation(.spring(response: 0.30, dampingFraction: 0.85), value: selectedSection)
        }
        .onAppear {
            optimizer.refreshTelemetry()
            if optimizer.launchAgents.isEmpty {
                optimizer.scanLaunchAgents()
            }
        }
    }

    private func sectionTabButton(title: String, index: Int) -> some View {
        let isSelected = selectedSection == index
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedSection = index
            }
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .white : BathysPalette.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? BathysPalette.surfaceFillSelected : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var maintenanceSectionBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach($optimizer.tasks) { $task in
                    HStack(spacing: 14) {
                        BathysRoundCheckButton(
                            isSelected: $task.isSelected,
                            tint: BathysPalette.emerald,
                            size: 19
                        )

                        ZStack {
                            Circle()
                                .fill(BathysPalette.emerald.opacity(0.14))
                                .frame(width: 34, height: 34)
                                .overlay(Circle().strokeBorder(BathysPalette.emerald.opacity(0.24), lineWidth: 1))
                            Image(systemName: task.symbol)
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(BathysPalette.emerald)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                            Text(task.subtitle)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(BathysPalette.textTertiary)
                        }

                        Spacer()

                        statusView(for: task.status)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(BathysPalette.surfaceFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(BathysPalette.hairline, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 48)

            Spacer()

            HStack {
                Spacer()
                CircularActionOrbButton(
                    label: optimizer.isRunningTasks ? "Attendi…" : "Ottimizza",
                    iconName: "bolt.fill",
                    tint: BathysPalette.emerald,
                    isDisabled: optimizer.isRunningTasks
                ) {
                    optimizer.runSelectedOptimizations()
                }
                Spacer()
            }
            .padding(.bottom, 24)
        }
    }

    private var startupAgentsSectionBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(optimizer.launchAgents) { agent in
                    HStack(spacing: 14) {
                        Circle()
                            .fill(agent.isOrphaned ? BathysPalette.coral : BathysPalette.emerald)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(agent.label)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                if agent.isOrphaned {
                                    Text("Orfano")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(BathysPalette.coral)
                                }
                            }

                            Text(agent.executablePath)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(BathysPalette.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        BathysRoundIconButton(
                            icon: "magnifyingglass",
                            size: 26,
                            iconSize: 11,
                            tint: BathysPalette.emerald,
                            helpText: "Mostra nel Finder"
                        ) {
                            NSWorkspace.shared.selectFile(agent.plistPath, inFileViewerRootedAtPath: "")
                        }

                        if agent.isUserAgent {
                            BathysRoundIconButton(
                                icon: "trash.fill",
                                size: 26,
                                iconSize: 11,
                                tint: BathysPalette.coral,
                                isDestructive: true,
                                helpText: "Sposta nel Cestino"
                            ) {
                                optimizer.removeLaunchAgent(agent)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BathysPalette.surfaceFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(BathysPalette.hairline, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func statusView(for status: OptimizationTaskItem.Status) -> some View {
        switch status {
        case .ready:
            EmptyView()
        case .running:
            ProgressView().controlSize(.small)
        case .completed(let msg):
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                Text(msg)
                    .font(.system(size: 12, weight: .regular))
            }
            .foregroundStyle(BathysPalette.emerald)
        case .failed(let err):
            Text(err)
                .font(.system(size: 12))
                .foregroundStyle(BathysPalette.coral)
        }
    }
}

struct TelemetryMetricPill: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(BathysPalette.textSecondary)
                Spacer()
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
            }

            Text(value)
                .font(.system(size: 22, weight: .light))
                .monospacedDigit()
                .foregroundStyle(.white)

            Text(detail)
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(BathysPalette.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BathysPalette.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(BathysPalette.hairline, lineWidth: 1)
        )
    }
}

// MARK: - High-Craft Clean & Safety Confirmation Sheet

struct TrashPreviewItem: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let bytes: Int64
    let path: String?
}

struct TrashConfirmationSheet: View {
    let title: String
    let subtitle: String
    let bytes: Int64
    let confirmLabel: String
    var includesPermanentTrash: Bool = false
    var previewItems: [TrashPreviewItem] = []
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            BathysPalette.workspaceBottom
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(BathysPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Safety & Reversibility Guarantee Pill
                HStack(spacing: 10) {
                    Image(systemName: includesPermanentTrash ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(includesPermanentTrash ? BathysPalette.amber : BathysPalette.emerald)

                    Text(includesPermanentTrash
                         ? (L10n.lang == .italian
                            ? "Include lo svuotamento definitivo del Cestino di macOS. Gli altri file vanno nel Cestino."
                            : "Includes emptying macOS Trash permanently. Other items move safely to Trash.")
                         : (L10n.lang == .italian
                            ? "Spostamento sicuro nel Cestino • Puoi ripristinare qualsiasi file dal Finder in ogni momento."
                            : "Safe move to macOS Trash • You can restore any file from Finder at any time."))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(includesPermanentTrash ? BathysPalette.amber : BathysPalette.emerald)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((includesPermanentTrash ? BathysPalette.amber : BathysPalette.emerald).opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder((includesPermanentTrash ? BathysPalette.amber : BathysPalette.emerald).opacity(0.24), lineWidth: 1)
                )

                // Interactive Preview Breakdown (if provided)
                if !previewItems.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 5) {
                            ForEach(previewItems.prefix(8)) { item in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.name)
                                            .font(.system(size: 12.5, weight: .medium))
                                            .foregroundStyle(BathysPalette.textPrimary)
                                            .lineLimit(1)

                                        Text(item.detail)
                                            .font(.system(size: 10.5, weight: .regular))
                                            .foregroundStyle(BathysPalette.textTertiary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Text(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))
                                        .font(.system(size: 12, weight: .medium))
                                        .monospacedDigit()
                                        .foregroundStyle(BathysPalette.textSecondary)

                                    if let p = item.path, !p.isEmpty {
                                        BathysRoundIconButton(
                                            icon: "magnifyingglass",
                                            size: 22,
                                            iconSize: 10,
                                            tint: BathysPalette.sky,
                                            helpText: L10n.lang == .italian ? "Mostra nel Finder" : "Reveal in Finder"
                                        ) {
                                            NSWorkspace.shared.selectFile(p, inFileViewerRootedAtPath: "")
                                        }
                                    }
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.03))
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 165)
                }

                HStack {
                    Text(L10n.lang == .italian ? "Spazio totale selezionato:" : "Total selected space:")
                        .font(.system(size: 13))
                        .foregroundStyle(BathysPalette.textSecondary)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(BathysPalette.surfaceFill))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(BathysPalette.hairline, lineWidth: 1))

                HStack {
                    Button(L10n.lang == .italian ? "Annulla" : "Cancel", action: onCancel)
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BathysPalette.textSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(BathysPalette.surfaceFill))
                        .overlay(Capsule().strokeBorder(BathysPalette.hairline, lineWidth: 1))
                        .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button(action: onConfirm) {
                        Text(confirmLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(BathysPalette.coral))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(26)
        }
        .frame(width: 460)
        .background(BathysPalette.workspaceBottom)
        .background(SheetWindowCustomizer())
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}
