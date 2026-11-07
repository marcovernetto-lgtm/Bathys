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
    /// True per corrispondenze certe (bundle ID o nome identico). Le corrispondenze solo "simili"
    /// vengono mostrate ma non preselezionate, così l'utente decide consapevolmente.
    var isStrongMatch: Bool = true

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
@MainActor @Observable
final class UninstallerEngine {
    var apps: [InstalledApp] = []
    var searchQuery: String = ""
    var isLoadingApps = false
    var isScanningResiduals = false
    var selectedApp: InstalledApp?
    var residuals: [AppResidualItem] = []
    var showUninstallConfirmation = false
    var lastUninstalledAppName: String?
    var lastFreedBytes: Int64 = 0
    var lastFailedCount: Int = 0
    var isUninstalling = false
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
                residuals[i].isSelected = residuals[i].isStrongMatch
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

        // Bundle ID delle altre app installate: servono per non attribuire a questa app i file di un'app "sorella"
        // (es. com.google.Chrome vs com.google.Chrome.canary)
        let ownId = app.bundleId.lowercased()
        let otherIds = Set(apps.map { $0.bundleId.lowercased() }.filter { !$0.isEmpty && $0 != ownId })
        let otherNames = apps.filter { $0.id != app.id }.map(\.name)

        inspectTask = Task {
            let found = await Task.detached(priority: .userInitiated) {
                UninstallerEngine.findResiduals(for: app, otherBundleIds: otherIds, otherAppNames: otherNames)
            }.value

            guard !Task.isCancelled, self.selectedApp?.id == app.id else { return }
            self.residuals = found
            if self.isResetOnlyMode {
                for idx in self.residuals.indices {
                    self.residuals[idx].isSelected = (self.residuals[idx].kind != .appBundle) && self.residuals[idx].isStrongMatch
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
        guard !Self.isProtectedAppLocation(resolvedURL) else { return }

        if let existing = apps.first(where: { $0.url.standardizedFileURL == resolvedURL }) {
            inspectApp(existing)
            return
        }

        if let customApp = Self.parseAppBundle(at: resolvedURL, computeInitialSize: true),
           !Self.isProtectedBundleId(customApp.bundleId) {
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
        guard let app = selectedApp, !residuals.isEmpty, !isUninstalling else { return }
        showUninstallConfirmation = false

        let items = residuals
        guard items.contains(where: \.isSelected) else { return }
        isUninstalling = true
        let shouldTerminate = MacSafetyIntelligence.sandboxRootURL == nil && app.isRunning

        Task {
            // Se l'applicazione è aperta, chiudila gentilmente e attendi che termini davvero
            // (senza bloccare il Main Thread) prima di spostare i suoi file nel Cestino.
            if shouldTerminate {
                _ = terminateRunningApp(app)
                for _ in 0..<50 where app.isRunning {
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }

            let outcome = await Task.detached(priority: .userInitiated) {
                UninstallerEngine.performRemoval(of: items, appURL: app.url)
            }.value

            lastUninstalledAppName = app.name
            lastFreedBytes = outcome.freed
            lastFailedCount = outcome.failedCount
            if selectedApp?.id == app.id {
                residuals = items.filter { !outcome.removedIds.contains($0.id) }
            }
            isUninstalling = false

            if outcome.removedAppBundle {
                apps.removeAll { $0.id == app.id }
                if selectedApp?.id == app.id {
                    selectedApp = apps.first
                    if let next = selectedApp {
                        inspectApp(next)
                    } else {
                        residuals = []
                    }
                }
            }

            SoundManager.shared.playChime()
        }
    }

    struct RemovalOutcome: Sendable {
        var freed: Int64 = 0
        var removedIds: Set<UUID> = []
        var removedAppBundle = false
        var failedCount = 0
    }

    /// Esegue fisicamente la rimozione (thread in background): verifica di sicurezza per ogni percorso,
    /// scaricamento dei LaunchAgent utente da launchd e un unico fallback Finder per gli elementi protetti.
    nonisolated static func performRemoval(of items: [AppResidualItem], appURL: URL) -> RemovalOutcome {
        let fm = FileManager.default
        var outcome = RemovalOutcome()
        var pendingFallback: [AppResidualItem] = []

        for item in items where item.isSelected {
            guard isRemovableResidual(item, appURL: appURL) else {
                outcome.failedCount += 1
                continue
            }
            let url = URL(fileURLWithPath: item.path)

            if item.kind == .launchAgent {
                unloadUserLaunchAgentIfNeeded(at: url)
            }

            if SafeFileOps.moveToTrash(url) {
                outcome.freed += item.bytes
                outcome.removedIds.insert(item.id)
                if item.kind == .appBundle { outcome.removedAppBundle = true }
            } else if fm.fileExists(atPath: url.path) {
                pendingFallback.append(item)
            }
        }

        // Elementi di proprietà di root (es. /Library, receipts): un'unica richiesta al Finder,
        // che può chiedere una sola volta la password di amministratore per tutti.
        if !pendingFallback.isEmpty && MacSafetyIntelligence.sandboxRootURL == nil {
            let urls = pendingFallback.map { URL(fileURLWithPath: $0.path) }
            let sema = DispatchSemaphore(value: 0)
            NSWorkspace.shared.recycle(urls) { _, _ in sema.signal() }
            _ = sema.wait(timeout: .now() + 120)
        }
        for item in pendingFallback {
            if !fm.fileExists(atPath: item.path) {
                outcome.freed += item.bytes
                outcome.removedIds.insert(item.id)
                if item.kind == .appBundle { outcome.removedAppBundle = true }
            } else {
                outcome.failedCount += 1
            }
        }
        return outcome
    }

    /// Scarica da launchd un LaunchAgent utente prima di cestinarne il plist (altrimenti resterebbe attivo fino al logout)
    nonisolated static func unloadUserLaunchAgentIfNeeded(at plistURL: URL) {
        guard MacSafetyIntelligence.sandboxRootURL == nil else { return }
        let userAgents = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents").path
        guard plistURL.standardizedFileURL.path.hasPrefix(userAgents + "/") else { return }
        SafeFileOps.runProcess("/bin/launchctl", ["bootout", "gui/\(getuid())", plistURL.path], timeout: 10)
    }

    /// Ultima verifica di sicurezza prima della rimozione di un elemento della lista residui
    nonisolated static func isRemovableResidual(_ item: AppResidualItem, appURL: URL) -> Bool {
        let p = (item.path as NSString).standardizingPath
        if item.kind == .appBundle {
            guard p == (appURL.standardizedFileURL.path as NSString).standardizingPath,
                  p.lowercased().hasSuffix(".app"),
                  !isProtectedAppLocation(URL(fileURLWithPath: p)) else { return false }
            return !MacSafetyIntelligence.isForbiddenToDelete(path: p, allowUserContent: true)
        }
        // I residui devono trovarsi strettamente all'interno di una delle cartelle di ricerca (mai la cartella stessa)
        let roots = residualSearchTargets().map { ($0.0.standardizedFileURL.path as NSString).standardizingPath }
        if roots.contains(p) { return false }
        return roots.contains { p.hasPrefix($0 + "/") }
    }

    /// Bathys stesso, le app di sistema e Safari non devono mai essere disinstallati
    nonisolated static func isProtectedAppLocation(_ url: URL) -> Bool {
        let p = url.standardizedFileURL.resolvingSymlinksInPath().path
        if p.hasPrefix("/System/") { return true }
        if p == Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath().path { return true }
        return false
    }

    nonisolated static func isProtectedBundleId(_ bundleId: String) -> Bool {
        let id = bundleId.lowercased()
        return id == "com.bathys.cleaner" || id.hasPrefix("com.apple.safari")
    }

    /// Cartelle in cui vengono cercati i residui delle app
    nonisolated static func residualSearchTargets() -> [(URL, AppResidualItem.Kind)] {
        let fm = FileManager.default
        let sandbox = MacSafetyIntelligence.sandboxRootURL
        let home = sandbox ?? fm.homeDirectoryForCurrentUser
        let userLib = home.appendingPathComponent("Library")
        let sysLib = sandbox != nil ? home.appendingPathComponent("SystemLibrary") : URL(fileURLWithPath: "/Library")
        let receiptsDir = sandbox != nil ? home.appendingPathComponent("receipts") : URL(fileURLWithPath: "/private/var/db/receipts")
        return [
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
                        if isProtectedBundleId(app.bundleId) || app.name.lowercased() == "bathys" { continue }
                        if isProtectedAppLocation(item) { continue }
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

    /// Spezza un nome in token alfanumerici minuscoli (es. "com.spotify.client" -> ["com", "spotify", "client"])
    nonisolated private static func tokenize(_ s: String) -> [String] {
        s.lowercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
    }

    /// True se una sequenza contigua di token, concatenata, coincide esattamente con `target`.
    /// Evita i falsi positivi delle ricerche per sottostringa (es. app "Line" vs cartella "Timeline").
    nonisolated private static func tokensContainRun(_ tokens: [String], equalTo target: String) -> Bool {
        guard !target.isEmpty else { return false }
        for i in tokens.indices {
            var acc = ""
            for j in i..<tokens.count {
                acc += tokens[j]
                if acc == target { return true }
                if !target.hasPrefix(acc) { break }
            }
        }
        return false
    }

    /// True se `id` compare in `name` delimitato da inizio/fine stringa o da caratteri non alfanumerici
    nonisolated private static func containsDelimited(_ name: String, _ id: String) -> Bool {
        guard !id.isEmpty else { return false }
        var searchRange = name.startIndex..<name.endIndex
        while let r = name.range(of: id, options: [], range: searchRange) {
            let beforeOK = r.lowerBound == name.startIndex || !name[name.index(before: r.lowerBound)].isLetterOrDigit
            let afterOK = r.upperBound == name.endIndex || !name[r.upperBound].isLetterOrDigit
            if beforeOK && afterOK { return true }
            searchRange = r.upperBound..<name.endIndex
        }
        return false
    }

    /// Indici (esclusivi) in cui termina una sequenza contigua di token uguale a `target`
    nonisolated private static func tokenRunEnds(_ tokens: [String], equalTo target: String) -> [Int] {
        guard !target.isEmpty else { return [] }
        var ends: [Int] = []
        for i in tokens.indices {
            var acc = ""
            for j in i..<tokens.count {
                acc += tokens[j]
                if acc == target { ends.append(j + 1); break }
                if !target.hasPrefix(acc) { break }
            }
        }
        return ends
    }

    nonisolated static func findResiduals(
        for app: InstalledApp,
        otherBundleIds: Set<String> = [],
        otherAppNames: [String] = []
    ) -> [AppResidualItem] {
        let fm = FileManager.default

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
        let isAppleApp = rawBundleId.hasPrefix("com.apple.")
        let normBundleId = canonicalizeToken(rawBundleId)
        let normAppName = canonicalizeToken(app.name)
        let normFileName = canonicalizeToken(app.url.deletingPathExtension().lastPathComponent)

        let bundleParts = rawBundleId.split(separator: ".").map(String.init)
        let lastTwoNorm = bundleParts.suffix(2).joined().filter { $0.isLetter || $0.isNumber }

        // Versione nel nome (es. "Adobe Photoshop 2022" -> "2022"): i dati di altre versioni non vanno toccati
        let appVersionToken: String? = {
            guard let r = app.name.range(of: #"\s+(\d+)(\.\d+)*\s*$"#, options: .regularExpression) else { return nil }
            return app.name[r].trimmingCharacters(in: .whitespaces).split(separator: ".").first.map(String.init)
        }()

        // Nomi di altre app installate più specifici del nostro (es. "SpyderUtility" per "Spyder", "ChatGPT Atlas" per "ChatGPT")
        let longerSiblingNames = Set(otherAppNames.map { canonicalizeToken($0) })
            .filter { normAppName.count >= 4 && $0.count > normAppName.count && $0.hasPrefix(normAppName) }

        // App "sorelle" con bundle ID più specifico del nostro (es. com.google.chrome.canary per com.google.chrome)
        let moreSpecificSiblings = otherBundleIds.filter { !rawBundleId.isEmpty && $0.count > rawBundleId.count && $0.hasPrefix(rawBundleId) }

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

        /// Esclusioni di sicurezza valide per ogni candidato
        func isExcluded(_ name: String) -> Bool {
            let lower = name.lowercased()
            if name.hasPrefix(".") { return true }
            // Dati di sistema Apple: mai attribuiti a un'app di terze parti
            if !isAppleApp && (lower.hasPrefix("com.apple.") || lower.hasPrefix("group.com.apple.") || lower.contains(".com.apple.")) {
                return true
            }
            if MacSafetyIntelligence.protectedCacheIdentifiers.contains(name) { return true }
            // Appartiene a un'altra app installata più specifica (es. Chrome Canary)
            if moreSpecificSiblings.contains(where: { containsDelimited(lower, $0) }) { return true }
            // Il nome contiene il bundle ID completo di un'altra app installata, ma non il nostro
            if !containsDelimited(lower, rawBundleId) && otherBundleIds.contains(where: { $0.count >= 8 && containsDelimited(lower, $0) }) {
                return true
            }
            if !containsDelimited(lower, rawBundleId) {
                let tokens = tokenize(name)
                let norm = canonicalizeToken(name)
                // Appartiene a un'altra app installata con nome più specifico
                if longerSiblingNames.contains(where: { norm == $0 || norm.hasPrefix($0) || tokensContainRun(tokens, equalTo: $0) }) {
                    return true
                }
                // Stesso prodotto ma versione diversa (es. "Adobe Photoshop 2026 Settings" per Photoshop 2022)
                if let version = appVersionToken {
                    for end in tokenRunEnds(tokens, equalTo: normAppName) where end < tokens.count {
                        let next = tokens[end]
                        if next.allSatisfy(\.isNumber) && next != version { return true }
                    }
                }
            }
            return false
        }

        enum MatchStrength { case none, weak, strong }

        func matchStrength(_ name: String) -> MatchStrength {
            let lower = name.lowercased()
            let tokens = tokenize(name)
            let norm = canonicalizeToken(name)

            // Match 1: Bundle ID diretto delimitato (es. com.spotify.client o 2FNC3A47ZF.com.spotify.client)
            if !rawBundleId.isEmpty && containsDelimited(lower, rawBundleId) { return .strong }
            // Match 2: Bundle ID normalizzato come sequenza di token
            if normBundleId.count >= 6 && tokensContainRun(tokens, equalTo: normBundleId) { return .strong }
            // Match 4: Ultime due componenti del bundleId (almeno 6 caratteri)
            if lastTwoNorm.count >= 6 && tokensContainRun(tokens, equalTo: lastTwoNorm) { return .strong }
            // Match 3: Nome app / nome file (almeno 4 caratteri)
            var weak = false
            for candidate in [normAppName, normFileName] where candidate.count >= 4 {
                // Nome identico (es. "Spotify", "Google Chrome", "Adobe Photoshop 2022"): corrispondenza certa
                if norm == candidate || canonicalizeToken(name.replacingOccurrences(of: #"\.[A-Za-z]+$"#, with: "", options: .regularExpression)) == candidate {
                    return .strong
                }
                // Nome contenuto con parole aggiuntive (es. "Claude-3p", "Foo Helper"): solo suggerito
                if tokensContainRun(tokens, equalTo: candidate) { weak = true }
                // Nomi composti senza separatori (es. "DockerDesktop") solo per nomi abbastanza distintivi
                if candidate.count >= 6 && norm.hasPrefix(candidate) { weak = true }
            }
            return weak ? .weak : .none
        }

        func appendItem(name: String, url: URL, kind: AppResidualItem.Kind, strong: Bool) {
            let stdPath = url.standardizedFileURL.path
            guard !seenPaths.contains(stdPath) else { return }
            // Evita link simbolici: il loro contenuto reale appartiene ad altre posizioni
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true { return }
            seenPaths.insert(stdPath)
            items.append(
                AppResidualItem(
                    name: name,
                    path: stdPath,
                    kind: kind,
                    bytes: computeAllocatedSize(at: url),
                    isSelected: strong,
                    isStrongMatch: strong
                )
            )
        }

        for (dirURL, kind) in residualSearchTargets() where fm.fileExists(atPath: dirURL.path) {
            guard let children = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [.isSymbolicLinkKey], options: []) else {
                continue
            }

            for child in children {
                let childName = child.lastPathComponent
                guard !isExcluded(childName) else { continue }

                let strength = matchStrength(childName)
                if strength != .none {
                    appendItem(name: childName, url: child, kind: kind, strong: strength == .strong)
                    continue
                }

                // Match 5: cartella del vendor (es. ~/Library/Application Support/Google/Chrome)
                guard let vendor = vendorToken, canonicalizeToken(childName) == vendor,
                      let subChildren = try? fm.contentsOfDirectory(at: child, includingPropertiesForKeys: [.isSymbolicLinkKey], options: []) else {
                    continue
                }
                for sub in subChildren {
                    let subName = sub.lastPathComponent
                    guard !isExcluded(subName) else { continue }
                    let subNorm = canonicalizeToken(subName)
                    // "Chrome" dentro "Google" per l'app "Google Chrome": il nome app termina con il nome della sottocartella
                    let vendorScoped = subNorm.count >= 4 && normAppName == vendor + subNorm
                    let strength = vendorScoped ? .strong : matchStrength(subName)
                    if strength != .none {
                        appendItem(name: "\(childName)/\(subName)", url: sub, kind: kind, strong: strength == .strong)
                    }
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

private extension Character {
    var isLetterOrDigit: Bool { isLetter || isNumber }
}
