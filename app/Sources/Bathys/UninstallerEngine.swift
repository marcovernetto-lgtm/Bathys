import Foundation
import Observation
import AppKit

struct AppResidualItem: Identifiable, Sendable {
    enum Kind: String, Sendable {
        case appBundle = "APP BUNDLE"
        case appSupport = "APP SUPPORT"
        case container = "CONTAINER"
        case cache = "CACHE"
        case preferences = "PREFERENZE"
        case launchAgent = "LAUNCH AGENT"
        case stateAndLogs = "STATI & LOG"
        case receipt = "RECEIPT"
    }

    let id = UUID()
    let name: String
    let path: String
    let kind: Kind
    let bytes: Int64
    var isSelected: Bool = true

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.replacingOccurrences(of: home, with: "~")
    }
}

struct InstalledApp: Identifiable, Hashable {
    let id: String // path
    let name: String
    let bundleId: String
    let version: String
    let url: URL
    var bundleBytes: Int64

    var formattedBundleSize: String {
        ByteCountFormatter.string(fromByteCount: bundleBytes, countStyle: .file)
    }

    var isRunning: Bool {
        let stdURL = url.standardizedFileURL
        return NSWorkspace.shared.runningApplications.contains { running in
            if !bundleId.isEmpty, let rId = running.bundleIdentifier, rId.caseInsensitiveCompare(bundleId) == .orderedSame {
                return true
            }
            if let bURL = running.bundleURL?.standardizedFileURL, bURL == stdURL {
                return true
            }
            return false
        }
    }

    var subfolderName: String? {
        let parent = url.deletingLastPathComponent()
        let parentPath = parent.path
        let homeApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        if parentPath == "/Applications" || parentPath == homeApps || parentPath == "/System/Applications" {
            return nil
        }
        let folderName = parent.lastPathComponent
        if folderName.hasSuffix(".localized") {
            return folderName.replacingOccurrences(of: ".localized", with: "")
        }
        return folderName
    }
}

