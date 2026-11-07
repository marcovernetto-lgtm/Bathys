import Foundation
import Observation
import AppKit

/// Verifica eseguita di nuovo al momento della pulizia: se l'app proprietaria della cache è aperta, la cache non si tocca.
struct LiveAppGuard: Sendable {
    /// Bundle ID esatti, oppure prefissi terminanti con "." (es. "com.adobe.")
    var bundleIds: [String] = []
    /// Cartella profilo Chromium/Electron: se contiene un SingletonLock di un processo vivo, l'app è aperta
    var chromiumProfileDir: String? = nil

    nonisolated func isOwnerRunning(runningIds: Set<String>) -> Bool {
        for g in bundleIds {
            for r in runningIds where r == g || (g.hasSuffix(".") && r.hasPrefix(g)) || g.hasPrefix(r + ".") {
                return true
            }
        }
        if let dir = chromiumProfileDir, MacSafetyIntelligence.chromiumProfileIsLocked(dir) {
            return true
        }
        return false
    }
}

struct DiscoveredItem: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let targetPaths: [String]
    let safetyNote: String?
    let bytes: Int64
    var isSelected: Bool = true
    /// Consente di pulire cache che si trovano dentro le cartelle personali (es. ~/Movies/CacheClip di DaVinci Resolve)
    let allowsUserContent: Bool
    let liveGuard: LiveAppGuard?

    init(
        name: String,
        path: String,
        targetPaths: [String]? = nil,
        safetyNote: String? = nil,
        bytes: Int64,
        isSelected: Bool = true,
        allowsUserContent: Bool = false,
        liveGuard: LiveAppGuard? = nil
    ) {
        self.name = name
        self.path = path
        self.targetPaths = targetPaths ?? [path]
        self.safetyNote = safetyNote
        self.bytes = bytes
        self.isSelected = isSelected
        self.allowsUserContent = allowsUserContent
        self.liveGuard = liveGuard
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

struct ScanCategory: Identifiable {
    enum State { case idle, scanning, done, denied }

    let id: String
    let titleIT: String
    let titleEN: String
    let subtitleIT: String
    let subtitleEN: String
    let symbol: String
    let urls: [URL]
    var bytes: Int64 = 0
    var state: State = .idle
    var isExpanded: Bool = false
    var isSelected: Bool = true
    var topItems: [DiscoveredItem] = []

    var title: String {
        L10n.lang == .italian ? titleIT : titleEN
    }

    var subtitle: String {
        L10n.lang == .italian ? subtitleIT : subtitleEN
    }

    init(
        id: String,
        title: String,
        titleEN: String? = nil,
        subtitle: String,
        subtitleEN: String? = nil,
        symbol: String,
        urls: [URL]
    ) {
        self.id = id
        self.titleIT = title
        self.titleEN = titleEN ?? title
        self.subtitleIT = subtitle
        self.subtitleEN = subtitleEN ?? subtitle
        self.symbol = symbol
        self.urls = urls
    }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return (urls.first?.path ?? "").replacingOccurrences(of: home, with: "~")
    }

    var selectedBytes: Int64 {
        guard isSelected else { return 0 }
        if topItems.isEmpty { return bytes }
        return topItems.filter(\.isSelected).reduce(0) { $0 + $1.bytes }
    }
}

/// Regole di sicurezza macOS integrate per distinguere contenitori strutturali (0, C, T, X, Caches) da file eliminabili.
enum MacSafetyIntelligence {
    nonisolated static var sandboxRootURL: URL? {
        if let env = ProcessInfo.processInfo.environment["BATHYS_SANDBOX_ROOT"], !env.isEmpty {
            return URL(fileURLWithPath: env).standardizedFileURL
        }
        return nil
    }

    /// Servizi di sistema critici che non devono essere svuotati durante la pulizia ordinaria
    nonisolated static let protectedCacheIdentifiers: Set<String> = [
        "0",
        "X",
        "CloudKit",
        "com.apple.bird",
        "com.apple.LaunchServices",
        "FamilyCircle",
        "PassKit",
        "com.apple.nsurlsessiond",
        "com.apple.Safari.SafeBrowsing",
        "TemporaryItems",
        "com.apple.WorkflowKit.BackgroundShortcutRunner",
        "com.apple.shortcuts",
        "com.apple.shortcuts.runtime"
    ]

    /// Cartelle di cache di sviluppo o Xcode che hanno categorie dedicate e non devono essere duplicate nella scansione generica di Caches
    nonisolated static let specializedCacheIdentifiers: Set<String> = [
        "Homebrew", "pip", "pypoetry", "com.apple.dt.Xcode"
    ]

