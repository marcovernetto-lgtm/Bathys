import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - MODULE 2: SONAR SPAZIO (Bathys Radial Disk Telemetry)

struct SonarDiskWorkspace: View {
    @Bindable var sonar: SonarEngine
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Navigazione + selettore del disco
            WorkspaceTopBar(onBack: onBack) {
                HStack(spacing: DS.Space.xs) {
                    if let selectedVol = sonar.selectedVolume {
                        Menu {
                            ForEach(sonar.availableVolumes) { volume in
                                Button {
                                    sonar.selectVolume(volume)
                                } label: {
                                    Text("\(volume.name) — \(volume.formattedCapacity)")
                                }
                            }
                        } label: {
                            HStack(spacing: DS.Space.xs) {
                                Image(systemName: selectedVol.isInternal ? "internaldrive" : "externaldrive")
                                    .foregroundStyle(BathysPalette.amber)
                                Text(selectedVol.name)
                                    .font(DS.Font.control)
                                    .foregroundStyle(DS.Ink.primary)
                                Text(selectedVol.formattedCapacity)
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Ink.tertiary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(DS.Ink.tertiary)
                            }
                            .lineLimit(1)
                            .fixedSize()
                        }
                        .menuStyle(.button)
                        .buttonStyle(.ds(.secondary))
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .disabled(sonar.isScanning)
                    }

                    Button {
                        sonar.rescanCurrentVolume()
                    } label: {
                        Label(L10n.lang == .italian ? "Rianalizza" : "Rescan", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.ds(.secondary))
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(sonar.isScanning)
                }
            }
            .padding(.horizontal, DS.Space.gutter)
            .padding(.top, DS.Space.top)

            // 2. Contenuto
            if sonar.isScanning {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    Spacer()
                    DSBadge(text: L10n.lang == .italian ? "Mappatura del disco" : "Mapping the disk", icon: "dot.radiowaves.left.and.right", tint: BathysPalette.amber)
                    HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                        Text("\(sonar.scannedFilesCount)")
                            .font(DS.Font.bigNumber)
                            .contentTransition(.numericText())
                            .animation(DS.Motion.standard, value: sonar.scannedFilesCount)
                            .foregroundStyle(DS.Ink.primary)
                        Text(L10n.lang == .italian ? "elementi analizzati" : "items analysed")
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Ink.secondary)
                    }
                    Text(sonar.currentScanPath.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Ink.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 420, alignment: .leading)
                    Spacer()
                }
                .padding(.horizontal, DS.Space.gutter)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else if let current = sonar.currentNode {
                // Intestazione: nome cartella e dimensione
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                        Text(localizedFolderName(current))
                            .font(DS.Font.display)
                            .foregroundStyle(DS.Ink.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(current.formattedSize)
                            .font(DS.Font.display)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(DS.Ink.tertiary)
                            .fixedSize()
                        Spacer(minLength: 0)
                    }
                    Text(L10n.lang == .italian
                         ? "Clicca un settore o una cartella per esplorarla. Le cartelle di sistema sono protette."
                         : "Click a sector or folder to explore it. System folders are protected.")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Ink.secondary)
                }
                .padding(.horizontal, DS.Space.gutter)
                .padding(.top, DS.Space.xl)
                .padding(.bottom, DS.Space.m)

                // Symmetrical 2-Column Body: Sunburst Instrument Panel (Left) + Top Folders (Right)
                HStack(alignment: .center, spacing: 28) {
                    NauticalConsolePanel(size: 292) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.02, green: 0.05, blue: 0.10).opacity(0.98))
                                .frame(width: 252, height: 252)
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
                                    guard child.canBeTrashed else { return }
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
                .padding(.horizontal, DS.Space.gutter)
                .padding(.bottom, DS.Space.xl)
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
            HStack(spacing: DS.Space.s) {
                Image(systemName: "arrow.turn.left.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BathysPalette.amber)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(BathysPalette.amber.opacity(0.14)))

                Text(L10n.lang == .italian ? "Cartella superiore" : "Enclosing folder")
                    .font(DS.Font.bodyEmphasis)
                    .foregroundStyle(DS.Ink.primary)

                Spacer(minLength: DS.Space.xs)

                if let parentNode = sonar.navigationStack.dropLast().last {
                    Text(displayParentName(parentNode))
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Ink.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.horizontal, DS.Space.s)
            .frame(height: 40)
            .dsSurface(radius: DS.Radius.row - 2, isHovered: isHovered)
            .contentShape(Rectangle())
        }
        .buttonStyle(TactileCardButtonStyle())
        .keyboardShortcut(.upArrow, modifiers: .command)
        .onHover { hovering in withAnimation(DS.Motion.quick) { isHovered = hovering } }
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
        let chartColor = isSystem ? Color(red: 0.42, green: 0.48, blue: 0.56) : BathysPalette.chartColor(for: node.colorIndex)
        let share = Double(node.bytes) / Double(max(1, parentTotalBytes))

        HStack(spacing: DS.Space.s) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(chartColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: DS.Space.xs) {
                    Text(displayNodeTitle)
                        .font(DS.Font.bodyEmphasis)
                        .foregroundStyle(isSystem ? DS.Ink.secondary : DS.Ink.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if isSystem {
                        DSBadge(text: L10n.lang == .italian ? "Sistema" : "System", icon: "lock.fill", tint: Color(red: 0.60, green: 0.70, blue: 0.84))
                    } else if rule == .emptyContentsOnly {
                        DSBadge(text: L10n.lang == .italian ? "Svuota contenuto" : "Empty contents", tint: BathysPalette.teal)
                    }
                }
                DSProgressBar(value: max(share, 0.01), tint: chartColor.opacity(0.85), height: 3)
            }

            Spacer(minLength: DS.Space.xs)

            HStack(spacing: 6) {
                BathysRoundIconButton(
                    icon: "folder",
                    size: 26,
                    iconSize: 11,
                    tint: BathysPalette.sky,
                    helpText: L10n.lang == .italian ? "Mostra nel Finder" : "Reveal in Finder"
                ) {
                    NSWorkspace.shared.selectFile(node.path, inFileViewerRootedAtPath: "")
                }
                if node.canBeTrashed {
                    BathysRoundIconButton(
                        icon: rule == .emptyContentsOnly ? "sparkles" : "trash",
                        size: 26,
                        iconSize: 11,
                        tint: rule == .emptyContentsOnly ? BathysPalette.teal : BathysPalette.coral,
                        isDestructive: rule != .emptyContentsOnly,
                        helpText: rule == .emptyContentsOnly
                            ? (L10n.lang == .italian ? "Svuota il contenuto (la cartella resta)" : "Empty contents (folder is kept)")
                            : (L10n.lang == .italian ? "Sposta nel Cestino" : "Move to Trash")
                    ) {
                        onTrash()
                    }
                }
            }
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)

            VStack(alignment: .trailing, spacing: 2) {
                Text(node.bytes == 0 && isSystem ? "—" : node.formattedSize)
                    .font(DS.Font.value)
                    .foregroundStyle(DS.Ink.primary)
                Text(String(format: "%.0f%%", share * 100))
                    .font(DS.Font.caption.monospacedDigit())
                    .foregroundStyle(DS.Ink.tertiary)
            }
            .fixedSize()
            .frame(minWidth: 64, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isHovered ? DS.Ink.primary : DS.Ink.tertiary)
                .frame(width: 14)
                .opacity(node.isDirectory ? 1 : 0)
        }
        .padding(.horizontal, DS.Space.s)
        .frame(height: 50)
        .dsSurface(radius: DS.Radius.row - 2, isHovered: isHovered)
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
            // 1. Barra superiore: ricerca + scegli app
            WorkspaceTopBar(onBack: onBack) {
                HStack(spacing: DS.Space.xs) {
                    DSSearchField(
                        placeholder: L10n.lang == .italian ? "Cerca un'app" : "Search apps",
                        text: $uninstaller.searchQuery,
                        focus: $isSearchFocused,
                        width: 200
                    )
                    Button {
                        uninstaller.pickAppFromDisk()
                    } label: {
                        Label(L10n.lang == .italian ? "Scegli app…" : "Choose app…", systemImage: "plus")
                    }
                    .buttonStyle(.ds(.secondary))
                }
            }
            .padding(.horizontal, DS.Space.gutter)
            .padding(.top, DS.Space.top)
            .padding(.bottom, DS.Space.l)

            // 2. Elenco app + dettaglio
            HStack(alignment: .top, spacing: DS.Space.l) {
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 2) {
                            if uninstaller.isLoadingApps && uninstaller.apps.isEmpty {
                                ForEach(0..<8, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(DS.Ink.surface)
                                        .frame(height: 40)
                                }
                            } else if uninstaller.filteredApps.isEmpty {
                                Text(uninstaller.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? (L10n.lang == .italian ? "Nessuna app trovata nella cartella Applicazioni." : "No apps found in the Applications folder.")
                                     : (L10n.lang == .italian ? "Nessuna app corrisponde alla ricerca." : "No apps match your search."))
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Ink.tertiary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, DS.Space.xl)
                                    .frame(maxWidth: .infinity)
                            }
                            ForEach(uninstaller.filteredApps) { app in
                                UninstallerAppRow(
                                    app: app,
                                    isSelected: uninstaller.selectedApp?.id == app.id
                                ) {
                                    uninstaller.inspectApp(app)
                                }
                                .id(app.id)
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: uninstaller.selectedApp?.id) { _, newId in
                        if let newId {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                scrollProxy.scrollTo(newId, anchor: .center)
                            }
                        }
                    }
                }
                .frame(width: 236)
                .dsSurface(radius: DS.Radius.row + 2)

                if let app = uninstaller.selectedApp {
                    VStack(alignment: .leading, spacing: 0) {
                        // Intestazione app
                        HStack(alignment: .center, spacing: DS.Space.s) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: DS.Space.xs) {
                                    Text(app.name)
                                        .font(DS.Font.title)
                                        .foregroundStyle(DS.Ink.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    if app.isRunning {
                                        DSBadge(text: L10n.lang == .italian ? "Aperta" : "Running", icon: "circle.fill", tint: BathysPalette.amber)
                                            .help(L10n.lang == .italian ? "Verrà chiusa prima della rimozione" : "It will be quit before removal")
                                    }
                                }
                                let subfolder = app.subfolderName.map { " · \($0)" } ?? ""
                                Text("v\(app.version)\(subfolder) · " + (L10n.lang == .italian ? "\(uninstaller.residuals.count) elementi" : "\(uninstaller.residuals.count) items"))
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Ink.tertiary)
                                    .lineLimit(1)
                            }
                            .layoutPriority(1)

                            Spacer(minLength: DS.Space.s)

                            Text(ByteCountFormatter.string(fromByteCount: uninstaller.totalSelectedBytes, countStyle: .file))
                                .font(DS.Font.title.monospacedDigit())
                                .contentTransition(.numericText())
                                .animation(DS.Motion.standard, value: uninstaller.totalSelectedBytes)
                                .foregroundStyle(DS.Ink.primary)
                                .fixedSize()
                        }

                        if uninstaller.residuals.count > 1 {
                            DSSegmented(
                                options: [
                                    (value: false, label: L10n.lang == .italian ? "Disinstalla tutto" : "Uninstall all"),
                                    (value: true, label: L10n.lang == .italian ? "Solo reset dati" : "Reset data only")
                                ],
                                selection: Binding(
                                    get: { uninstaller.isResetOnlyMode },
                                    set: { uninstaller.setUninstallScope(resetOnly: $0) }
                                ),
                                tint: uninstaller.isResetOnlyMode ? BathysPalette.amber : BathysPalette.coral
                            )
                            .help(L10n.lang == .italian
                                  ? "Solo reset dati: l'app resta installata, vengono rimossi cache, preferenze e stati"
                                  : "Reset data only: the app stays installed; caches, preferences and states are removed")
                            .padding(.top, DS.Space.m)
                        }

                        // Elementi trovati
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 6) {
                                if uninstaller.isScanningResiduals {
                                    ForEach(0..<4, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: DS.Radius.row - 2, style: .continuous)
                                            .fill(DS.Ink.surface)
                                            .frame(height: 52)
                                    }
                                }
                                ForEach($uninstaller.residuals) { $item in
                                    ResidualItemRow(item: $item)
                                }
                            }
                            .padding(.top, DS.Space.m)
                            .padding(.bottom, DS.Space.l)
                        }
                        .mask(
                            VStack(spacing: 0) {
                                Rectangle()
                                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: DS.Space.xl)
                            }
                        )

                        HStack {
                            Spacer()
                            CircularActionOrbButton(
                                label: uninstaller.isUninstalling
                                    ? (L10n.lang == .italian ? "Attendi…" : "Working…")
                                    : (uninstaller.isResetOnlyMode
                                        ? (L10n.lang == .italian ? "Reset dati" : "Reset data")
                                        : (L10n.lang == .italian ? "Disinstalla" : "Uninstall")),
                                iconName: uninstaller.isResetOnlyMode ? "arrow.counterclockwise" : "trash",
                                tint: uninstaller.isResetOnlyMode ? BathysPalette.amber : BathysPalette.coral,
                                isDisabled: uninstaller.totalSelectedBytes == 0 || uninstaller.isUninstalling,
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
                        .padding(.top, DS.Space.xs)
                    }
                } else {
                    // Stato vuoto che insegna cosa fare
                    VStack(spacing: DS.Space.m) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(isDropTargeted ? BathysPalette.coral : DS.Ink.tertiary)
                        VStack(spacing: DS.Space.xxs) {
                            Text(L10n.lang == .italian ? "Trascina qui un'app" : "Drop an app here")
                                .font(DS.Font.headline)
                                .foregroundStyle(DS.Ink.primary)
                            Text(L10n.lang == .italian
                                 ? "oppure sceglila dall'elenco: Bathys troverà anche i file che lascia sparsi nel Mac."
                                 : "or pick it from the list: Bathys also finds the files it leaves around your Mac.")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Ink.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button {
                            uninstaller.pickAppFromDisk()
                        } label: {
                            Text(L10n.lang == .italian ? "Scegli app…" : "Choose app…")
                        }
                        .buttonStyle(.ds(.primary, tint: BathysPalette.coral))
                    }
                    .padding(DS.Space.xxl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .strokeBorder(isDropTargeted ? BathysPalette.coral : DS.Ink.hairlineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
                }
            }
            .padding(.horizontal, DS.Space.gutter)
            .padding(.bottom, DS.Space.xl)
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
            // Da tastiera chiediamo SEMPRE conferma: un tasto premuto per errore non deve mai disinstallare un'app
            if uninstaller.selectedApp != nil && uninstaller.totalSelectedBytes > 0 && !uninstaller.isUninstalling {
                uninstaller.showUninstallConfirmation = true
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
                        // Da tastiera chiediamo SEMPRE conferma (mai disinstallazione immediata)
                        if uninstaller.selectedApp != nil && uninstaller.totalSelectedBytes > 0
                            && !uninstaller.isUninstalling && !uninstaller.showUninstallConfirmation {
                            uninstaller.showUninstallConfirmation = true
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

private struct UninstallerAppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xs) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(isSelected ? DS.Font.bodyEmphasis : DS.Font.body)
                        .foregroundStyle(isSelected ? DS.Ink.primary : DS.Ink.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let sub = app.subfolderName {
                        Text(sub)
                            .font(.system(size: 10.5))
                            .foregroundStyle(DS.Ink.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                if app.isRunning {
                    Circle()
                        .fill(BathysPalette.amber)
                        .frame(width: 6, height: 6)
                        .help(L10n.lang == .italian ? "App aperta" : "App is running")
                }
            }
            .padding(.horizontal, DS.Space.xs)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? BathysPalette.coral.opacity(0.16) : (isHovered ? DS.Ink.surfaceHover : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(app.name)
        .onHover { hovering in withAnimation(DS.Motion.quick) { isHovered = hovering } }
    }
}

struct ResidualItemRow: View {
    @Binding var item: AppResidualItem
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Space.s) {
            BathysRoundCheckButton(isSelected: $item.isSelected, tint: BathysPalette.coral)

            Image(systemName: kindSymbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(kindTint)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(kindTint.opacity(0.14)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: DS.Space.xs) {
                    Text(item.name)
                        .font(DS.Font.bodyEmphasis)
                        .foregroundStyle(item.isSelected ? DS.Ink.primary : DS.Ink.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(kindLabel)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Ink.tertiary)
                        .lineLimit(1)
                        .fixedSize()
                    if !item.isStrongMatch {
                        DSBadge(text: L10n.lang == .italian ? "Da verificare" : "Review", tint: BathysPalette.amber)
                            .help(L10n.lang == .italian
                                  ? "Il nome somiglia a quello dell'app ma non è certo che le appartenga: non è selezionato di default"
                                  : "The name resembles the app's but ownership isn't certain: not selected by default")
                    }
                }
                Text(item.displayPath)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Ink.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(item.path)
            }

            Spacer(minLength: DS.Space.xs)

            BathysRoundIconButton(
                icon: "folder",
                size: 26,
                iconSize: 11,
                tint: BathysPalette.sky,
                helpText: L10n.lang == .italian ? "Mostra nel Finder" : "Reveal in Finder"
            ) {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            }
            .opacity(isHovered ? 1 : 0)

            Text(item.formattedSize)
                .font(DS.Font.value)
                .foregroundStyle(item.isSelected ? DS.Ink.primary : DS.Ink.tertiary)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.leading, DS.Space.xxs)
        .padding(.trailing, DS.Space.s)
        .frame(minHeight: 52)
        .dsSurface(radius: DS.Radius.row - 2, isHovered: isHovered)
        .onHover { hovering in
            withAnimation(DS.Motion.quick) { isHovered = hovering }
        }
    }

    private var it: Bool { L10n.lang == .italian }

    private var kindLabel: String {
        switch item.kind {
        case .appBundle: return it ? "Applicazione" : "Application"
        case .appSupport: return it ? "Supporto" : "Support files"
        case .container: return it ? "Contenitore" : "Container"
        case .cache: return "Cache"
        case .preferences: return it ? "Preferenze" : "Preferences"
        case .launchAgent: return it ? "Avvio automatico" : "Login item"
        case .stateAndLogs: return it ? "Stato e log" : "State & logs"
        case .receipt: return it ? "Ricevuta" : "Receipt"
        }
    }

    private var kindSymbol: String {
        switch item.kind {
        case .appBundle: return "app.dashed"
        case .appSupport: return "folder"
        case .container: return "shippingbox"
        case .cache: return "archivebox"
        case .preferences: return "slider.horizontal.3"
        case .launchAgent: return "power"
        case .stateAndLogs: return "doc.text"
        case .receipt: return "doc.badge.ellipsis"
        }
    }

    private var kindTint: Color {
        switch item.kind {
        case .appBundle: return BathysPalette.coral
        case .appSupport, .container: return BathysPalette.sky
        case .cache: return BathysPalette.teal
        case .preferences: return BathysPalette.steel
        case .launchAgent: return BathysPalette.amber
        case .stateAndLogs, .receipt: return Color(red: 0.62, green: 0.70, blue: 0.80)
        }
    }
}

// MARK: - MODULE 4: PRESTAZIONI (Separated Tabs for Breathability — Zero Crowding)

struct OptimizationWorkspace: View {
    @Bindable var optimizer: OptimizerEngine
    let onBack: () -> Void
    @State private var selectedSection: Int = 0 // 0 = Manutenzione, 1 = Elementi di Avvio
    @State private var agentPendingRemoval: LaunchAgentItem?
    @State private var agentRemovalFailed = false

    private var it: Bool { L10n.lang == .italian }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Barra superiore con le due sezioni
            WorkspaceTopBar(onBack: onBack) {
                DSSegmented(
                    options: [
                        (value: 0, label: it ? "Manutenzione" : "Maintenance"),
                        (value: 1, label: (it ? "Elementi di avvio" : "Startup items") + " · \(optimizer.launchAgents.count)")
                    ],
                    selection: $selectedSection,
                    tint: BathysPalette.emerald
                )
            }
            .padding(.horizontal, DS.Space.gutter)
            .padding(.top, DS.Space.top)

            // 2. Titolo e stato del Mac
            VStack(alignment: .leading, spacing: DS.Space.m) {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text(it ? "Prestazioni" : "Performance")
                        .font(DS.Font.display)
                        .foregroundStyle(DS.Ink.primary)
                    Text(selectedSection == 0
                         ? (it ? "Piccole manutenzioni sicure che macOS non fa da solo." : "Small, safe maintenance tasks macOS doesn't do on its own.")
                         : (it ? "Programmi che partono da soli. Quelli orfani puntano a file che non esistono più." : "Programs that launch on their own. Orphaned ones point to files that no longer exist."))
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: DS.Space.l) {
                    DSMeter(
                        icon: "memorychip",
                        label: "RAM",
                        value: String(format: "%.0f%%", optimizer.ramUsedFraction * 100) + " · " + ByteCountFormatter.string(fromByteCount: Int64(optimizer.ramUsedBytes), countStyle: .memory),
                        fraction: optimizer.ramUsedFraction,
                        tint: optimizer.ramUsedFraction > 0.8 ? BathysPalette.amber : BathysPalette.emerald
                    )
                    Rectangle().fill(DS.Ink.hairline).frame(width: 1, height: 20)
                    DSMeter(
                        icon: "internaldrive",
                        label: it ? "Disco" : "Disk",
                        value: ByteCountFormatter.string(fromByteCount: optimizer.diskFreeBytes, countStyle: .file) + (it ? " liberi" : " free"),
                        fraction: optimizer.diskUsedFraction,
                        tint: optimizer.diskUsedFraction > 0.9 ? BathysPalette.amber : BathysPalette.sky
                    )
                    Rectangle().fill(DS.Ink.hairline).frame(width: 1, height: 20)
                    HStack(spacing: DS.Space.xs) {
                        Image(systemName: "power")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(optimizer.orphanedAgentsCount > 0 ? BathysPalette.coral : BathysPalette.emerald)
                        Text(optimizer.orphanedAgentsCount > 0
                             ? (it ? "\(optimizer.orphanedAgentsCount) elementi orfani" : "\(optimizer.orphanedAgentsCount) orphaned items")
                             : (it ? "Avvio in ordine" : "Startup is clean"))
                            .font(DS.Font.captionEmphasis)
                            .foregroundStyle(DS.Ink.primary)
                            .fixedSize()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DS.Space.m)
                .frame(height: 48)
                .dsSurface(radius: DS.Radius.row)
            }
            .padding(.horizontal, DS.Space.gutter)
            .padding(.top, DS.Space.xl)
            .padding(.bottom, DS.Space.m)

            // 3. Sezione attiva
            ZStack {
                if selectedSection == 0 {
                    maintenanceSectionBody
                        .transition(.opacity)
                } else {
                    startupAgentsSectionBody
                        .transition(.opacity)
                }
            }
            .animation(DS.Motion.standard, value: selectedSection)
        }
        .onAppear {
            optimizer.refreshTelemetry()
            if optimizer.launchAgents.isEmpty {
                optimizer.scanLaunchAgents()
            }
        }
    }

    private var maintenanceSectionBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DS.Space.xs) {
                    ForEach($optimizer.tasks) { $task in
                        OptimizerTaskRow(task: $task)
                    }
                }
                .padding(.horizontal, DS.Space.gutter)
                .padding(.bottom, DS.Space.l)
            }
            .mask(
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: DS.Space.xl)
                }
            )

            HStack {
                Spacer()
                CircularActionOrbButton(
                    label: optimizer.isRunningTasks ? (it ? "Attendi…" : "Working…") : (it ? "Ottimizza" : "Optimize"),
                    iconName: "bolt.fill",
                    tint: BathysPalette.emerald,
                    isDisabled: optimizer.isRunningTasks || !optimizer.tasks.contains(where: \.isSelected)
                ) {
                    optimizer.runSelectedOptimizations()
                }
                Spacer()
            }
            .padding(.top, DS.Space.xs)
            .padding(.bottom, DS.Space.xl)
        }
    }

    private var startupAgentsSectionBody: some View {
        agentsList
            .confirmationDialog(
                it ? "Rimuovere questo elemento di avvio?" : "Remove this startup item?",
                isPresented: Binding(
                    get: { agentPendingRemoval != nil },
                    set: { if !$0 { agentPendingRemoval = nil } }
                ),
                titleVisibility: .visible,
                presenting: agentPendingRemoval
            ) { agent in
                Button(it ? "Sposta nel Cestino" : "Move to Trash", role: .destructive) {
                    agentRemovalFailed = !optimizer.removeLaunchAgent(agent)
                    agentPendingRemoval = nil
                }
                Button(it ? "Annulla" : "Cancel", role: .cancel) {
                    agentPendingRemoval = nil
                }
            } message: { agent in
                Text(it
                     ? "\(agent.label) verrà disattivato e il suo file \(agent.displayPath) spostato nel Cestino."
                     : "\(agent.label) will be unloaded and its file \(agent.displayPath) moved to the Trash.")
            }
            .alert(
                it ? "Impossibile rimuovere l'elemento" : "Could not remove the item",
                isPresented: $agentRemovalFailed
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(it
                     ? "Il file è protetto o non hai i permessi necessari. Puoi rimuoverlo manualmente dal Finder."
                     : "The file is protected or you lack the required permissions. You can remove it manually in Finder.")
            }
    }

    private var agentsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DS.Space.xs) {
                if optimizer.launchAgents.isEmpty {
                    VStack(spacing: DS.Space.xs) {
                        Image(systemName: optimizer.isScanningAgents ? "hourglass" : "checkmark.circle")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(BathysPalette.emerald)
                        Text(optimizer.isScanningAgents
                             ? (it ? "Ricerca degli elementi di avvio…" : "Looking for startup items…")
                             : (it ? "Nessun elemento di avvio di terze parti." : "No third-party startup items."))
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Ink.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, DS.Space.xxxl)
                }
                ForEach(optimizer.launchAgents) { agent in
                    LaunchAgentRow(agent: agent) {
                        // Rimuovere un elemento di avvio è un'azione importante: chiediamo sempre conferma
                        agentPendingRemoval = agent
                    }
                }
            }
            .padding(.horizontal, DS.Space.gutter)
            .padding(.bottom, DS.Space.xxl)
        }
    }
}