/// Motore Disinstallazione Profonda Bathys: Scansione applicazioni installate, Drag & Drop .app e ricerca profonda di tutti i residui orfani in ~/Library e /Library.
@MainActor
final class UninstallerEngine: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var searchQuery: String = ""
    @Published var isLoadingApps = false
    @Published var isScanningResiduals = false
    @Published var selectedApp: InstalledApp?
    @Published var residuals: [AppResidualItem] = []
    @Published var showUninstallConfirmation = false
    @Published var lastUninstalledAppName: String?
    @Published var lastFreedBytes: Int64 = 0
    private var inspectTask: Task<Void, Never>?

    var filteredApps: [InstalledApp] {
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return apps
        }
        let q = searchQuery.lowercased()
        return apps.filter {
            $0.name.lowercased().contains(q) ||
            $0.bundleId.lowercased().contains(q) ||
            ($0.subfolderName?.lowercased().contains(q) ?? false)
        }
    }

    var totalSelectedBytes: Int64 {
        residuals.filter { $0.isSelected }.reduce(0) { $0 + $1.bytes }
    }

    /// True quando l'utente ha scelto "Reset Dati" (preserva il bundle .app ed elimina solo cache/preferenze/residui)
    var isResetOnlyMode: Bool {
        guard let bundleItem = residuals.first(where: { $0.kind == .appBundle }) else { return false }
        let hasOtherSelected = residuals.contains(where: { $0.kind != .appBundle && $0.isSelected })
        return !bundleItem.isSelected && hasOtherSelected
    }

    func setUninstallScope(resetOnly: Bool) {
        for i in residuals.indices {
            if residuals[i].kind == .appBundle {
                residuals[i].isSelected = !resetOnly
            } else {
                residuals[i].isSelected = true
            }
        }
    }

    @discardableResult
    func terminateRunningApp(_ app: InstalledApp) -> Bool {
        let stdURL = app.url.standardizedFileURL
        var terminatedAny = false
        for running in NSWorkspace.shared.runningApplications {
            let matchId = !app.bundleId.isEmpty && running.bundleIdentifier?.caseInsensitiveCompare(app.bundleId) == .orderedSame
            let matchURL = running.bundleURL?.standardizedFileURL == stdURL
            if matchId || matchURL {
                if running.terminate() {
                    terminatedAny = true
                }
            }
        }
        return terminatedAny
    }

    /// Raggruppamento per i satelliti visuali nella Camera di Decompressione (Left Pane)
    var categoryBreakdown: [(kind: AppResidualItem.Kind, bytes: Int64, count: Int)] {
        var map: [AppResidualItem.Kind: (bytes: Int64, count: Int)] = [:]
        for item in residuals where item.kind != .appBundle {
            let cur = map[item.kind] ?? (0, 0)
            map[item.kind] = (cur.bytes + item.bytes, cur.count + 1)
        }
        return map.map { ($0.key, $0.value.bytes, $0.value.count) }
            .sorted { $0.bytes > $1.bytes }
    }

    func loadInstalledApps() {
        guard !isLoadingApps else { return }
        isLoadingApps = true

        Task {
            let discovered = await Task.detached(priority: .userInitiated) {
                UninstallerEngine.scanApplicationsFolders()
            }.value

            self.apps = discovered
            self.isLoadingApps = false
            if let currentURL = self.selectedApp?.url.standardizedFileURL,
               let matched = discovered.first(where: { $0.url.standardizedFileURL == currentURL }) {
                self.inspectApp(matched)
            } else if let first = discovered.first {
                self.inspectApp(first)
            } else {
                self.selectedApp = nil
                self.residuals = []
            }
        }
    }

    func inspectApp(_ app: InstalledApp) {
        inspectTask?.cancel()
        selectedApp = app
        isScanningResiduals = true
        residuals = []
        lastUninstalledAppName = nil

        inspectTask = Task {
            let found = await Task.detached(priority: .userInitiated) {
                UninstallerEngine.findResiduals(for: app)
            }.value

            guard !Task.isCancelled, self.selectedApp?.id == app.id else { return }
            self.residuals = found
            if self.isResetOnlyMode {
                for idx in self.residuals.indices {
                    self.residuals[idx].isSelected = (self.residuals[idx].kind != .appBundle)
                }
            }
            // Aggiorna la dimensione del bundle nella lista se calcolata
            if let bundleItem = found.first(where: { $0.kind == .appBundle }),
               let idx = self.apps.firstIndex(where: { $0.id == app.id }) {
                self.apps[idx].bundleBytes = bundleItem.bytes
            }
            self.isScanningResiduals = false
        }
    }

    func selectNextApp() {
        let list = filteredApps
        guard !list.isEmpty else { return }
        guard let current = selectedApp, let idx = list.firstIndex(where: { $0.id == current.id }) else {
            if let first = list.first { inspectApp(first) }
            return
        }
        if idx + 1 < list.count {
            inspectApp(list[idx + 1])
        }
    }

    func selectPreviousApp() {
        let list = filteredApps
        guard !list.isEmpty else { return }
        guard let current = selectedApp, let idx = list.firstIndex(where: { $0.id == current.id }) else {
            if let first = list.first { inspectApp(first) }
            return
        }
        if idx > 0 {
            inspectApp(list[idx - 1])
        }
    }

    func handleDroppedAppURL(_ url: URL) {
        let resolvedURL = url.standardizedFileURL
        guard resolvedURL.pathExtension.lowercased() == "app" else { return }

        if let existing = apps.first(where: { $0.url.standardizedFileURL == resolvedURL }) {
            inspectApp(existing)
            return
        }

        if let customApp = Self.parseAppBundle(at: resolvedURL, computeInitialSize: true) {
            apps.insert(customApp, at: 0)
            inspectApp(customApp)
        }
    }

    func pickAppFromDisk() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Analizza Residui App"
        panel.message = "Seleziona un'applicazione (.app) per cercare tutti i suoi file sparsi nel Mac"
        if panel.runModal() == .OK, let url = panel.url {
            handleDroppedAppURL(url)
        }
    }

    func uninstallSelectedItems() {
        guard let app = selectedApp, !residuals.isEmpty else { return }
        showUninstallConfirmation = false

        // Se l'applicazione è attualmente aperta, chiudila gentilmente prima di spostare i suoi file nel Cestino
        if app.isRunning && MacSafetyIntelligence.sandboxRootURL == nil {
            _ = terminateRunningApp(app)
            Thread.sleep(forTimeInterval: 0.35)
        }

        let fm = FileManager.default
        let sandbox = MacSafetyIntelligence.sandboxRootURL
        var freed: Int64 = 0
        var remaining: [AppResidualItem] = []
        var removedAppBundle = false

        for item in residuals {
            if item.isSelected {
                let url = URL(fileURLWithPath: item.path)
                var deleted = false
                if let sb = sandbox {
                    let sbPath = (sb.path as NSString).standardizingPath
                    let targetPath = (url.path as NSString).standardizingPath
                    if targetPath.hasPrefix(sbPath + "/") {
                        deleted = (try? fm.removeItem(at: url)) != nil
                    }
                } else {
                    if (try? fm.trashItem(at: url, resultingItemURL: nil)) != nil {
                        deleted = true
                    } else {
                        let sema = DispatchSemaphore(value: 0)
                        var recycled = false
                        NSWorkspace.shared.recycle([url]) { dict, err in
                            if err == nil && !dict.isEmpty { recycled = true }
                            sema.signal()
                        }
                        _ = sema.wait(timeout: .now() + 2.0)
                        deleted = recycled || !fm.fileExists(atPath: url.path)
                    }
                }

                if deleted {
                    freed += item.bytes
                    if item.kind == .appBundle {
                        removedAppBundle = true
                    }
                } else {
                    remaining.append(item)
                }
            } else {
                remaining.append(item)
            }
        }

        lastUninstalledAppName = app.name
        lastFreedBytes = freed
        residuals = remaining

        if removedAppBundle {
            apps.removeAll { $0.id == app.id }
            selectedApp = apps.first
            if let next = selectedApp {
                inspectApp(next)
            }
        }

        SoundManager.shared.playChime()
    }

    // MARK: - Deep Residual Correlation Engine

    nonisolated static func scanApplicationsFolders() -> [InstalledApp] {
        let fm = FileManager.default
        let roots: [URL]
        if let sandbox = MacSafetyIntelligence.sandboxRootURL {
            roots = [sandbox.appendingPathComponent("Applications")]
        } else {
            let home = fm.homeDirectoryForCurrentUser
            roots = [
                URL(fileURLWithPath: "/Applications"),
                home.appendingPathComponent("Applications")
            ]
        }

        var result: [InstalledApp] = []
        var seenPaths: Set<String> = []
        var visitedDirs: Set<String> = []

        func scanDirectory(_ dir: URL, depth: Int) {
            if depth > 4 { return }
            let realPath = (try? dir.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath ?? dir.standardized.path
            guard !visitedDirs.contains(realPath) else { return }
            visitedDirs.insert(realPath)

            guard let contents = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            for item in contents {
                if item.pathExtension.lowercased() == "app" {
                    let path = item.standardizedFileURL.path
                    guard !seenPaths.contains(path) else { continue }
                    seenPaths.insert(path)

                    if let app = parseAppBundle(at: item, computeInitialSize: false) {
                        // Evita app di sistema Apple non rimovibili e proteggi Bathys stesso dall'auto-disinstallazione
                        if app.bundleId.hasPrefix("com.apple.Safari") { continue }
                        if app.bundleId == "com.bathys.cleaner" || app.name.lowercased() == "bathys" { continue }
                        result.append(app)
                    }
                    // Non ricorrere all'interno del bundle .app
                } else {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                        let ext = item.pathExtension.lowercased()
                        // Evita cartelle framework, plugin o bundle interni non .app
                        if ext.isEmpty || ext == "localized" {
                            scanDirectory(item, depth: depth + 1)
                        }
                    }
                }
            }
        }

        for root in roots where fm.fileExists(atPath: root.path) {
            scanDirectory(root, depth: 0)
        }

        result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return result
    }

    nonisolated static func parseAppBundle(at url: URL, computeInitialSize: Bool) -> InstalledApp? {
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        let dict = NSDictionary(contentsOf: plistURL) as? [String: Any]
        let fileName = url.deletingPathExtension().lastPathComponent
        let displayName = (dict?["CFBundleDisplayName"] as? String)?.trimmingCharacters(in: .whitespaces)
        let cfName = (dict?["CFBundleName"] as? String)?.trimmingCharacters(in: .whitespaces)
        
        let finalName: String
        if let d = displayName, !d.isEmpty {
            finalName = d
        } else if !fileName.isEmpty {
            finalName = fileName
        } else if let c = cfName, !c.isEmpty {
            finalName = c
        } else {
            finalName = "Applicazione"
        }

        let bundleId = (dict?["CFBundleIdentifier"] as? String) ?? ""
        let version = (dict?["CFBundleShortVersionString"] as? String) ?? "1.0"
        let size = computeInitialSize ? computeAllocatedSize(at: url) : 0

        return InstalledApp(
            id: url.path,
            name: finalName,
            bundleId: bundleId,
            version: version,
            url: url,
            bundleBytes: size
        )
    }

    /// Normalizzazione euristica: estrae token alfanumerici minuscoli per il pattern matching
    nonisolated private static func canonicalizeToken(_ s: String) -> String {
        let strippedVersion = s.replacingOccurrences(
            of: #"\s+\d+(\.\d+)*\s*$"#,
            with: "",
            options: .regularExpression
        )
        return String(strippedVersion.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    nonisolated static func findResiduals(for app: InstalledApp) -> [AppResidualItem] {
        let fm = FileManager.default
        let sandbox = MacSafetyIntelligence.sandboxRootURL
        let home = sandbox ?? fm.homeDirectoryForCurrentUser
        let userLib = home.appendingPathComponent("Library")
        let sysLib = sandbox != nil ? home.appendingPathComponent("SystemLibrary") : URL(fileURLWithPath: "/Library")
        let receiptsDir = sandbox != nil ? home.appendingPathComponent("receipts") : URL(fileURLWithPath: "/private/var/db/receipts")

        var items: [AppResidualItem] = []
        var seenPaths: Set<String> = []

        // 1. Il bundle .app principale
        let bundleSize = computeAllocatedSize(at: app.url)
        items.append(
            AppResidualItem(
                name: "\(app.name).app",
                path: app.url.path,
                kind: .appBundle,
                bytes: bundleSize,
                isSelected: true
            )
        )
        seenPaths.insert(app.url.standardizedFileURL.path)

        // Costruisci token di correlazione per identificare residui orfani
        let rawBundleId = app.bundleId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normBundleId = canonicalizeToken(rawBundleId)
        let normAppName = canonicalizeToken(app.name)
        let normFileName = canonicalizeToken(app.url.deletingPathExtension().lastPathComponent)

        let bundleParts = rawBundleId.split(separator: ".").map(String.init)
        let lastTwoNorm = bundleParts.suffix(2).joined().filter { $0.isLetter || $0.isNumber }

        // Estrai eventuale vendor (es. com.google.Chrome -> google, com.spotify.client -> spotify)
        let genericVendors: Set<String> = [
            "com", "org", "net", "io", "app", "me", "dev", "co", "uk", "de", "fr", "it",
            "apple", "macos", "osx", "desktop", "client", "mac", "software", "studio", "inc", "ltd"
        ]
        var vendorToken: String? = nil
        if bundleParts.count >= 3 {
            let candidate = canonicalizeToken(bundleParts[1])
            if candidate.count >= 4 && !genericVendors.contains(candidate) {
                vendorToken = candidate
            }
        }

        // Mappa delle directory di scansione profonda
        let searchTargets: [(URL, AppResidualItem.Kind)] = [
            (userLib.appendingPathComponent("Application Support"), .appSupport),
            (userLib.appendingPathComponent("Application Scripts"), .appSupport),
            (userLib.appendingPathComponent("Containers"), .container),
            (userLib.appendingPathComponent("Group Containers"), .container),
            (userLib.appendingPathComponent("Caches"), .cache),
            (userLib.appendingPathComponent("HTTPStorages"), .cache),
            (userLib.appendingPathComponent("WebKit"), .cache),
            (userLib.appendingPathComponent("Cookies"), .cache),
            (userLib.appendingPathComponent("Preferences"), .preferences),
            (userLib.appendingPathComponent("Preferences/ByHost"), .preferences),
            (userLib.appendingPathComponent("Saved Application State"), .stateAndLogs),
            (userLib.appendingPathComponent("Logs"), .stateAndLogs),
            (userLib.appendingPathComponent("Logs/DiagnosticReports"), .stateAndLogs),
            (userLib.appendingPathComponent("LaunchAgents"), .launchAgent),
            (sysLib.appendingPathComponent("Application Support"), .appSupport),
            (sysLib.appendingPathComponent("Caches"), .cache),
            (sysLib.appendingPathComponent("Preferences"), .preferences),
            (sysLib.appendingPathComponent("LaunchAgents"), .launchAgent),
            (sysLib.appendingPathComponent("LaunchDaemons"), .launchAgent),
            (sysLib.appendingPathComponent("PrivilegedHelperTools"), .launchAgent),
            (receiptsDir, .receipt)
        ]

        for (dirURL, kind) in searchTargets where fm.fileExists(atPath: dirURL.path) {
            guard let children = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: []) else {
                continue
            }

            for child in children {
                let childName = child.lastPathComponent
                let childLower = childName.lowercased()
                let childNorm = canonicalizeToken(childName)

                var matched = false

                // Match 1: Bundle ID diretto (es. com.spotify.client o 2FNC3A47ZF.com.spotify...)
                if !rawBundleId.isEmpty && childLower.contains(rawBundleId) {
                    matched = true
                }
                // Match 2: Bundle ID normalizzato
                else if normBundleId.count >= 6 && childNorm.contains(normBundleId) {
                    matched = true
                }
                // Match 3: Nome app normalizzato (almeno 4 caratteri per evitare falsi positivi)
                else if normAppName.count >= 4 && childNorm.contains(normAppName) {
                    matched = true
                }
                else if normFileName.count >= 4 && childNorm.contains(normFileName) {
                    matched = true
                }
                // Match 4: Ultime due componenti del bundleId (almeno 6 caratteri)
                else if lastTwoNorm.count >= 6 && childNorm.contains(lastTwoNorm) {
                    matched = true
                }

                // Match 5: Se il nome cartella corrisponde esattamente al vendor (es. ~/Library/Application Support/Google/Chrome)
                if !matched, let vendor = vendorToken, childNorm == vendor {
                    if let subChildren = try? fm.contentsOfDirectory(at: child, includingPropertiesForKeys: nil, options: []) {
                        for sub in subChildren {
                            let subNorm = canonicalizeToken(sub.lastPathComponent)
                            if (normAppName.count >= 3 && subNorm.contains(normAppName)) ||
                               (!rawBundleId.isEmpty && sub.lastPathComponent.lowercased().contains(rawBundleId)) {
                                let stdPath = sub.standardizedFileURL.path
                                if !seenPaths.contains(stdPath) {
                                    seenPaths.insert(stdPath)
                                    let b = computeAllocatedSize(at: sub)
                                    items.append(
                                        AppResidualItem(
                                            name: "\(childName)/\(sub.lastPathComponent)",
                                            path: stdPath,
                                            kind: kind,
                                            bytes: b,
                                            isSelected: true
                                        )
                                    )
                                }
                            }
                        }
                    }
                }

                if matched {
                    let stdPath = child.standardizedFileURL.path
                    guard !seenPaths.contains(stdPath) else { continue }
                    seenPaths.insert(stdPath)
                    let b = computeAllocatedSize(at: child)
                    items.append(
                        AppResidualItem(
                            name: childName,
                            path: stdPath,
                            kind: kind,
                            bytes: b,
                            isSelected: true
                        )
                    )
                }
            }
        }

        // Mantieni il bundle .app in cima, poi ordina i residui per dimensione decrescente
        let bundleItems = items.filter { $0.kind == .appBundle }
        let otherItems = items.filter { $0.kind != .appBundle }.sorted { $0.bytes > $1.bytes }
        return bundleItems + otherItems
    }

    nonisolated static func computeAllocatedSize(at url: URL) -> Int64 {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]

        if let topVals = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]), topVals.isSymbolicLink == true {
            return 0
        }

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            let v = try? url.resourceValues(forKeys: keys)
            return Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? v?.fileSize ?? 0)
        }

        var total: Int64 = 0
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            guard let v = try? fileURL.resourceValues(forKeys: keys) else { continue }
            if v.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            if v.isRegularFile == true {
                total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? v.fileSize ?? 0)
            }
        }
        return total
    }
}
