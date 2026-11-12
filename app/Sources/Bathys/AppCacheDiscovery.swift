import Foundation

/// Rilevamento dinamico delle cache delle app installate dall'utente.
/// Nessun elenco fisso di app: le cache vengono riconosciute dalla loro struttura
/// (profili Chromium/Electron, contenitori sandbox) e dai file di configurazione delle app pro
/// (Adobe, DaVinci Resolve), che possono puntare anche a dischi esterni.
extension Scanner {
    /// Sottocartelle di un profilo Chromium/Electron interamente rigenerate dall'app al successivo avvio
    nonisolated static let chromiumCacheSubpaths: [String] = [
        "Cache", "Code Cache", "GPUCache", "DawnCache", "DawnGraphiteCache", "DawnWebGPUCache",
        "GrShaderCache", "ShaderCache", "Service Worker/CacheStorage", "Service Worker/ScriptCache"
    ]

    /// Cartelle che identificano con certezza un profilo Chromium/Electron
    nonisolated static let chromiumProfileMarkers: [String] = [
        "Code Cache", "GPUCache", "DawnCache", "DawnGraphiteCache", "DawnWebGPUCache", "GrShaderCache", "Cache/Cache_Data"
    ]

    nonisolated private static func normalizedName(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    /// Figli visibili di una cartella (i file nascosti come .DS_Store restano dove sono)
    nonisolated private static func visibleChildren(of dir: URL) -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isSymbolicLinkKey], options: []) else {
            return []
        }
        return items.filter { url in
            guard !url.lastPathComponent.hasPrefix(".") else { return false }
            return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink != true
        }
    }

    nonisolated private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    nonisolated static func measureInstalledAppCaches(
        progress: @escaping @Sendable (String, Int) -> Void
    ) -> (bytes: Int64, denied: Bool, topItems: [DiscoveredItem]) {
        let fm = FileManager.default
        let sandbox = MacSafetyIntelligence.sandboxRootURL
        let home = sandbox ?? fm.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")
        let appSupport = lib.appendingPathComponent("Application Support")
        let userCaches = lib.appendingPathComponent("Caches").standardizedFileURL.path
        let english = AppSettings.shared.language == .english
        func t(_ it: String, _ en: String) -> String { english ? en : it }

        let runningIds = MacSafetyIntelligence.activeRunningBundleIdentifiers()
        let runningNames = MacSafetyIntelligence.activeRunningAppNames()
        let installedApps = UninstallerEngine.scanApplicationsFolders()
            .filter { !$0.bundleId.lowercased().hasPrefix("com.apple.") }

        var items: [DiscoveredItem] = []
        var reported = 0
        var seenTargets: Set<String> = []

        func addItem(
            name: String,
            targets: [URL],
            note: String,
            selected: Bool = true,
            allowsUserContent: Bool = false,
            guardIds: [String] = [],
            chromiumProfile: String? = nil
        ) {
            var paths: [String] = []
            var bytes: Int64 = 0
            for url in targets {
                let p = url.standardizedFileURL.path
                guard !seenTargets.contains(p) else { continue }
                // Doppia protezione: mai cartelle di sistema o strutturali
                guard !MacSafetyIntelligence.isForbiddenToDelete(path: p, allowUserContent: allowsUserContent) else { continue }
                let b = UninstallerEngine.computeAllocatedSize(at: url)
                guard b > 0 else { continue }
                seenTargets.insert(p)
                paths.append(p)
                bytes += b
                reported += 1
                progress(p, reported)
            }
            guard bytes > 0, let first = paths.first else { return }
            items.append(
                DiscoveredItem(
                    name: name,
                    path: first,
                    targetPaths: paths,
                    safetyNote: note,
                    bytes: bytes,
                    isSelected: selected,
                    allowsUserContent: allowsUserContent,
                    liveGuard: LiveAppGuard(bundleIds: guardIds, chromiumProfileDir: chromiumProfile)
                )
            )
        }

        // ------------------------------------------------------------------
        // 1. Adobe (Premiere Pro, After Effects, Media Encoder, Audition)
        // ------------------------------------------------------------------
        let adobeInstalled = installedApps.contains { $0.bundleId.lowercased().hasPrefix("com.adobe.") }
        let adobeRunning = runningIds.contains { $0.hasPrefix("com.adobe.") }
        if !adobeRunning {
            let common = appSupport.appendingPathComponent("Adobe/Common")
            let mediaCaches: [(String, String, String)] = [
                ("Media Cache Files", "Adobe • Media Cache Files", "Audio conformato e file indicizzati • Rigenerati all'apertura dei progetti"),
                ("Media Cache", "Adobe • Database Media Cache", "Indici della cache media • Rigenerati automaticamente"),
                ("Peak Files", "Adobe • Peak Files", "Forme d'onda audio • Rigenerate automaticamente")
            ]
            for (folder, name, note) in mediaCaches {
                let dir = common.appendingPathComponent(folder)
                guard isDirectory(dir) else { continue }
                addItem(
                    name: name,
                    targets: visibleChildren(of: dir),
                    note: t(note, "Regenerable Adobe media cache"),
                    guardIds: ["com.adobe."]
                )
            }

            // Cache disco di After Effects: la posizione è scritta nelle preferenze (può essere su un disco esterno)
            if adobeInstalled {
                for folder in afterEffectsDiskCacheFolders(lib: lib) {
                    let folderURL = URL(fileURLWithPath: folder).standardizedFileURL
                    // Se è dentro ~/Library/Caches è già coperta dalla categoria "Cache Utente"
                    if folderURL.path == userCaches || folderURL.path.hasPrefix(userCaches + "/") { continue }
                    for cacheDir in afterEffectsDiskCacheDirectories(in: folderURL) {
                        addItem(
                            name: "After Effects • Disk Cache",
                            targets: visibleChildren(of: cacheDir),
                            note: t("Fotogrammi di anteprima in cache • Rigenerati durante l'anteprima", "Cached preview frames • Regenerated on preview"),
                            allowsUserContent: true,
                            guardIds: ["com.adobe."]
                        )
                    }
                }
            }
        }

        // ------------------------------------------------------------------
        // 2. DaVinci Resolve: CacheClip in ogni cartella di archiviazione media configurata
        // ------------------------------------------------------------------
        let resolveIds = ["com.blackmagic-design.davinciresolve", "com.blackmagic-design.davinciresolvelite", "com.blackmagic-design.davinciresolvestudio"]
        let resolveRunning = runningIds.contains { id in resolveIds.contains(id) }
        if !resolveRunning {
            let config = resolveMediaStorageConfig(lib: lib)
            var roots = config.roots
            if roots.isEmpty { roots = [home.appendingPathComponent("Movies").path] }
            for root in roots {
                let rootURL = URL(fileURLWithPath: root)
                let cacheClip = rootURL.appendingPathComponent(config.cacheDirName)
                if isDirectory(cacheClip) {
                    addItem(
                        name: "DaVinci Resolve • Render Cache (\(config.cacheDirName))",
                        targets: visibleChildren(of: cacheClip),
                        note: t("Cache di rendering • Rigenerata da Resolve quando serve", "Render cache • Regenerated by Resolve when needed"),
                        allowsUserContent: true,
                        guardIds: resolveIds
                    )
                }
                // Proxy e media ottimizzati: rigenerabili ma lunghi da ricreare -> mostrati ma NON preselezionati
                for (folder, label) in [("ProxyMedia", "Proxy Media"), ("OptimizedMedia", "Optimized Media")] {
                    let dir = rootURL.appendingPathComponent(folder)
                    guard isDirectory(dir) else { continue }
                    addItem(
                        name: "DaVinci Resolve • \(label)",
                        targets: visibleChildren(of: dir),
                        note: t("Rigenerabili, ma ricrearli può richiedere molto tempo", "Regenerable, but recreating them can take a long time"),
                        selected: false,
                        allowsUserContent: true,
                        guardIds: resolveIds
                    )
                }
            }
        }

        // ------------------------------------------------------------------
        // 3. App Electron / Chromium (Slack, Discord, VS Code, Claude, Spotify…): riconosciute dalla struttura
        // ------------------------------------------------------------------
        let appsByNorm: [String: InstalledApp] = {
            var map: [String: InstalledApp] = [:]
            for app in installedApps {
                map[normalizedName(app.name)] = map[normalizedName(app.name)] ?? app
                map[normalizedName(app.url.deletingPathExtension().lastPathComponent)] = map[normalizedName(app.url.deletingPathExtension().lastPathComponent)] ?? app
                if !app.bundleId.isEmpty { map[app.bundleId.lowercased()] = app }
            }
            return map
        }()

        for profile in visibleChildren(of: appSupport) where isDirectory(profile) {
            let folderName = profile.lastPathComponent
            let isChromiumProfile = chromiumProfileMarkers.contains { fm.fileExists(atPath: profile.appendingPathComponent($0).path) }
            guard isChromiumProfile else { continue }

            let norm = normalizedName(folderName)
            let owner = appsByNorm[norm] ?? appsByNorm[folderName.lowercased()]
            // App aperta: blocco di Chromium attivo, bundle ID o nome tra le app in esecuzione
            if MacSafetyIntelligence.chromiumProfileIsLocked(profile.path) { continue }
            if let owner, runningIds.contains(owner.bundleId.lowercased()) { continue }
            if runningNames.contains(norm) { continue }

            let targets = chromiumCacheSubpaths
                .map { profile.appendingPathComponent($0) }
                .filter { isDirectory($0) }
            addItem(
                name: "\(owner?.name ?? folderName) • " + t("cache app", "app cache"),
                targets: targets,
                note: t("Cache di codice, GPU e rete (Chromium/Electron) • Ricreate al prossimo avvio",
                        "Code, GPU and network caches (Chromium/Electron) • Recreated on next launch"),
                guardIds: owner.map { [$0.bundleId.lowercased()] } ?? [],
                chromiumProfile: profile.path
            )
        }

        // ------------------------------------------------------------------
        // 4. App sandbox (App Store e non): ~/Library/Containers/<id>/Data/Library/Caches
        //    Richiede l'Accesso Completo al Disco, altrimenti macOS chiederebbe un permesso per ogni app.
        // ------------------------------------------------------------------
        var denied = false
        if sandbox != nil || MacSafetyIntelligence.hasFullDiskAccess() {
            let containersRoot = lib.appendingPathComponent("Containers")
            for container in visibleChildren(of: containersRoot) where isDirectory(container) {
                let bid = container.lastPathComponent.lowercased()
                if bid.hasPrefix("com.apple.") { continue }
                if runningIds.contains(where: { $0 == bid || bid.hasPrefix($0 + ".") }) { continue }
                let cachesDir = container.appendingPathComponent("Data/Library/Caches")
                guard isDirectory(cachesDir) else { continue }
                let targets = visibleChildren(of: cachesDir).filter {
                    !MacSafetyIntelligence.shouldSkipItem(at: $0, insideDarwinTemp: false, runningIds: runningIds)
                }
                let owner = appsByNorm[bid] ?? installedApps.first { !$0.bundleId.isEmpty && bid.hasPrefix($0.bundleId.lowercased() + ".") }
                addItem(
                    name: "\(owner?.name ?? container.lastPathComponent) • " + t("cache sandbox", "sandbox cache"),
                    targets: targets,
                    note: t("Cache dell'app sandbox • macOS la considera eliminabile", "Sandboxed app cache • macOS treats it as purgeable"),
                    guardIds: [bid]
                )
            }
        } else {
            denied = true
        }

        // Ordina per dimensione; gli elementi non preselezionati restano sempre visibili singolarmente
        let sorted = items.sorted { $0.bytes > $1.bytes }
        let optional = sorted.filter { !$0.isSelected }
        let regular = sorted.filter { $0.isSelected }
        let maxVisible = 18
        var final = Array(regular.prefix(maxVisible))
        if regular.count > maxVisible {
            let tail = regular.dropFirst(maxVisible)
            let tailPaths = tail.flatMap(\.targetPaths)
            let tailBytes = tail.reduce(0) { $0 + $1.bytes }
            let guardIds = tail.flatMap { $0.liveGuard?.bundleIds ?? [] }
            if let first = tailPaths.first, tailBytes > 0 {
                final.append(
                    DiscoveredItem(
                        name: t("Altre cache di app (\(tail.count) app)", "Other app caches (\(tail.count) apps)"),
                        path: first,
                        targetPaths: tailPaths,
                        safetyNote: t("Cache rigenerabili di app minori", "Regenerable caches of smaller apps"),
                        bytes: tailBytes,
                        allowsUserContent: false,
                        liveGuard: LiveAppGuard(bundleIds: guardIds)
                    )
                )
            }
        }
        final.append(contentsOf: optional)
        let total = final.reduce(0) { $0 + $1.bytes }
        return (total, denied && total == 0, final)
    }

    // MARK: - Lettura configurazioni app pro

    /// Cartelle "Disk Cache" configurate nelle preferenze di tutte le versioni di After Effects
    nonisolated static func afterEffectsDiskCacheFolders(lib: URL) -> [String] {
        let prefsRoot = lib.appendingPathComponent("Preferences/Adobe/After Effects")
        var folders: Set<String> = []
        for versionDir in (try? FileManager.default.contentsOfDirectory(at: prefsRoot, includingPropertiesForKeys: nil)) ?? [] {
            let files = (try? FileManager.default.contentsOfDirectory(atPath: versionDir.path)) ?? []
            for file in files where file.hasPrefix("Adobe After Effects") && file.hasSuffix(" Prefs.txt") {
                guard let data = FileManager.default.contents(atPath: versionDir.appendingPathComponent(file).path),
                      let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { continue }
                var inSection = false
                for rawLine in text.replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n") {
                    let line = rawLine.trimmingCharacters(in: .whitespaces)
                    if line.hasPrefix("[") {
                        inSection = (line == "[\"Disk Cache Controls\"]")
                        continue
                    }
                    guard inSection, line.hasPrefix("\"Folder"),
                          let eq = line.range(of: "= \"") else { continue }
                    var value = String(line[eq.upperBound...])
                    if value.hasSuffix("\"") { value.removeLast() }
                    if value.hasPrefix("/") { folders.insert(value) }
                }
            }
        }
        return Array(folders)
    }

    /// After Effects crea dentro la cartella scelta una sottocartella "…Disk Cache…": la cerchiamo fino a due livelli
    nonisolated static func afterEffectsDiskCacheDirectories(in folder: URL) -> [URL] {
        var result: [URL] = []
        for child in visibleChildren(of: folder) where isDirectory(child) {
            if child.lastPathComponent.localizedCaseInsensitiveContains("disk cache") {
                result.append(child)
                continue
            }
            if ["adobe", "after effects"].contains(child.lastPathComponent.lowercased()) {
                for sub in visibleChildren(of: child) where isDirectory(sub) && sub.lastPathComponent.localizedCaseInsensitiveContains("disk cache") {
                    result.append(sub)
                }
            }
        }
        return result
    }

    /// Cartelle di archiviazione media e nome della cartella cache di DaVinci Resolve (da config.dat)
    nonisolated static func resolveMediaStorageConfig(lib: URL) -> (roots: [String], cacheDirName: String) {
        let configURL = lib.appendingPathComponent("Preferences/Blackmagic Design/DaVinci Resolve/config.dat")
        guard let data = FileManager.default.contents(atPath: configURL.path),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return ([], "CacheClip")
        }
        var roots: [String] = []
        var cacheDir = "CacheClip"
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let eq = line.range(of: " = ") else { continue }
            let key = line[..<eq.lowerBound]
            let value = String(line[eq.upperBound...]).trimmingCharacters(in: .whitespaces)
            if key.hasPrefix("Site.") && key.hasSuffix(".Root") && value.hasPrefix("/") {
                if !roots.contains(value) { roots.append(value) }
            } else if key == "RenderCaching.CacheDir" && !value.isEmpty && !value.contains("/") {
                cacheDir = value
            }
        }
        return (roots, cacheDir)
    }
}
