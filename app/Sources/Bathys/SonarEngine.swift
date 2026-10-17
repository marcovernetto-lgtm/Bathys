import Foundation
import Observation
import AppKit

enum NodeSafetyRule: Sendable, Equatable {
    case normal                  // Elemento ordinario: può essere spostato nel Cestino
    case emptyContentsOnly       // Contenitore strutturale (C, T, Caches, Logs): svuota solo il contenuto interno preservando la cartella
    case systemProtected         // Cartella di sistema protetta (0, X, Keychains, CloudKit): non eliminabile
}

struct DiskNode: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let targetPaths: [String]
    let bytes: Int64
    let isDirectory: Bool
    let colorIndex: Int
    var children: [DiskNode]

    init(
        name: String,
        path: String,
        targetPaths: [String]? = nil,
        bytes: Int64,
        isDirectory: Bool,
        colorIndex: Int,
        children: [DiskNode]
    ) {
        self.name = name
        self.path = path
        self.targetPaths = targetPaths ?? [path]
        self.bytes = bytes
        self.isDirectory = isDirectory
        self.colorIndex = colorIndex
        self.children = children
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.replacingOccurrences(of: home, with: "~")
    }

    /// Rileva se il nodo è un componente o cartella vitale del sistema operativo macOS che non deve MAI essere toccato
    var isSystemFile: Bool {
        let p = (path as NSString).standardizingPath

        // 0. Supporto Sandbox di test isolata
        if let sandbox = MacSafetyIntelligence.sandboxRootURL {
            let sbPath = (sandbox.path as NSString).standardizingPath
            if p == sbPath || p.hasPrefix(sbPath + "/") {
                if p.contains("/var/folders/") {
                    let last = URL(fileURLWithPath: p).lastPathComponent
                    if last == "0" || last == "X" { return true }
                    return false
                }
                let criticalNames: Set<String> = [
                    "Keychains", "CloudKit", "com.apple.bird", "Accounts", "IdentityServices", "System"
                ]
                return criticalNames.contains(name)
            }
        }

        // 1. File utente e download (~/ o /Users/...): NON sono file di sistema (salvo portachiavi di sistema)
        if p.hasPrefix("/Users") {
            let criticalUserSystemItems: Set<String> = [
                "Keychains", "CloudKit", "com.apple.bird", "Accounts", "IdentityServices",
                "com.apple.LaunchServices", "com.apple.iconservices", "com.apple.iconservices.store",
                "FamilyCircle", "PassKit"
            ]
            return criticalUserSystemItems.contains(name)
        }

        // 2. Volumi esterni: non sono file di sistema macOS
        if p.hasPrefix("/Volumes") { return false }

        // 3. Applicazioni: le app scaricate e di terze parti NON sono file di sistema
        if p.hasPrefix("/Applications") {
            if p.hasPrefix("/Applications/Safari.app") || p.hasPrefix("/Applications/Utilities") {
                return true
            }
            return false
        }

        // 4. Cartelle Darwin in /var/folders: C e T sono cache e temporanei creati dalle app (NON sistema puro)
        if p.contains("/var/folders/") {
            let last = URL(fileURLWithPath: p).lastPathComponent
            if last == "C" || last == "T" { return false }
            if last == "0" || last == "X" { return true }
        }

        // 5. Cartelle radice e protette del sistema operativo macOS (SIP / Kernel / Frameworks)
        if p == "/System" || p.hasPrefix("/System/") { return true }
        if p == "/Library" { return true }
        if p.hasPrefix("/Library/") {
            // Sottocartelle di terze parti dentro /Library (Application Support, Caches, Logs, Audio Plugins)
            if p.hasPrefix("/Library/Application Support") {
                let sub = p.replacingOccurrences(of: "/Library/Application Support", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if !sub.isEmpty {
                    let firstComponent = sub.split(separator: "/").first.map(String.init) ?? ""
                    let appleNativeAppSupport: Set<String> = ["Apple", "CrashReporter", "com.apple.TCC"]
                    return appleNativeAppSupport.contains(firstComponent)
                }
                return false
            }
            if p.hasPrefix("/Library/Caches") || p.hasPrefix("/Library/Logs") || p.hasPrefix("/Library/Audio/Plug-Ins") {
                return false
            }
            return true
        }
        if p == "/usr" || p.hasPrefix("/usr/") { return true }
        if p == "/bin" || p.hasPrefix("/bin/") { return true }
        if p == "/sbin" || p.hasPrefix("/sbin/") { return true }
        if p == "/private" || p.hasPrefix("/private/") { return true }
        if p == "/" { return true }

        return false
    }

    /// Determina la regola di sicurezza: i file di sistema sono rigidamente protetti da qualsiasi eliminazione
    var safetyRule: NodeSafetyRule {
        if isSystemFile {
            return .systemProtected
        }
        let inVarFolders = path.contains("/var/folders/")
        if inVarFolders && (name == "C" || name == "T") {
            return .emptyContentsOnly
        }
        let containerSuffixes = [
            "/Library/Caches",
            "/Library/Logs",
            "/Library/Saved Application State",
            "/Library/Logs/DiagnosticReports"
        ]
        if containerSuffixes.contains(where: { path.hasSuffix($0) }) {
            return .emptyContentsOnly
        }
        return .normal
    }

    var safetyDescription: String? {
        switch safetyRule {
        case .systemProtected:
            return "Cartella di sistema protetta da macOS (non eliminabile)"
        case .emptyContentsOnly:
            return "Contenitore strutturale macOS • Svuota il contenuto preservando la cartella"
        case .normal:
            return nil
        }
    }
}

