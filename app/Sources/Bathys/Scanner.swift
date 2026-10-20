import Foundation
import Observation
import AppKit

struct DiscoveredItem: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let targetPaths: [String]
    let safetyNote: String?
    let bytes: Int64
    var isSelected: Bool = true

    init(
        name: String,
        path: String,
        targetPaths: [String]? = nil,
        safetyNote: String? = nil,
        bytes: Int64,
        isSelected: Bool = true
    ) {
        self.name = name
        self.path = path
        self.targetPaths = targetPaths ?? [path]
        self.safetyNote = safetyNote
        self.bytes = bytes
        self.isSelected = isSelected
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

    /// Verifica se un elemento figlio dentro Caches, C o T deve essere protetto
    nonisolated static func shouldSkipItem(at url: URL, insideDarwinTemp: Bool, isGeneralCaches: Bool = false) -> Bool {
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
            let runningIds = activeRunningBundleIdentifiers()
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
@MainActor
final class Scanner: ObservableObject {
    @Published var categories: [ScanCategory]
    @Published var isScanning = false
    @Published var hasScanned = false
    @Published var isCleaning = false
    @Published var isResurfacing = false
    @Published var hasCleaned = false
    @Published var depth: Double = 0          // 0 = superficie (0%), 1 = fondale marino (100% completato)
    @Published var currentPath = ""
    @Published var startedAt: Date?
    @Published var resurfaceStartedAt: Date?
    @Published var lastCleanedBytes: Int64 = 0
    @Published var lastCleanedCount: Int = 0
    @Published var showCleanConfirmation = false

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

                let result = await Task.detached(priority: .userInitiated) {
                    Scanner.measure(urls) { path, count in
                        Task { @MainActor in
                            self.currentPath = path
                            let subRatio = min(0.85, Double(count) * 0.02)
                            self.depth = baseProgress + slice * (0.05 + subRatio)
                        }
                    }
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
        let fm = FileManager.default
        if let sandbox = MacSafetyIntelligence.sandboxRootURL {
            // In modalità sandbox di test: non spostare mai nulla fuori dalla cartella sandbox!
            guard url.standardizedFileURL.path.hasPrefix(sandbox.path) else { return false }
            return (try? fm.removeItem(at: url)) != nil
        }

        if isTrashCategory {
            return (try? fm.removeItem(at: url)) != nil
        }

        do {
            try fm.trashItem(at: url, resultingItemURL: nil)
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
            return recycled || !fm.fileExists(atPath: url.path)
        }
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

                for catIndex in selectedCats.indices {
                    guard selectedCats[catIndex].isSelected, selectedCats[catIndex].bytes > 0 else { continue }
                    let isTrashCategory = selectedCats[catIndex].id == "trash"

                    var remainingItems: [DiscoveredItem] = []
                    for item in selectedCats[catIndex].topItems {
                        if item.isSelected {
                            var failedPaths: [String] = []

                            for targetPath in item.targetPaths {
                                // Supporto per la compattazione nativa Apple symbolscache (coresymbolicationd)
                                if targetPath == "symbolscache://compact" {
                                    if MacSafetyIntelligence.sandboxRootURL == nil {
                                        let p = Process()
                                        p.executableURL = URL(fileURLWithPath: "/usr/bin/symbolscache")
                                        p.arguments = ["compact", "--free-capacity", "256"]
                                        try? p.run()
                                        p.waitUntilExit()
                                    }
                                    count += 1
                                    continue
                                }

                                // Controllo di sicurezza macOS assoluto: mai toccare cartelle di sistema o personali
                                guard !MacSafetyIntelligence.isForbiddenToDelete(path: targetPath) else {
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

                            if failedPaths.isEmpty {
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
                                            isSelected: item.isSelected
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/symbolscache")
        process.arguments = ["status"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: "\n") {
                    if line.contains("bytes total:") {
                        let parts = line.components(separatedBy: ":")
                        if parts.count > 1 {
                            let raw = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            let tokens = raw.split(separator: " ")
                            if tokens.count >= 2, let val = Double(tokens[0]) {
                                let unit = tokens[1].uppercased()
                                if unit.hasPrefix("GB") {
                                    return Int64(val * 1_000_000_000)
                                } else if unit.hasPrefix("MB") {
                                    return Int64(val * 1_000_000)
                                } else if unit.hasPrefix("KB") {
                                    return Int64(val * 1_000)
                                } else if unit.hasPrefix("B") {
                                    return Int64(val)
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            return 0
        }
        return 0
    }

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
        let darwinTempPath = (MacSafetyIntelligence.sandboxRootURL?.appendingPathComponent("var/folders/T") ?? fm.temporaryDirectory).standardizedFileURL.path

        for root in urls where fm.fileExists(atPath: root.path) {
            let stdRootPath = root.standardizedFileURL.path
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
                if MacSafetyIntelligence.shouldSkipItem(at: child, insideDarwinTemp: isDarwinTempRoot, isGeneralCaches: isGeneralCachesRoot) {
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