    /// Percorsi e cartelle di sistema assolutamente intoccabili da qualsiasi routine di pulizia
    nonisolated static func isForbiddenToDelete(path: String, allowUserContent: Bool = false) -> Bool {
        let p = (path as NSString).standardizingPath
        let home = sandboxRootURL?.path ?? FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path

        // Cartelle e radici di sistema macOS intoccabili
        let forbiddenPrefixes = [
            "/System", "/usr", "/bin", "/sbin", "/etc", "/var/db",
            "/private/var/db", "/Library/Apple", "/Library/SystemMigration"
        ]
        if forbiddenPrefixes.contains(where: { p == $0 || p.hasPrefix($0 + "/") }) { return true }

        // Root del sistema e cartella home dell'utente non possono MAI essere cancellate
        if p == "/" || p == home || p == "/Users" { return true }

        // Cartelle di primo livello del disco (/opt, /private, /cores, /Applications…) e home di altri utenti (/Users/nome)
        let rootComponents = p.split(separator: "/")
        if rootComponents.count == 1 { return true }
        if rootComponents.count == 2 && rootComponents[0] == "Users" { return true }

        // Root di volumi montati (non cancellare mai il punto di mount del disco!)
        if p.hasPrefix("/Volumes/") {
            let components = p.split(separator: "/")
            if components.count <= 2 {
                return true
            }
        }

        // Radici intoccabili: le cartelle principali stesse non devono MAI essere cancellate
        let protectedRoots: Set<String> = [
            "/Applications",
            "/Library",
            "/Users",
            home,
            home + "/Applications",
            home + "/Library",
            home + "/Documents",
            home + "/Desktop",
            home + "/Pictures",
            home + "/Music",
            home + "/Movies",
            home + "/Downloads"
        ]
        if protectedRoots.contains(p) { return true }

        // Cartelle dati personali dell'utente (documenti, foto, musica, video, download, scrivania)
        let personalDataFolders = [
            home + "/Documents",
            home + "/Desktop",
            home + "/Pictures",
            home + "/Music",
            home + "/Movies",
            home + "/Downloads"
        ]

        if !allowUserContent {
            // Per il cleaner automatico profondo: MAI toccare nulla dentro le cartelle personali dell'utente
            if personalDataFolders.contains(where: { p.hasPrefix($0 + "/") }) { return true }
            // Per il cleaner automatico: MAI toccare o modificare file dentro i pacchetti /Applications (preserva codesign Apple)
            if p.hasPrefix("/Applications/") || p.hasPrefix(home + "/Applications/") { return true }
        }

        // Cartelle strutturali di sistema in /var/folders (0 e X sono protette al 100%)
        if p.contains("/var/folders/") {
            let last = URL(fileURLWithPath: p).lastPathComponent
            if last == "0" || last == "X" { return true }
        }

        // Cartelle critiche e sensibili della Libreria utente / di sistema (password, keychain, messaggi, mail, safari)
        let sensitiveLibraryFolders = [
            "Keychains", "CloudKit", "Accounts", "IdentityServices",
            "Safari", "Mail", "Messages", "Preferences", "Cookies",
            "Group Containers", "ApplePushService", "HomeKit", "Calendars",
            "AddressBookSourceSync", "Biometrics", "CoreDuet", "PersonalizationPortrait",
            "com.apple.bird"
        ]
        for sensitive in sensitiveLibraryFolders {
            if p.contains("/Library/" + sensitive) || p.hasSuffix("/" + sensitive) {
                return true
            }
        }

        // Cartelle contenitore strutturali (non cancellare la cartella Caches o Logs in sé, solo il contenuto interno)
        let structuralContainers: Set<String> = [
            home + "/Library/Caches",
            "/Library/Caches",
            home + "/Library/Logs",
            "/Library/Logs",
            home + "/Library/Saved Application State",
            home + "/Library/WebKit",
            home + "/Library/HTTPStorages",
            home + "/.Trash",
            home + "/var/folders/T",
            home + "/var/folders/C"
        ]
        if structuralContainers.contains(p) { return true }

        return false
    }

    /// Estensioni audio/media tipiche dei file temporanei orfani lasciati in /var/folders/.../T
    nonisolated static let orphanMediaExtensions: Set<String> = [
        "aac", "m4a", "wav", "mp3", "caf", "aiff", "mp4", "mov"
    ]

    /// Rileva i Bundle Identifier delle applicazioni utente attualmente aperte sul Mac (escluse durante la pulizia automatica per evitare crash o perdita di sessione)
    nonisolated static func activeRunningBundleIdentifiers() -> Set<String> {
        guard sandboxRootURL == nil else { return [] }
        let apps = NSWorkspace.shared.runningApplications
        var ids: Set<String> = ["com.bathys.cleaner", "bathys"]
        for app in apps {
            if app.activationPolicy == .regular, let bid = app.bundleIdentifier?.lowercased(), !bid.isEmpty {
                ids.insert(bid)
            }
        }
        return ids
    }