struct SunburstSegment: Identifiable {
    let id: UUID
    let node: DiskNode
    let ring: Int              // 0 = inner, 1 = middle, 2 = outer
    let startAngle: Double     // radians
    let endAngle: Double       // radians
    let colorIndex: Int
    let fractionOfRoot: Double
}

public struct DiskVolume: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let isInternal: Bool
    public let totalBytes: Int64
    public let availableBytes: Int64

    public var formattedCapacity: String {
        let totalStr = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let availStr = ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)
        return "\(availStr) liberi su \(totalStr)"
    }
}

/// Motore Sonar Abissale: Analizzatore gerarchico dello spazio disco e generatore radiale Sunburst Bathys.
@MainActor @Observable
final class SonarEngine {
    var availableVolumes: [DiskVolume] = []
    var selectedVolumeId: String = "/"

    var selectedVolume: DiskVolume? {
        availableVolumes.first(where: { $0.id == selectedVolumeId })
            ?? availableVolumes.first
    }

    var isScanning = false
    var scannedFilesCount = 0
    var currentScanPath = ""
    var rootNode: DiskNode?
    var navigationStack: [DiskNode] = []
    var hoveredNode: DiskNode?
    var nodePendingTrash: DiskNode?

    /// Nodi scoperti in tempo reale durante la scansione per popolare i blip del radar Sonar
    var liveRadarBlips: [(name: String, bytes: Int64, angle: Double, distance: Double)] = []

    var currentNode: DiskNode? {
        navigationStack.last ?? rootNode
    }

    var activeTargetURL: URL {
        selectedVolume?.url ?? URL(fileURLWithPath: "/")
    }

    init() {
        refreshVolumes()
    }

    func refreshVolumes() {
        availableVolumes = SonarEngine.discoverVolumes()
        if !availableVolumes.contains(where: { $0.id == selectedVolumeId }) {
            selectedVolumeId = availableVolumes.first?.id ?? "/"
        }
    }

    func selectVolume(_ volume: DiskVolume) {
        guard !isScanning else { return }
        selectedVolumeId = volume.id
        scan(url: volume.url)
    }

    func rescanCurrentVolume() {
        guard !isScanning else { return }
        scan(url: activeTargetURL)
    }

    func scan(url: URL? = nil) {
        guard !isScanning else { return }
        let target = url ?? activeTargetURL
        isScanning = true
        scannedFilesCount = 0
        currentScanPath = target.path
        hoveredNode = nil
        liveRadarBlips = []
        let thresholdBytes = Int64(max(1, AppSettings.shared.sonarThresholdMB)) * 1024 * 1024

        Task {
            let tree = await SonarEngine.buildTree(
                at: target,
                maxDepth: 3,
                onProgress: { path, count in
                    Task { @MainActor in
                        self.currentScanPath = path
                        self.scannedFilesCount += count
                    }
                },
                onChildCompleted: { name, bytes, idx in
                    Task { @MainActor in
                        guard bytes >= thresholdBytes else { return }
                        let angle = Double(idx * 137) * (.pi / 180.0)
                        let dist = min(0.88, max(0.18, Double(( idx % 5 ) + 1) * 0.16))
                        self.liveRadarBlips.append((name: name, bytes: bytes, angle: angle, distance: dist))
                        if self.liveRadarBlips.count > 18 {
                            self.liveRadarBlips.removeFirst()
                        }
                    }
                }
            )

            self.rootNode = tree
            self.navigationStack = [tree]
            self.updateBlipsFromCurrentNode()
            self.currentScanPath = ""
            self.isScanning = false
            SoundManager.shared.playChime()
        }
    }