private struct OptimizerTaskRow: View {
    @Binding var task: OptimizationTaskItem
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Space.s) {
            BathysRoundCheckButton(isSelected: $task.isSelected, tint: BathysPalette.emerald)
            Image(systemName: task.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BathysPalette.emerald)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(BathysPalette.emerald.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(DS.Font.headline)
                    .foregroundStyle(task.isSelected ? DS.Ink.primary : DS.Ink.secondary)
                    .lineLimit(1)
                Text(task.subtitle)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Ink.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: DS.Space.s)
            status
        }
        .padding(.leading, DS.Space.xs)
        .padding(.trailing, DS.Space.m)
        .padding(.vertical, DS.Space.s)
        .dsSurface(radius: DS.Radius.row, isHovered: isHovered)
        .onHover { hovering in withAnimation(DS.Motion.quick) { isHovered = hovering } }
    }

    @ViewBuilder
    private var status: some View {
        switch task.status {
        case .ready:
            EmptyView()
        case .running:
            ProgressView().controlSize(.small).tint(BathysPalette.emerald)
        case .completed(let msg):
            DSBadge(text: msg, icon: "checkmark", tint: BathysPalette.emerald)
        case .failed(let err):
            DSBadge(text: err, icon: "exclamationmark.triangle.fill", tint: BathysPalette.coral)
        }
    }
}