    /// True se Bathys ha l'Accesso Completo al Disco (il database TCC dell'utente è leggibile solo in quel caso)
    nonisolated static func hasFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let tccDB = home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        if let handle = try? FileHandle(forReadingFrom: tccDB) {
            try? handle.close()
            return true
        }
        let canaries = ["Library/Safari", "Library/Mail", "Library/Messages", "Library/Suggestions", "Library/Cookies"]
        return canaries.contains { (try? FileManager.default.contentsOfDirectory(atPath: home.appendingPathComponent($0).path)) != nil }
    }

    /// Un profilo Chromium/Electron aperto contiene il link "SingletonLock" -> "nomehost-PID" di un processo vivo
    nonisolated static func chromiumProfileIsLocked(_ profileDir: String) -> Bool {
        let lock = (profileDir as NSString).appendingPathComponent("SingletonLock")
        guard let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: lock),
              let pidText = dest.split(separator: "-").last,
              let pid = Int32(pidText), pid > 0 else { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }

    /// Nomi normalizzati delle app aperte (nome visibile e nome del pacchetto .app)
    nonisolated static func activeRunningAppNames() -> Set<String> {
        guard sandboxRootURL == nil else { return [] }
        func norm(_ s: String) -> String { String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }) }
        var names: Set<String> = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let n = app.localizedName { names.insert(norm(n)) }
            if let u = app.bundleURL { names.insert(norm(u.deletingPathExtension().lastPathComponent)) }
        }
        names.remove("")
        return names
    }

    /// Verifica se un elemento figlio dentro Caches, C o T deve essere protetto
    nonisolated static func shouldSkipItem(
        at url: URL,
        insideDarwinTemp: Bool,
        isGeneralCaches: Bool = false,
        runningIds precomputedRunningIds: Set<String>? = nil
    ) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") && name != ".Trash" { return true }
        if protectedCacheIdentifiers.contains(name) { return true }
        if isGeneralCaches && specializedCacheIdentifiers.contains(name) { return true }
        if isForbiddenToDelete(path: url.path) { return true }
        let lowerName = name.lowercased()
        let lockSuffixes = [".lock", "-lock", ".lck", ".shm", "-shm", ".wal", "-wal", "-journal", ".pid", ".sock"]
        if lockSuffixes.contains(where: { lowerName.hasSuffix($0) }) { return true }

        // Protezione in tempo reale per le app attualmente aperte nel Dock (evita crash o disconnessioni di app in uso)
        if sandboxRootURL == nil {
            let runningIds = precomputedRunningIds ?? activeRunningBundleIdentifiers()
            if runningIds.contains(lowerName) || runningIds.contains(lowerName.replacingOccurrences(of: ".savedstate", with: "")) {
                return true
            }
        }

        // In /var/folders/.../T evitiamo di toccare file modificati negli ultimi 30 minuti
        // per non interrompere sessioni di app attualmente aperte.
        if insideDarwinTemp {
            if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               Date.now.timeIntervalSince(modDate) < 1800 {
                return true
            }
        }
        return false
    }
}

/// Motore Bathys Deep Scan: Analisi profonda di cache, cloni temporanei, artefatti di sviluppo e residui orfani.
@MainActor @Observable
final class Scanner {
    var categories: [ScanCategory]
    var isScanning = false
    var hasScanned = false
    var isCleaning = false
    var isResurfacing = false
    var hasCleaned = false
    var depth: Double = 0          // 0 = superficie (0%), 1 = fondale marino (100% completato)
    var currentPath = ""
    var startedAt: Date?
    var resurfaceStartedAt: Date?
    var lastCleanedBytes: Int64 = 0
    var lastCleanedCount: Int = 0
    var showCleanConfirmation = false

    var totalBytes: Int64 { categories.reduce(0) { $0 + $1.bytes } }
    var selectedBytes: Int64 { categories.reduce(0) { $0 + $1.selectedBytes } }