    func drillDown(into node: DiskNode) {
        guard node.isDirectory else { return }

        // Se la cartella ha già i figli calcolati, naviga all'istante
        if !node.children.isEmpty {
            navigationStack.append(node)
            hoveredNode = nil
            updateBlipsFromCurrentNode()
            return
        }

        // Se la cartella non ha figli (fine livello di profondità iniziale),
        // esegue un'espansione al volo rapida per esplorare in profondità qualsiasi cartella!
        guard !isScanning else { return }
        isScanning = true
        currentScanPath = node.path

        Task {
            let expanded = await SonarEngine.buildTree(
                at: URL(fileURLWithPath: node.path),
                maxDepth: 2,
                onProgress: { path, count in
                    Task { @MainActor in
                        self.currentScanPath = path
                        self.scannedFilesCount += count
                    }
                },
                onChildCompleted: { _, _, _ in }
            )

            if let lastIdx = self.navigationStack.indices.last {
                var current = self.navigationStack[lastIdx]
                if let childIdx = current.children.firstIndex(where: { $0.id == node.id }) {
                    current.children[childIdx] = expanded
                    self.navigationStack[lastIdx] = current
                }
            }

            self.navigationStack.append(expanded)
            self.hoveredNode = nil
            self.updateBlipsFromCurrentNode()
            self.currentScanPath = ""
            self.isScanning = false
        }
    }

    func navigateUp() {
        guard navigationStack.count > 1 else { return }
        navigationStack.removeLast()
        hoveredNode = nil
        updateBlipsFromCurrentNode()
    }

    func navigateToBreadcrumb(at index: Int) {
        guard index >= 0 && index < navigationStack.count else { return }
        navigationStack = Array(navigationStack.prefix(index + 1))
        hoveredNode = nil
        updateBlipsFromCurrentNode()
    }