private struct LaunchAgentRow: View {
    let agent: LaunchAgentItem
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: agent.isOrphaned ? "exclamationmark.triangle" : "power")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(agent.isOrphaned ? BathysPalette.coral : BathysPalette.emerald)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill((agent.isOrphaned ? BathysPalette.coral : BathysPalette.emerald).opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: DS.Space.xs) {
                    Text(agent.label)
                        .font(DS.Font.bodyEmphasis)
                        .foregroundStyle(DS.Ink.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if agent.isOrphaned {
                        DSBadge(text: L10n.lang == .italian ? "Orfano" : "Orphaned", tint: BathysPalette.coral)
                    }
                    if !agent.isUserAgent {
                        DSBadge(text: L10n.lang == .italian ? "Tutti gli utenti" : "All users", tint: Color(red: 0.62, green: 0.70, blue: 0.80))
                    }
                }
                Text(agent.executablePath)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Ink.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(agent.executablePath)
            }
            Spacer(minLength: DS.Space.s)
            HStack(spacing: 6) {
                BathysRoundIconButton(
                    icon: "folder",
                    size: 26,
                    iconSize: 11,
                    tint: BathysPalette.sky,
                    helpText: L10n.lang == .italian ? "Mostra nel Finder" : "Reveal in Finder"
                ) {
                    NSWorkspace.shared.selectFile(agent.plistPath, inFileViewerRootedAtPath: "")
                }
                if agent.isUserAgent {
                    BathysRoundIconButton(
                        icon: "trash",
                        size: 26,
                        iconSize: 11,
                        tint: BathysPalette.coral,
                        isDestructive: true,
                        helpText: L10n.lang == .italian ? "Disattiva e sposta nel Cestino" : "Unload and move to Trash",
                        action: onRemove
                    )
                }
            }
            .opacity(isHovered ? 1 : 0.0)
        }
        .padding(.horizontal, DS.Space.s)
        .frame(minHeight: 52)
        .dsSurface(radius: DS.Radius.row - 2, isHovered: isHovered)
        .onHover { hovering in withAnimation(DS.Motion.quick) { isHovered = hovering } }
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

    private var it: Bool { L10n.lang == .italian }
    private var safetyTint: Color { includesPermanentTrash ? BathysPalette.amber : BathysPalette.emerald }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            // Titolo e spiegazione
            HStack(alignment: .top, spacing: DS.Space.s) {
                Image(systemName: includesPermanentTrash ? "exclamationmark.triangle.fill" : "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(includesPermanentTrash ? BathysPalette.amber : BathysPalette.coral)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill((includesPermanentTrash ? BathysPalette.amber : BathysPalette.coral).opacity(0.15)))
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text(title)
                        .font(DS.Font.title)
                        .foregroundStyle(DS.Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Ink.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Cosa verrà rimosso
            if !previewItems.isEmpty {
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(Array(previewItems.enumerated()), id: \.element.id) { index, item in
                                if index > 0 { Rectangle().fill(DS.Ink.hairline).frame(height: 1) }
                                HStack(spacing: DS.Space.s) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(DS.Font.bodyEmphasis)
                                            .foregroundStyle(DS.Ink.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        // Le descrizioni lunghe restano nel suggerimento: l'elenco resta compatto e leggibile
                                        if item.detail.count <= 32 {
                                            Text(item.detail)
                                                .font(DS.Font.caption)
                                                .foregroundStyle(DS.Ink.tertiary)
                                        }
                                    }
                                    .layoutPriority(1)
                                    .help(item.detail)
                                    Spacer(minLength: DS.Space.s)
                                    if let p = item.path, !p.isEmpty {
                                        BathysRoundIconButton(
                                            icon: "folder",
                                            size: 24,
                                            iconSize: 10.5,
                                            tint: BathysPalette.sky,
                                            helpText: it ? "Mostra nel Finder" : "Reveal in Finder"
                                        ) {
                                            NSWorkspace.shared.selectFile(p, inFileViewerRootedAtPath: "")
                                        }
                                    }
                                    Text(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))
                                        .font(DS.Font.value)
                                        .foregroundStyle(DS.Ink.secondary)
                                        .frame(minWidth: 64, alignment: .trailing)
                                }
                                .padding(.horizontal, DS.Space.s)
                                .padding(.vertical, 9)
                            }
                        }
                    }
                    .frame(maxHeight: previewItems.count > 6 ? 320 : nil)
                    .mask(
                        VStack(spacing: 0) {
                            Rectangle()
                            LinearGradient(colors: [.black, previewItems.count > 6 ? .clear : .black], startPoint: .top, endPoint: .bottom)
                                .frame(height: DS.Space.l)
                        }
                    )

                    Rectangle().fill(DS.Ink.hairlineStrong).frame(height: 1)

                    HStack {
                        Text(it ? "Totale" : "Total")
                            .font(DS.Font.bodyEmphasis)
                            .foregroundStyle(DS.Ink.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                            .font(DS.Font.title.monospacedDigit())
                            .foregroundStyle(DS.Ink.primary)
                    }
                    .padding(.horizontal, DS.Space.s)
                    .padding(.vertical, DS.Space.s)
                }
                .dsSurface(radius: DS.Radius.row)
            } else {
                HStack {
                    Text(it ? "Totale" : "Total")
                        .font(DS.Font.bodyEmphasis)
                        .foregroundStyle(DS.Ink.secondary)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                        .font(DS.Font.title.monospacedDigit())
                        .foregroundStyle(DS.Ink.primary)
                }
                .padding(DS.Space.s)
                .dsSurface(radius: DS.Radius.row)
            }

            // Garanzia di sicurezza
            HStack(alignment: .top, spacing: DS.Space.xs) {
                Image(systemName: includesPermanentTrash ? "exclamationmark.shield.fill" : "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(safetyTint)
                Text(includesPermanentTrash
                     ? (it ? "Il contenuto del Cestino verrà eliminato definitivamente e non potrà essere recuperato. Tutto il resto va nel Cestino."
                           : "The Trash contents will be deleted permanently and cannot be recovered. Everything else goes to the Trash.")
                     : (it ? "Tutto finisce nel Cestino: puoi ripristinare qualsiasi file dal Finder."
                           : "Everything goes to the Trash: you can restore any file from Finder."))
                    .font(DS.Font.caption)
                    .foregroundStyle(safetyTint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Azioni
            HStack(spacing: DS.Space.xs) {
                Spacer()
                Button(it ? "Annulla" : "Cancel", action: onCancel)
                    .buttonStyle(.ds(.secondary, size: .large))
                    .keyboardShortcut(.cancelAction)
                Button(confirmLabel, action: onConfirm)
                    .buttonStyle(.ds(.primary, size: .large, tint: includesPermanentTrash ? BathysPalette.amber : BathysPalette.coral))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DS.Space.xxl)
        .frame(width: 480)
        .background(DS.Ink.groundDeep)
        .background(SheetWindowCustomizer())
        .preferredColorScheme(.dark)
    }
}