    /// Numero di applicazioni attualmente aperte nel Dock le cui sessioni attive vengono protette automaticamente
    var protectedRunningAppsCount: Int {
        NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }.count
    }

    init() {
        let fm = FileManager.default
        let sandbox = MacSafetyIntelligence.sandboxRootURL
        let home = sandbox ?? fm.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")
        let tempRoot = sandbox?.appendingPathComponent("var/folders/T") ?? fm.temporaryDirectory
        let cacheDarwinRoot = sandbox?.appendingPathComponent("var/folders/C") ?? fm.temporaryDirectory.deletingLastPathComponent().appendingPathComponent("C")

        var cachesURLs: [URL] = [
            lib.appendingPathComponent("Caches"),
            lib.appendingPathComponent("Application Support/Google/Chrome/Default/Service Worker/CacheStorage"),
            lib.appendingPathComponent("Application Support/Arc/User Data/Default/Service Worker/CacheStorage")
        ]
        if sandbox == nil {
            cachesURLs.insert(URL(fileURLWithPath: "/Library/Caches"), at: 1)
        }

        var logsURLs: [URL] = [
            lib.appendingPathComponent("Logs"),
            lib.appendingPathComponent("Logs/DiagnosticReports"),
            lib.appendingPathComponent("Application Support/CrashReporter")
        ]
        if sandbox == nil {
            logsURLs.insert(URL(fileURLWithPath: "/Library/Logs"), at: 1)
        }

        categories = [
            .init(
                id: "caches",
                title: "Cache Utente, Browser & App",
                titleEN: "User, Browser & App Caches",
                subtitle: "Svuota le cache di Safari, Chrome, Arc e app preservando le cartelle di sistema",
                subtitleEN: "Clear Safari, Chrome, Arc, and app caches while preserving system folders",
                symbol: "archivebox.fill",
                urls: cachesURLs
            ),
            .init(
                id: "appcaches",
                title: "Cache delle App Installate",
                titleEN: "Installed App Caches",
                subtitle: "After Effects, Premiere, DaVinci Resolve, app Electron e sandbox • Mai con l'app aperta",
                subtitleEN: "After Effects, Premiere, DaVinci Resolve, Electron and sandboxed apps • Never while the app is open",
                symbol: "square.stack.3d.up.fill",
                urls: [lib.appendingPathComponent("Application Support")]
            ),
            .init(
                id: "temp",
                title: "File Temporanei & Cache Darwin (C / T)",
                titleEN: "Temporary Files & Darwin Cache (C / T)",
                subtitle: "Pulisce il contenuto di /var/folders/T e C (es. .aac orfani) senza toccare 0, C, T, X",
                subtitleEN: "Clean /var/folders/T and C contents (e.g. orphaned .aac) without touching 0, C, T, X",
                symbol: "clock.arrow.circlepath",
                urls: [tempRoot, cacheDarwinRoot]
            ),
            .init(
                id: "dev",
                title: "Cache Sviluppo (Node, Cargo, Brew, Pip, Gradle)",
                titleEN: "Developer Caches (Node, Cargo, Brew, Pip, Gradle)",
                subtitle: "Pacchetti scaricati da npm, pnpm, bun, Rust Cargo, Homebrew e Python",
                subtitleEN: "Cached packages from npm, pnpm, bun, Rust Cargo, Homebrew, and Python",
                symbol: "terminal.fill",
                urls: [
                    home.appendingPathComponent(".npm/_cacache"),
                    home.appendingPathComponent(".pnpm-store"),
                    home.appendingPathComponent(".bun/install/cache"),
                    home.appendingPathComponent(".cargo/registry/cache"),
                    home.appendingPathComponent(".gradle/caches"),
                    lib.appendingPathComponent("Caches/Homebrew"),
                    lib.appendingPathComponent("Caches/pip"),
                    lib.appendingPathComponent("Caches/pypoetry")
                ]
            ),
            .init(
                id: "xcode",
                title: "Artefatti Xcode, DerivedData & Simulatori",
                titleEN: "Xcode Artifacts, DerivedData & Simulators",
                subtitle: "Build intermedi, simboli di debug iOS/macOS e cache CoreSimulator",
                subtitleEN: "Intermediate builds, iOS/macOS debug symbols, and CoreSimulator caches",
                symbol: "hammer.fill",
                urls: [
                    lib.appendingPathComponent("Developer/Xcode/DerivedData"),
                    lib.appendingPathComponent("Developer/Xcode/Archives"),
                    lib.appendingPathComponent("Developer/Xcode/iOS DeviceSupport"),
                    lib.appendingPathComponent("Developer/CoreSimulator/Caches"),
                    lib.appendingPathComponent("Caches/com.apple.dt.Xcode")
                ]
            ),
            .init(
                id: "logs",
                title: "Log di Sistema & Crash Report",
                titleEN: "System Logs & Crash Reports",
                subtitle: "Registri diagnostici obsoleti, report di crash e telemetria locale",
                subtitleEN: "Outdated diagnostic logs, crash reports, and local telemetry",
                symbol: "doc.text.fill",
                urls: logsURLs
            ),
            .init(
                id: "orphans",
                title: "Stati Sospesi & Cache WebKit/HTTP",
                titleEN: "Saved States & WebKit/HTTP Caches",
                subtitle: "Stati finestre salvati, storage HTTP e cache WebKit rigenerabili",
                subtitleEN: "Saved window states, HTTP storage, and regenerable WebKit caches",
                symbol: "puzzlepiece.extension.fill",
                urls: [
                    lib.appendingPathComponent("Saved Application State"),
                    lib.appendingPathComponent("WebKit"),
                    lib.appendingPathComponent("HTTPStorages")
                ]
            ),
            .init(
                id: "trash",
                title: "Cestino di macOS",
                titleEN: "macOS Trash",
                subtitle: "File già eliminati dall'utente in attesa di rimozione definitiva",
                subtitleEN: "Previously deleted user files awaiting permanent removal",
                symbol: "trash.fill",
                urls: [home.appendingPathComponent(".Trash")]
            )
        ]

        // Lo svuotamento del Cestino è definitivo e irreversibile: la categoria è disattivata di default
        // e deve essere scelta esplicitamente dall'utente.
        if let trashIdx = categories.firstIndex(where: { $0.id == "trash" }) {
            categories[trashIdx].isSelected = false
        }
    }

    /// True se tra gli elementi selezionati c'è il contenuto del Cestino (eliminazione definitiva)
    var includesPermanentTrashDeletion: Bool {
        categories.contains { $0.id == "trash" && $0.isSelected && $0.selectedBytes > 0 }
    }

    func scan() {
        guard !isScanning, !isCleaning else { return }
        isScanning = true
        hasScanned = false
        isResurfacing = false
        hasCleaned = false
        startedAt = .now
        depth = 0.0
        lastCleanedBytes = 0
        lastCleanedCount = 0

        for i in categories.indices {
            categories[i].bytes = 0
            categories[i].state = .idle
            categories[i].topItems = []
        }

        Task {
            let count = Double(categories.count)
            for i in categories.indices {
                // Rispetta la selezione pre-scansione: se l'utente ha escluso la categoria, non scansionarla
                guard categories[i].isSelected else {
                    categories[i].state = .done
                    depth = Double(i + 1) / count
                    continue
                }

                categories[i].state = .scanning
                let baseProgress = Double(i) / count
                let slice = 1.0 / count
                depth = baseProgress + slice * 0.05
                let begin = Date.now
                let urls = categories[i].urls
                let isAppCaches = categories[i].id == "appcaches"

                let result = await Task.detached(priority: .userInitiated) {
                    let report: @Sendable (String, Int) -> Void = { path, count in
                        Task { @MainActor in
                            self.currentPath = path
                            let subRatio = min(0.85, Double(count) * 0.02)
                            self.depth = baseProgress + slice * (0.05 + subRatio)
                        }
                    }
                    return isAppCaches
                        ? Scanner.measureInstalledAppCaches(progress: report)
                        : Scanner.measure(urls, progress: report)
                }.value

                let elapsed = Date.now.timeIntervalSince(begin)
                let minCategoryDuration: Double = 0.50
                if elapsed < minCategoryDuration {
                    try? await Task.sleep(for: .seconds(minCategoryDuration - elapsed))
                }

                categories[i].bytes = result.bytes
                categories[i].topItems = result.topItems
                categories[i].state = (result.denied && result.bytes == 0) ? .denied : .done
                depth = Double(i + 1) / count
            }

            depth = 1.0
            currentPath = ""
            isScanning = false
            hasScanned = true
            SoundManager.shared.playChime()
        }
    }

    nonisolated private static func safeTrashOrRemove(url: URL, isTrashCategory: Bool) -> Bool {
        // Nessun fallback su NSWorkspace.recycle nella pulizia massiva: eviterebbe attese di secondi
        // per ogni file protetto e potrebbe generare richieste di password a raffica dal Finder.
        SafeFileOps.moveToTrash(url, permanently: isTrashCategory, allowWorkspaceFallback: false)
    }

    /// Sposta in sicurezza gli elementi interni selezionati nel Cestino preservando sempre le cartelle strutturali (0, C, T, X, Caches, Logs).
    func cleanSelectedItems() {
        guard !isScanning, !isCleaning, selectedBytes > 0 else { return }
        isCleaning = true
        showCleanConfirmation = false

        let selectedCats = categories

        Task {
            // Esegui tutto il lavoro pesante di I/O (spostamento file, riciclo e ricalcoli) su un thread di background separato dal Main Thread
            let cleanResult = await Task.detached(priority: .userInitiated) { () -> (freed: Int64, count: Int, updates: [(index: Int, items: [DiscoveredItem], bytes: Int64)]) in
                var freed: Int64 = 0
                var count = 0
                var updatedCategories: [(index: Int, items: [DiscoveredItem], bytes: Int64)] = []

                // Stato delle app aperte rilevato ADESSO (non al momento della scansione)
                let runningNow = MacSafetyIntelligence.activeRunningBundleIdentifiers()

                for catIndex in selectedCats.indices {
                    guard selectedCats[catIndex].isSelected, selectedCats[catIndex].bytes > 0 else { continue }
                    let isTrashCategory = selectedCats[catIndex].id == "trash"

                    var remainingItems: [DiscoveredItem] = []
                    for item in selectedCats[catIndex].topItems {
                        if item.isSelected {
                            var failedPaths: [String] = []
                            var symbolsFreed: Int64 = 0
                            let isSymbolsCacheItem = item.targetPaths == ["symbolscache://compact"]
                            // Se nel frattempo l'utente ha aperto l'app proprietaria, la sua cache viene lasciata intatta
                            let ownerRunning = item.liveGuard?.isOwnerRunning(runningIds: runningNow) ?? false

                            if ownerRunning { failedPaths = item.targetPaths }
                            let pathsToProcess = ownerRunning ? [] : item.targetPaths

                            for targetPath in pathsToProcess {
                                // Supporto per la compattazione nativa Apple symbolscache (coresymbolicationd)
                                if targetPath == "symbolscache://compact" {
                                    if MacSafetyIntelligence.sandboxRootURL == nil {
                                        let before = Scanner.getSymbolscacheBytes()
                                        let result = SafeFileOps.runProcess("/usr/bin/symbolscache", ["compact", "--free-capacity", "256"], timeout: 120)
                                        let after = Scanner.getSymbolscacheBytes()
                                        if result?.status == 0 {
                                            count += 1
                                            // Conta solo lo spazio realmente recuperato dalla compattazione
                                            symbolsFreed += max(0, before - after)
                                        } else {
                                            failedPaths.append(targetPath)
                                        }
                                    }
                                    continue
                                }

                                // Controllo di sicurezza macOS assoluto: mai toccare cartelle di sistema o personali
                                guard !MacSafetyIntelligence.isForbiddenToDelete(path: targetPath, allowUserContent: item.allowsUserContent) else {
                                    failedPaths.append(targetPath)
                                    continue
                                }

                                let url = URL(fileURLWithPath: targetPath)
                                if Scanner.safeTrashOrRemove(url: url, isTrashCategory: isTrashCategory) {
                                    count += 1
                                } else {
                                    failedPaths.append(targetPath)
                                }
                            }

                            if isSymbolsCacheItem {
                                // La cache simboli non viene eliminata ma compattata: il valore rilevato è la sua dimensione totale
                                freed += symbolsFreed
                            } else if failedPaths.isEmpty {
                                freed += item.bytes
                            } else {
                                // Ricalcola la dimensione reale dei soli file che non è stato possibile rimuovere
                                let remainingBytes = failedPaths.reduce(Int64(0)) { acc, fp in
                                    acc + UninstallerEngine.computeAllocatedSize(at: URL(fileURLWithPath: fp))
                                }
                                let itemFreed = max(0, item.bytes - remainingBytes)
                                freed += itemFreed
                                if remainingBytes > 0 {
                                    remainingItems.append(
                                        DiscoveredItem(
                                            name: item.name,
                                            path: failedPaths[0],
                                            targetPaths: failedPaths,
                                            safetyNote: item.safetyNote,
                                            bytes: remainingBytes,
                                            isSelected: item.isSelected,
                                            allowsUserContent: item.allowsUserContent,
                                            liveGuard: item.liveGuard
                                        )
                                    )
                                }
                            }
                        } else {
                            remainingItems.append(item)
                        }
                    }

                    updatedCategories.append((index: catIndex, items: remainingItems, bytes: remainingItems.reduce(0) { $0 + $1.bytes }))
                }

                return (freed, count, updatedCategories)
            }.value

            // Pausa calibrata per consentire l'animazione visiva fluida di recupero
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            for update in cleanResult.updates {
                categories[update.index].topItems = update.items
                categories[update.index].bytes = update.bytes
            }

            lastCleanedBytes = cleanResult.freed
            lastCleanedCount = cleanResult.count
            isCleaning = false
            hasCleaned = true
            SoundManager.shared.playChime()

            // Sequenza di Riemersione: il batiscafo risale fluidamente verso la superficie
            isResurfacing = true
            resurfaceStartedAt = .now
            let totalAscentTime: Double = 2.0
            try? await Task.sleep(for: .seconds(totalAscentTime))

            self.depth = 0.0
            self.isResurfacing = false
            self.resurfaceStartedAt = nil
        }
    }

    nonisolated static func getSymbolscacheBytes() -> Int64 {
        if MacSafetyIntelligence.sandboxRootURL != nil { return 0 }
        guard let result = SafeFileOps.runProcess("/usr/bin/symbolscache", ["status"], timeout: 15),
              result.status == 0 else { return 0 }
        for line in result.output.components(separatedBy: "\n") where line.contains("bytes total:") {
            let parts = line.components(separatedBy: ":")
            guard parts.count > 1 else { continue }
            let tokens = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
            guard tokens.count >= 2, let val = Double(tokens[0].replacingOccurrences(of: ",", with: ".")) else { continue }
            let unit = tokens[1].uppercased()
            if unit.hasPrefix("TB") { return Int64(val * 1_000_000_000_000) }
            if unit.hasPrefix("GB") { return Int64(val * 1_000_000_000) }
            if unit.hasPrefix("MB") { return Int64(val * 1_000_000) }
            if unit.hasPrefix("KB") { return Int64(val * 1_000) }
            if unit.hasPrefix("B") { return Int64(val) }
        }
        return 0
    }

    /// Cartelle cache dei browser Chromium che non devono essere svuotate mentre il browser è aperto
    nonisolated private static let browserCacheRoots: [(pathFragment: String, bundleId: String)] = [
        ("Application Support/Google/Chrome/", "com.google.chrome"),
        ("Application Support/Arc/", "company.thebrowser.browser")
    ]

    nonisolated static func measure(
        _ urls: [URL],
        progress: @escaping @Sendable (String, Int) -> Void
    ) -> (bytes: Int64, denied: Bool, topItems: [DiscoveredItem]) {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]
        var total: Int64 = 0
        var denied = false
        var reportedCount = 0

        struct GroupBucket {
            var displayPath: String
            var targetPaths: [String]
            var safetyNote: String?
            var bytes: Int64
        }

        var childBuckets: [String: GroupBucket] = [:]
        var lastReport = DispatchTime.now()
        // Calcolato una sola volta per scansione (prima veniva interrogato NSWorkspace per ogni singolo file)
        let runningIds = MacSafetyIntelligence.activeRunningBundleIdentifiers()
        // Radici della stessa categoria: se una radice è contenuta in un'altra (es. Logs e Logs/DiagnosticReports)
        // la sottocartella viene contata solo una volta, evitando il doppio conteggio dei byte.
        let rootPaths = Set(urls.map { $0.standardizedFileURL.path })
        let darwinTempPath = (MacSafetyIntelligence.sandboxRootURL?.appendingPathComponent("var/folders/T") ?? fm.temporaryDirectory).standardizedFileURL.path

        for root in urls where fm.fileExists(atPath: root.path) {
            let stdRootPath = root.standardizedFileURL.path

            // Non toccare le cache di un browser Chromium mentre è aperto (rischio di corruzione del profilo)
            if MacSafetyIntelligence.sandboxRootURL == nil,
               let browser = browserCacheRoots.first(where: { stdRootPath.contains($0.pathFragment) }),
               runningIds.contains(browser.bundleId) {
                continue
            }

            let isDarwinTempRoot = stdRootPath == darwinTempPath || root.lastPathComponent == "T"
            let isDarwinCacheRoot = root.lastPathComponent == "C" && stdRootPath.contains("/var/folders/")
            let isGeneralCachesRoot = root.lastPathComponent == "Caches"

            guard let contents = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: Array(keys)) else {
                denied = true
                continue
            }

            // Raggruppatori dedicati per i file sciolti dentro /var/folders/.../T (come i file .aac orfani)
            var looseMediaPaths: [String] = []
            var looseMediaBytes: Int64 = 0
            var looseTempPaths: [String] = []
            var looseTempBytes: Int64 = 0

            for child in contents {
                if rootPaths.contains(child.standardizedFileURL.path) {
                    continue
                }
                if MacSafetyIntelligence.shouldSkipItem(
                    at: child,
                    insideDarwinTemp: isDarwinTempRoot,
                    isGeneralCaches: isGeneralCachesRoot,
                    runningIds: runningIds
                ) {
                    continue
                }

                // Ignora link simbolici per prevenire cicli o eliminazioni fuori perimetro
                if (try? child.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
                    continue
                }

                var childBytes: Int64 = 0
                var isDir: ObjCBool = false
                let exists = fm.fileExists(atPath: child.path, isDirectory: &isDir)
                guard exists else { continue }

                if !isDir.boolValue {
                    if let v = try? child.resourceValues(forKeys: keys) {
                        childBytes = Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? v.fileSize ?? 0)
                    }
                    guard childBytes > 0 else { continue }
                    total += childBytes

                    if isDarwinTempRoot {
                        let ext = child.pathExtension.lowercased()
                        if MacSafetyIntelligence.orphanMediaExtensions.contains(ext) {
                            looseMediaPaths.append(child.path)
                            looseMediaBytes += childBytes
                        } else {
                            looseTempPaths.append(child.path)
                            looseTempBytes += childBytes
                        }
                        continue
                    }
                } else if let walker = fm.enumerator(
                    at: child,
                    includingPropertiesForKeys: Array(keys),
                    options: [],
                    errorHandler: { _, _ in true }
                ) {
                    for case let url as URL in walker {
                        guard let v = try? url.resourceValues(forKeys: keys) else { continue }
                        if v.isSymbolicLink == true {
                            walker.skipDescendants()
                            continue
                        }
                        guard v.isRegularFile == true else { continue }
                        let b = Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? v.fileSize ?? 0)
                        childBytes += b
                        total += b

                        let now = DispatchTime.now()
                        if now.uptimeNanoseconds - lastReport.uptimeNanoseconds > 150_000_000 {
                            lastReport = now
                            reportedCount += 1
                            progress(url.path, reportedCount)
                        }
                    }
                }

                guard childBytes > 0 else { continue }

                let note: String? = isDarwinTempRoot
                    ? "Cartella temporanea in /var/folders/T (la cartella T viene preservata)"
                    : (isDarwinCacheRoot ? "Cache Darwin in /var/folders/C (la cartella C viene preservata)" : (root.path.hasPrefix("/Library") ? "Cache o registri di sistema macOS • Rigenerabili" : nil))

                let key = child.lastPathComponent
                if var existing = childBuckets[key] {
                    existing.targetPaths.append(child.path)
                    existing.bytes += childBytes
                    childBuckets[key] = existing
                } else {
                    childBuckets[key] = GroupBucket(
                        displayPath: child.path,
                        targetPaths: [child.path],
                        safetyNote: note,
                        bytes: childBytes
                    )
                }
            }

            // Aggiungi il gruppo di file audio/media orfani (.aac, ecc.) trovati in /var/folders/.../T
            if !looseMediaPaths.isEmpty && looseMediaBytes > 0 {
                let label = "File audio e media orfani in /var/folders/T (\(looseMediaPaths.count) file)"
                childBuckets[label] = GroupBucket(
                    displayPath: looseMediaPaths[0],
                    targetPaths: looseMediaPaths,
                    safetyNote: "Sicuri da rimuovere • Preserva la cartella strutturale T",
                    bytes: looseMediaBytes
                )
            }

            // Aggiungi il gruppo di altri file temporanei sciolti trovati in /var/folders/.../T
            if !looseTempPaths.isEmpty && looseTempBytes > 0 {
                let label = "File temporanei sciolti in /var/folders/T (\(looseTempPaths.count) file)"
                childBuckets[label] = GroupBucket(
                    displayPath: looseTempPaths[0],
                    targetPaths: looseTempPaths,
                    safetyNote: "Inattivi da oltre 30 min • Preserva la cartella strutturale T",
                    bytes: looseTempBytes
                )
            }
        }

        // Rilevamento automatico della cache di debug simboli macOS (coresymbolicationd)
        let isCachesCategory = urls.contains { $0.lastPathComponent == "Caches" && $0.path.contains("Library") }
        if isCachesCategory {
            let scBytes = Scanner.getSymbolscacheBytes()
            if scBytes > 0 {
                total += scBytes
                childBuckets["com.apple.coresymbolicationd"] = GroupBucket(
                    displayPath: "/System/Library/Caches/com.apple.coresymbolicationd",
                    targetPaths: ["symbolscache://compact"],
                    safetyNote: "Cache simboli di debug Apple gestita da coresymbolicationd • Compattazione nativa",
                    bytes: scBytes
                )
            }
        }

        let allSorted = childBuckets.map {
            DiscoveredItem(
                name: $0.key,
                path: $0.value.displayPath,
                targetPaths: $0.value.targetPaths,
                safetyNote: $0.value.safetyNote,
                bytes: $0.value.bytes
            )
        }
        .sorted { $0.bytes > $1.bytes }

        // Mostra i primi 14 elementi più pesanti e raggruppa tutti i rimanenti in una voce cumulativa,
        // così il 100% dello spazio rilevato è controllabile ed effettivamente pulito!
        let maxVisible = 14
        var finalItems = Array(allSorted.prefix(maxVisible))
        if allSorted.count > maxVisible {
            let tail = allSorted.dropFirst(maxVisible)
            let tailBytes = tail.reduce(0) { $0 + $1.bytes }
            let tailPaths = tail.flatMap(\.targetPaths)
            if tailBytes > 0 && !tailPaths.isEmpty {
                finalItems.append(
                    DiscoveredItem(
                        name: "Altri elementi minori (\(tailPaths.count) elementi)",
                        path: tailPaths[0],
                        targetPaths: tailPaths,
                        safetyNote: "Sottocartelle e file di cache secondari",
                        bytes: tailBytes
                    )
                )
            }
        }

        let measuredTotal = finalItems.reduce(0) { $0 + $1.bytes }
        return (measuredTotal, denied, finalItems)
    }
}