    @discardableResult
    private func trashURL(_ url: URL) -> Bool {
        if let sandbox = MacSafetyIntelligence.sandboxRootURL {
            let sbPath = (sandbox.path as NSString).standardizingPath
            let targetPath = (url.path as NSString).standardizingPath
            guard targetPath.hasPrefix(sbPath + "/") else { return false }
            return (try? FileManager.default.removeItem(at: url)) != nil
        }

        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            let sema = DispatchSemaphore(value: 0)
            var recycled = false
            NSWorkspace.shared.recycle([url]) { dict, err in
                if err == nil && !dict.isEmpty {
                    recycled = true
                }
                sema.signal()
            }
            _ = sema.wait(timeout: .now() + 2.0)
            if recycled || !FileManager.default.fileExists(atPath: url.path) {
                return true
            }
            NSLog("[Bathys Sonar] Errore spostamento nel cestino per \(url.path): \(error.localizedDescription)")
            return false
        }
    }

    /// Sposta un nodo nel Cestino, oppure — se è un contenitore strutturale come C, T, Caches o Logs —
    /// svuota in sicurezza solo il suo contenuto interno preservando la cartella padre!
    func moveNodeToTrash(_ node: DiskNode) {
        guard !node.isSystemFile, node.safetyRule != .systemProtected else {
            NSLog("[Bathys Sonar] Tentativo di eliminazione bloccato: \(node.name) è un file/cartella vitale di sistema macOS.")
            nodePendingTrash = nil
            return
        }

        let fm = FileManager.default
        nodePendingTrash = nil

        switch node.safetyRule {
        case .systemProtected:
            return

        case .emptyContentsOnly:
            let containerURL = URL(fileURLWithPath: node.path)
            let isDarwinTemp = node.name == "T" && node.path.contains("/var/folders/")
            guard let children = try? fm.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
                return
            }
            for childURL in children {
                if MacSafetyIntelligence.shouldSkipItem(at: childURL, insideDarwinTemp: isDarwinTemp) {
                    continue
                }
                guard !MacSafetyIntelligence.isForbiddenToDelete(path: childURL.path) else { continue }
                trashURL(childURL)
            }
            // Aggiorna il nodo contenitore svuotato (resta visibile ma svuotato)
            if var current = currentNode {
                if let idx = current.children.firstIndex(where: { $0.id == node.id }) {
                    current.children[idx] = DiskNode(
                        name: node.name,
                        path: node.path,
                        bytes: 0,
                        isDirectory: true,
                        colorIndex: node.colorIndex,
                        children: []
                    )
                    current.children.removeAll { $0.bytes == 0 }
                }
                let newBytes = current.children.reduce(0) { $0 + $1.bytes }
                let updated = DiskNode(
                    name: current.name,
                    path: current.path,
                    bytes: newBytes,
                    isDirectory: current.isDirectory,
                    colorIndex: current.colorIndex,
                    children: current.children
                )
                navigationStack[navigationStack.count - 1] = updated
                if navigationStack.count == 1 {
                    rootNode = updated
                }
                updateBlipsFromCurrentNode()
            }

        case .normal:
            var anyTrashed = false
            for targetPath in node.targetPaths {
                guard !MacSafetyIntelligence.isForbiddenToDelete(path: targetPath, allowUserContent: true) else {
                    NSLog("[Bathys Sonar] Percorso protetto da MacSafetyIntelligence: \(targetPath)")
                    continue
                }
                let url = URL(fileURLWithPath: targetPath)
                if trashURL(url) {
                    anyTrashed = true
                }
            }
            guard anyTrashed else {
                NSLog("[Bathys Sonar] Impossibile cestinare nodo: \(node.name) (\(node.path))")
                return
            }

            if var current = currentNode {
                current.children.removeAll { $0.id == node.id }
                let newBytes = current.children.reduce(0) { $0 + $1.bytes }
                let updated = DiskNode(
                    name: current.name,
                    path: current.path,
                    bytes: newBytes,
                    isDirectory: current.isDirectory,
                    colorIndex: current.colorIndex,
                    children: current.children
                )
                navigationStack[navigationStack.count - 1] = updated

                // Propaga il ricalcolo delle dimensioni ai genitori nello stack di navigazione
                if navigationStack.count > 1 {
                    for i in stride(from: navigationStack.count - 2, through: 0, by: -1) {
                        var parent = navigationStack[i]
                        let childPath = navigationStack[i + 1].path
                        if let childIdx = parent.children.firstIndex(where: { $0.path == childPath }) {
                            parent.children[childIdx] = navigationStack[i + 1]
                        }
                        let parentBytes = parent.children.reduce(0) { $0 + $1.bytes }
                        navigationStack[i] = DiskNode(
                            name: parent.name,
                            path: parent.path,
                            bytes: parentBytes,
                            isDirectory: parent.isDirectory,
                            colorIndex: parent.colorIndex,
                            children: parent.children
                        )
                    }
                }
                rootNode = navigationStack.first
                updateBlipsFromCurrentNode()
            }
        }
    }

    private func updateBlipsFromCurrentNode() {
        guard let node = currentNode else { return }
        let top = node.children.prefix(14)
        let maxBytes = max(1.0, Double(top.first?.bytes ?? 1))
        var blips: [(name: String, bytes: Int64, angle: Double, distance: Double)] = []
        for (i, child) in top.enumerated() {
            let goldenAngle = Double(i) * 2.399963229728653
            let ratio = Double(child.bytes) / maxBytes
            let distance = 0.22 + (1.0 - ratio * 0.65) * 0.62
            blips.append((name: child.name, bytes: child.bytes, angle: goldenAngle, distance: distance))
        }
        liveRadarBlips = blips
    }

    /// Costruisce i segmenti concentrici del grafico radiale Sunburst (3 anelli gerarchici di profondità)
    var sunburstSegments: [SunburstSegment] {
        guard let root = currentNode, root.bytes > 0 else { return [] }
        var segments: [SunburstSegment] = []
        let total = Double(root.bytes)
        let fullCircle = Double.pi * 2.0
        let startOffset = -Double.pi / 2.0 // Parte dalle ore 12

        var cursor0 = startOffset
        for child0 in root.children.prefix(14) {
            let frac0 = Double(child0.bytes) / total
            let span0 = frac0 * fullCircle
            guard span0 > 0.015 else { continue }

            let end0 = cursor0 + span0
            segments.append(
                SunburstSegment(
                    id: child0.id,
                    node: child0,
                    ring: 0,
                    startAngle: cursor0,
                    endAngle: end0,
                    colorIndex: child0.colorIndex,
                    fractionOfRoot: frac0
                )
            )

            // Anello 1 (Sottocartelle di primo livello)
            if !child0.children.isEmpty && child0.bytes > 0 {
                var cursor1 = cursor0
                let parentBytes1 = Double(child0.bytes)
                for child1 in child0.children.prefix(10) {
                    let frac1 = Double(child1.bytes) / parentBytes1
                    let span1 = frac1 * span0
                    guard span1 > 0.018 else { continue }
                    let end1 = cursor1 + span1
                    segments.append(
                        SunburstSegment(
                            id: child1.id,
                            node: child1,
                            ring: 1,
                            startAngle: cursor1,
                            endAngle: end1,
                            colorIndex: child0.colorIndex,
                            fractionOfRoot: Double(child1.bytes) / total
                        )
                    )

                    // Anello 2 (Sottocartelle di secondo livello)
                    if !child1.children.isEmpty && child1.bytes > 0 {
                        var cursor2 = cursor1
                        let parentBytes2 = Double(child1.bytes)
                        for child2 in child1.children.prefix(8) {
                            let frac2 = Double(child2.bytes) / parentBytes2
                            let span2 = frac2 * span1
                            guard span2 > 0.022 else { continue }
                            let end2 = cursor2 + span2
                            segments.append(
                                SunburstSegment(
                                    id: child2.id,
                                    node: child2,
                                    ring: 2,
                                    startAngle: cursor2,
                                    endAngle: end2,
                                    colorIndex: child0.colorIndex,
                                    fractionOfRoot: Double(child2.bytes) / total
                                )
                            )
                            cursor2 = end2
                        }
                    }

                    cursor1 = end1
                }
            }

            cursor0 = end0
        }

        return segments
    }

    // MARK: - Parallel Tree Builder

    nonisolated static func buildTree(
        at rootURL: URL,
        maxDepth: Int,
        onProgress: @escaping @Sendable (String, Int) -> Void,
        onChildCompleted: @escaping @Sendable (String, Int64, Int) -> Void
    ) async -> DiskNode {
        let fm = FileManager.default
        guard let topContents = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: []
        ) else {
            return DiskNode(name: rootURL.lastPathComponent, path: rootURL.path, bytes: 0, isDirectory: true, colorIndex: 0, children: [])
        }

        // Evita di attraversare firmlink ridondanti, mount network e loop sintetici del kernel Darwin (come /.nofollow, /.vol)
        let skipPaths: Set<String> = [
            "/System/Volumes",
            "/dev",
            "/Volumes",
            "/Network",
            "/cores",
            "/home",
            "/net",
            "/private/var/vm"
        ]

        let topNodes: [DiskNode] = await withTaskGroup(of: DiskNode?.self) { group in
            for (index, itemURL) in topContents.enumerated() {
                let name = itemURL.lastPathComponent
                if rootURL.path == "/" && name.hasPrefix(".") { continue }
                if skipPaths.contains(itemURL.path) || itemURL.path.hasPrefix("/System/Volumes") { continue }
                group.addTask(priority: .userInitiated) {
                    var localSeen = 0
                    var lastReport = DispatchTime.now()
                    let node = scanDirectoryNode(
                        url: itemURL,
                        currentDepth: 1,
                        maxDepth: maxDepth,
                        colorIndex: index % 8,
                        seenCounter: &localSeen,
                        lastReport: &lastReport,
                        onProgress: onProgress
                    )
                    if localSeen > 0 {
                        onProgress(itemURL.path, localSeen)
                    }
                    if node.bytes > 0 || (itemURL.path.contains("/var/folders/") && (node.name == "0" || node.name == "X")) {
                        if node.bytes > 0 {
                            onChildCompleted(node.name, node.bytes, index)
                        }
                        return node
                    }
                    return nil
                }
            }

            var collected: [DiskNode] = []
            for await result in group {
                if let node = result {
                    collected.append(node)
                }
            }
            return collected
        }

        // Raggruppa eventuali file sciolti minori se la radice stessa è una cartella con centinaia di file (es. /var/folders/.../T)
        var majorNodes: [DiskNode] = []
        var looseSmallBytes: Int64 = 0
        var looseSmallPaths: [String] = []
        for n in topNodes {
            if !n.isDirectory && n.bytes < 512 * 1024 && n.safetyRule == .normal {
                looseSmallBytes += n.bytes
                looseSmallPaths.append(n.path)
            } else {
                majorNodes.append(n)
            }
        }
        if looseSmallBytes > 0 && !looseSmallPaths.isEmpty {
            majorNodes.append(
                DiskNode(
                    name: "File temporanei e media sciolti (\(looseSmallPaths.count) file)",
                    path: looseSmallPaths[0],
                    targetPaths: looseSmallPaths,
                    bytes: looseSmallBytes,
                    isDirectory: false,
                    colorIndex: 3,
                    children: []
                )
            )
        }

        // Raggruppa in ordine contiguo: prima tutti i nodi utente/app, poi tutte le cartelle di sistema vicine
        let userNodes = majorNodes.filter { !$0.isSystemFile }.sorted { $0.bytes > $1.bytes }
        let systemNodes = majorNodes.filter { $0.isSystemFile }.sorted { $0.bytes > $1.bytes }
        let sortedTopNodes = userNodes + systemNodes
        let rootTotal = sortedTopNodes.reduce(0) { $0 + $1.bytes }

        // Re-assegna colorIndex ordinato ai primi elementi per avere una tavolozza cromatica armoniosa nel Sunburst
        let coloredTopNodes = sortedTopNodes.enumerated().map { idx, n in
            DiskNode(
                name: n.name,
                path: n.path,
                targetPaths: n.targetPaths,
                bytes: n.bytes,
                isDirectory: n.isDirectory,
                colorIndex: idx % 8,
                children: n.children
            )
        }

        let rootName: String
        if rootURL.path == "/" {
            rootName = "Macintosh HD"
        } else if let volName = (try? rootURL.resourceValues(forKeys: [.volumeNameKey]))?.volumeName {
            rootName = volName
        } else {
            rootName = rootURL.lastPathComponent.isEmpty ? rootURL.path : rootURL.lastPathComponent
        }

        return DiskNode(
            name: rootName,
            path: rootURL.path,
            bytes: rootTotal,
            isDirectory: true,
            colorIndex: 0,
            children: Array(coloredTopNodes.prefix(35))
        )
    }

    nonisolated private static func scanDirectoryNode(
        url: URL,
        currentDepth: Int,
        maxDepth: Int,
        colorIndex: Int,
        seenCounter: inout Int,
        lastReport: inout DispatchTime,
        onProgress: @escaping @Sendable (String, Int) -> Void
    ) -> DiskNode {
        let p = url.path
        if p.hasPrefix("/System/Volumes") || p.hasPrefix("/dev") || p == "/Network" || (url.path != "/" && p.hasPrefix("/Volumes/")) {
            return DiskNode(name: url.lastPathComponent, path: url.path, bytes: 0, isDirectory: false, colorIndex: colorIndex, children: [])
        }

        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .isPackageKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey
        ]

        guard let values = try? url.resourceValues(forKeys: keys) else {
            return DiskNode(name: url.lastPathComponent, path: url.path, bytes: 0, isDirectory: false, colorIndex: colorIndex, children: [])
        }

        if values.isSymbolicLink == true {
            return DiskNode(name: url.lastPathComponent, path: url.path, bytes: 0, isDirectory: false, colorIndex: colorIndex, children: [])
        }

        if values.isRegularFile == true {
            let b = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
            seenCounter += 1
            return DiskNode(name: url.lastPathComponent, path: url.path, bytes: b, isDirectory: false, colorIndex: colorIndex, children: [])
        }

        // Se siamo oltre maxDepth o è un bundle (.app), calcoliamo la dimensione veloce senza espandere figli
        if currentDepth >= maxDepth || values.isPackage == true {
            let b = fastFolderSize(at: url, keys: keys, seenCounter: &seenCounter, lastReport: &lastReport, onProgress: onProgress)
            return DiskNode(
                name: url.lastPathComponent,
                path: url.path,
                bytes: b,
                isDirectory: values.isPackage != true,
                colorIndex: colorIndex,
                children: []
            )
        }

        guard let childrenURLs = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys), options: []) else {
            return DiskNode(name: url.lastPathComponent, path: url.path, bytes: 0, isDirectory: true, colorIndex: colorIndex, children: [])
        }

        var childNodes: [DiskNode] = []
        var totalBytes: Int64 = 0
        var groupedSmallFilesBytes: Int64 = 0
        var groupedSmallFilePaths: [String] = []

        // Scansioniamo tutti gli elementi della cartella per un calcolo completo e fedele al 100%
        for childURL in childrenURLs {
            let child = scanDirectoryNode(
                url: childURL,
                currentDepth: currentDepth + 1,
                maxDepth: maxDepth,
                colorIndex: colorIndex,
                seenCounter: &seenCounter,
                lastReport: &lastReport,
                onProgress: onProgress
            )
            if child.bytes > 0 {
                totalBytes += child.bytes
                if !child.isDirectory && child.bytes < 512 * 1024 {
                    groupedSmallFilesBytes += child.bytes
                    groupedSmallFilePaths.append(child.path)
                } else {
                    childNodes.append(child)
                }
            }
        }

        if groupedSmallFilesBytes > 0 && !groupedSmallFilePaths.isEmpty {
            let isDarwinT = url.lastPathComponent == "T" && url.path.contains("/var/folders/")
            let groupTitle = isDarwinT
                ? "File audio e temporanei sciolti (\(groupedSmallFilePaths.count) file)"
                : "File minori sciolti (\(groupedSmallFilePaths.count) file)"
            childNodes.append(
                DiskNode(
                    name: groupTitle,
                    path: groupedSmallFilePaths[0],
                    targetPaths: groupedSmallFilePaths,
                    bytes: groupedSmallFilesBytes,
                    isDirectory: false,
                    colorIndex: colorIndex,
                    children: []
                )
            )
        }

        childNodes.sort { a, b in
            if a.isSystemFile != b.isSystemFile {
                return !a.isSystemFile && b.isSystemFile
            }
            return a.bytes > b.bytes
        }
        return DiskNode(
            name: url.lastPathComponent,
            path: url.path,
            bytes: totalBytes,
            isDirectory: true,
            colorIndex: colorIndex,
            children: Array(childNodes.prefix(24))
        )
    }

    nonisolated private static func fastFolderSize(
        at url: URL,
        keys: Set<URLResourceKey>,
        seenCounter: inout Int,
        lastReport: inout DispatchTime,
        onProgress: @escaping @Sendable (String, Int) -> Void
    ) -> Int64 {
        let fm = FileManager.default
        var sum: Int64 = 0
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            let fp = fileURL.path
            if fp.hasPrefix("/System/Volumes") || fp.hasPrefix("/dev") {
                enumerator.skipDescendants()
                continue
            }
            guard let v = try? fileURL.resourceValues(forKeys: keys) else { continue }
            if v.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            if v.isRegularFile == true {
                sum += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? v.fileSize ?? 0)
                seenCounter += 1
                let now = DispatchTime.now()
                if now.uptimeNanoseconds - lastReport.uptimeNanoseconds > 180_000_000 {
                    lastReport = now
                    onProgress(fileURL.path, seenCounter)
                    seenCounter = 0
                }
            }
        }
        return sum
    }

    // MARK: - Volume Discovery

    nonisolated static func discoverVolumes() -> [DiskVolume] {
        if let sandbox = MacSafetyIntelligence.sandboxRootURL {
            return [
                DiskVolume(
                    id: sandbox.path,
                    name: "Bathys Test Sandbox",
                    url: sandbox,
                    isInternal: true,
                    totalBytes: 500 * 1024 * 1024,
                    availableBytes: 400 * 1024 * 1024
                )
            ]
        }

        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeIsInternalKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        var volumes: [DiskVolume] = []

        for url in urls {
            let path = url.path
            if path.hasPrefix("/System/Volumes") { continue }
            if path == "/private/var/vm" { continue }

            let vals = try? url.resourceValues(forKeys: Set(keys))
            let name = vals?.volumeName ?? (path == "/" ? "Macintosh HD" : url.lastPathComponent)
            let isInternal = vals?.volumeIsInternal ?? (path == "/")
            let total = Int64(vals?.volumeTotalCapacity ?? 0)
            let avail = Int64(vals?.volumeAvailableCapacity ?? 0)

            volumes.append(DiskVolume(
                id: path,
                name: name,
                url: url,
                isInternal: isInternal,
                totalBytes: total,
                availableBytes: avail
            ))
        }

        volumes.sort { v1, v2 in
            if v1.id == "/" { return true }
            if v2.id == "/" { return false }
            return v1.name.localizedStandardCompare(v2.name) == .orderedAscending
        }

        return volumes
    }
}

