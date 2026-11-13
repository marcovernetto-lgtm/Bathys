import Foundation
import Observation
import AppKit
import Darwin

struct OptimizationTaskItem: Identifiable {
    enum Status { case ready, running, completed(String), failed(String) }

    let id: String
    let titleIT: String
    let titleEN: String
    let subtitleIT: String
    let subtitleEN: String
    let symbol: String
    var isSelected: Bool = true
    var status: Status = .ready

    var title: String {
        AppSettings.shared.language == .english ? titleEN : titleIT
    }

    var subtitle: String {
        AppSettings.shared.language == .english ? subtitleEN : subtitleIT
    }
}

struct LaunchAgentItem: Identifiable, Sendable {
    let id: String // path
    let label: String
    let executablePath: String
    let plistPath: String
    let runAtLoad: Bool
    let isUserAgent: Bool
    let isOrphaned: Bool // True se l'eseguibile puntato dal plist non esiste più sul disco

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return plistPath.replacingOccurrences(of: home, with: "~")
    }
}

/// Motore Bathys Optimizer: Telemetria macOS in tempo reale, audit LaunchAgents orfani e manutenzione di sistema.
@MainActor @Observable
final class OptimizerEngine {
    var tasks: [OptimizationTaskItem] = [
        .init(
            id: "quicklook",
            titleIT: "Anteprime dei file",
            titleEN: "File previews",
            subtitleIT: "Ripristina le miniature dei file bloccate o non aggiornate",
            subtitleEN: "Resets stuck or outdated file thumbnails across Finder",
            symbol: "eye"
        ),
        .init(
            id: "dns",
            titleIT: "Connessione di rete",
            titleEN: "Network connection",
            subtitleIT: "Aggiorna la risoluzione dei domini e velocizza le connessioni di rete",
            subtitleEN: "Refreshes domain resolution and speeds up network lookups",
            symbol: "network"
        ),
        .init(
            id: "savedstate",
            titleIT: "Finestre dimenticate",
            titleEN: "Forgotten windows",
            subtitleIT: "Rimuove i salvataggi automatici delle finestre più vecchi di 30 giorni",
            subtitleEN: "Removes saved application window states older than 30 days",
            symbol: "macwindow"
        ),
        .init(
            id: "dsstore",
            titleIT: "Ordine delle cartelle",
            titleEN: "Folder views",
            subtitleIT: "Ripristina l'ordine di visualizzazione nelle cartelle Download e Documenti",
            subtitleEN: "Resets folder view metadata in Downloads, Documents, and Desktop",
            symbol: "square.grid.2x2"
        ),
        .init(
            id: "brokenplist",
            titleIT: "Impostazioni danneggiate",
            titleEN: "Damaged settings",
            subtitleIT: "Individua e rimuove i file di configurazione vuoti o corrotti",
            subtitleEN: "Finds and removes 0-byte or malformed .plist preference files",
            symbol: "wrench.and.screwdriver"
        )
    ]

    var launchAgents: [LaunchAgentItem] = []
    var isRunningTasks = false
    var isScanningAgents = false

    // Telemetria Hardware
    var diskTotalBytes: Int64 = 0
    var diskFreeBytes: Int64 = 0
    var ramTotalBytes: UInt64 = 0
    var ramUsedBytes: UInt64 = 0
    var cpuCores: Int = 8

    var diskUsedFraction: Double {
        guard diskTotalBytes > 0 else { return 0 }
        return Double(diskTotalBytes - diskFreeBytes) / Double(diskTotalBytes)
    }

    var ramUsedFraction: Double {
        guard ramTotalBytes > 0 else { return 0 }
        return Double(ramUsedBytes) / Double(ramTotalBytes)
    }

    var orphanedAgentsCount: Int {
        launchAgents.filter { $0.isOrphaned }.count
    }

    init() {
        refreshTelemetry()
    }

    func refreshTelemetry() {
        let info = ProcessInfo.processInfo
        ramTotalBytes = info.physicalMemory
        cpuCores = info.activeProcessorCount

        // Leggi RAM attiva + wired + compressa tramite Mach host_statistics64
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let active = UInt64(stats.active_count) * pageSize
            let wired = UInt64(stats.wire_count) * pageSize
            let compressed = UInt64(stats.compressor_page_count) * pageSize
            ramUsedBytes = min(ramTotalBytes, active + wired + compressed)
        } else {
            ramUsedBytes = ramTotalBytes / 2
        }

        // Leggi spazio disco APFS
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        if let values = try? homeURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            diskTotalBytes = Int64(values.volumeTotalCapacity ?? 0)
            diskFreeBytes = values.volumeAvailableCapacityForImportantUsage ?? 0
        }
    }

    // MARK: - Avviso disco quasi pieno

    var lowDiskThresholdBytes: Int64 {
        Int64(AppSettings.shared.lowDiskThresholdGB) * 1_000_000_000
    }

    /// True se lo spazio libero è sotto la soglia scelta nelle Impostazioni
    var isDiskLow: Bool {
        AppSettings.shared.lowDiskWarningEnabled && diskFreeBytes > 0 && diskFreeBytes < lowDiskThresholdBytes
    }

    /// Aggiorna lo spazio libero e, se è sotto la soglia, manda una notifica di sistema
    /// (al massimo una ogni 6 ore, per non insistere a ogni ritorno sulla finestra).
    func checkLowDiskSpace() {
        refreshTelemetry()
        guard isDiskLow, MacSafetyIntelligence.sandboxRootURL == nil,
              !CommandLine.arguments.contains("--self-test") else { return }
        let key = "bathys_lowdisk_last_notified"
        let last = UserDefaults.standard.object(forKey: key) as? Date ?? .distantPast
        guard Date.now.timeIntervalSince(last) > 6 * 3600 else { return }
        UserDefaults.standard.set(Date.now, forKey: key)

        let italian = AppSettings.shared.language == .italian
        let free = ByteCountFormatter.string(fromByteCount: diskFreeBytes, countStyle: .file)
        SoundManager.shared.postSystemNotification(
            title: italian ? "Bathys • Disco quasi pieno" : "Bathys • Disk almost full",
            body: italian
                ? "Restano solo \(free) liberi (soglia \(AppSettings.shared.lowDiskThresholdGB) GB). Libera spazio prima di render o export pesanti."
                : "Only \(free) left (threshold \(AppSettings.shared.lowDiskThresholdGB) GB). Free up space before heavy renders or exports."
        )
    }

    func scanLaunchAgents() {
        guard !isScanningAgents else { return }
        isScanningAgents = true

        Task {
            let discovered = await Task.detached(priority: .userInitiated) {
                OptimizerEngine.discoverLaunchAgents()
            }.value
            self.launchAgents = discovered
            self.isScanningAgents = false
            self.refreshTelemetry()
        }
    }

    /// Scarica l'agente da launchd (solo agenti utente) e sposta il suo plist nel Cestino.
    /// Restituisce false se il file non è stato rimosso (es. permessi insufficienti).
    @discardableResult
    func removeLaunchAgent(_ agent: LaunchAgentItem) -> Bool {
        let url = URL(fileURLWithPath: agent.plistPath)
        if agent.isUserAgent {
            UninstallerEngine.unloadUserLaunchAgentIfNeeded(at: url)
        }
        guard SafeFileOps.moveToTrash(url) else { return false }
        CleanupHistory.shared.commitPending(module: .optimizer, title: "Elemento di avvio \(agent.label)", freedBytes: 0)
        launchAgents.removeAll { $0.id == agent.id }
        return true
    }

    func runSelectedOptimizations() {
        guard !isRunningTasks else { return }
        isRunningTasks = true

        Task {
            for i in tasks.indices where tasks[i].isSelected {
                tasks[i].status = .running
                let taskId = tasks[i].id

                let english = AppSettings.shared.language == .english
                let outcome = await Task.detached(priority: .userInitiated) {
                    OptimizerEngine.executeTask(id: taskId, english: english)
                }.value

                try? await Task.sleep(for: .milliseconds(350))
                tasks[i].status = outcome.success ? .completed(outcome.message) : .failed(outcome.message)
            }

            refreshTelemetry()
            isRunningTasks = false
            SoundManager.shared.playChime()
        }
    }

    // MARK: - Task Handlers (Native macOS Optimization Routines)

    struct TaskOutcome: Sendable {
        let success: Bool
        let message: String
    }

    nonisolated static func executeTask(id: String, english: Bool = false) -> TaskOutcome {
        func ok(_ it: String, _ en: String) -> TaskOutcome { TaskOutcome(success: true, message: english ? en : it) }
        func fail(_ it: String, _ en: String) -> TaskOutcome { TaskOutcome(success: false, message: english ? en : it) }
        let fm = FileManager.default
        let sandbox = MacSafetyIntelligence.sandboxRootURL
        let home = sandbox ?? fm.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")

        func safeRemoveOrTrash(_ item: URL) -> Bool {
            // Manutenzione (.DS_Store, plist corrotti, stati finestra): non serve in cronologia
            SafeFileOps.moveToTrash(item, record: false)
        }

        switch id {
        case "quicklook":
            if sandbox == nil {
                let reset = SafeFileOps.runProcess("/usr/bin/qlmanage", ["-r", "cache"], timeout: 30)
                SafeFileOps.runProcess("/usr/bin/qlmanage", ["-r"], timeout: 30)
                guard reset?.status == 0 else {
                    return fail("Impossibile rigenerare la cache miniature", "Could not reset the thumbnail cache")
                }
            }
            return ok("Cache miniature rigenerata", "Thumbnail cache rebuilt")

        case "dns":
            if sandbox == nil {
                // Il vero svuotamento della cache DNS richiede i privilegi di amministratore (mDNSResponder):
                // macOS mostra la propria finestra di autenticazione, Bathys non vede mai la password.
                let script = "do shell script \"/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder\" with administrator privileges"
                guard let result = SafeFileOps.runProcess("/usr/bin/osascript", ["-e", script], timeout: 120) else {
                    return fail("Impossibile avviare lo svuotamento DNS", "Could not start the DNS flush")
                }
                if result.status != 0 {
                    return result.output.contains("-128")
                        ? fail("Annullato dall'utente", "Cancelled by user")
                        : fail("Svuotamento DNS non riuscito", "DNS flush failed")
                }
            }
            return ok("Cache DNS svuotata", "DNS cache flushed")

        case "savedstate":
            let stateDir = lib.appendingPathComponent("Saved Application State")
            var removed = 0
            let cutoff = Date.now.addingTimeInterval(-30 * 24 * 3600)
            let runningIds = MacSafetyIntelligence.activeRunningBundleIdentifiers()
            if let items = try? fm.contentsOfDirectory(at: stateDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
                for item in items {
                    // Mai toccare lo stato di un'app attualmente aperta
                    let bid = item.lastPathComponent.lowercased().replacingOccurrences(of: ".savedstate", with: "")
                    if runningIds.contains(bid) { continue }
                    if let mod = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                       mod < cutoff {
                        if safeRemoveOrTrash(item) {
                            removed += 1
                        }
                    }
                }
            }
            return removed > 0
                ? ok("\(removed) stati obsoleti rimossi", "\(removed) stale states removed")
                : ok("Nessuno stato obsoleto (>30g)", "No stale states (>30d)")

        case "dsstore":
            let targets = [
                home.appendingPathComponent("Downloads"),
                home.appendingPathComponent("Documents"),
                home.appendingPathComponent("Desktop")
            ]
            var removed = 0
            for dir in targets {
                let ds = dir.appendingPathComponent(".DS_Store")
                if fm.fileExists(atPath: ds.path), safeRemoveOrTrash(ds) {
                    removed += 1
                }
            }
            return removed > 0
                ? ok("\(removed) file .DS_Store rimossi", "\(removed) .DS_Store files removed")
                : ok("Cartelle già pulite", "Folders already clean")

        case "brokenplist":
            let prefDir = lib.appendingPathComponent("Preferences")
            var repaired = 0
            if let items = try? fm.contentsOfDirectory(at: prefDir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) {
                for item in items where item.pathExtension == "plist" {
                    let values = try? item.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    // Un plist appena modificato potrebbe essere in fase di scrittura da cfprefsd: non giudicarlo
                    if let mod = values?.contentModificationDate, Date.now.timeIntervalSince(mod) < 60 { continue }
                    let size = values?.fileSize ?? 0
                    var isBroken = (size == 0)
                    if !isBroken, let data = try? Data(contentsOf: item, options: .mappedIfSafe) {
                        isBroken = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) == nil
                    }
                    if isBroken {
                        if safeRemoveOrTrash(item) {
                            repaired += 1
                        }
                    }
                }
            }
            return repaired > 0
                ? ok("\(repaired) plist corrotti rimossi", "\(repaired) corrupted plists removed")
                : ok("Tutti i plist sono integri", "All plists are valid")

        default:
            return ok("Completato", "Completed")
        }
    }

    nonisolated static func discoverLaunchAgents() -> [LaunchAgentItem] {
        let fm = FileManager.default
        let sandbox = MacSafetyIntelligence.sandboxRootURL
        let home = sandbox ?? fm.homeDirectoryForCurrentUser
        let dirs: [(URL, Bool)]
        if sandbox != nil {
            dirs = [
                (home.appendingPathComponent("Library/LaunchAgents"), true),
                (home.appendingPathComponent("SystemLibrary/LaunchAgents"), false)
            ]
        } else {
            dirs = [
                (home.appendingPathComponent("Library/LaunchAgents"), true),
                (URL(fileURLWithPath: "/Library/LaunchAgents"), false)
            ]
        }

        var items: [LaunchAgentItem] = []

        for (dir, isUser) in dirs where fm.fileExists(atPath: dir.path) {
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.pathExtension == "plist" {
                guard let dict = NSDictionary(contentsOf: file) as? [String: Any] else { continue }
                let label = (dict["Label"] as? String) ?? file.deletingPathExtension().lastPathComponent
                let runAtLoad = (dict["RunAtLoad"] as? Bool) ?? false

                var execPath = ""
                if let prog = dict["Program"] as? String {
                    execPath = prog
                } else if let args = dict["ProgramArguments"] as? [String], let first = args.first {
                    execPath = first
                }

                // Verifica se il binario esiste sul disco per identificare agenti orfani
                var isOrphaned = false
                if !execPath.isEmpty && execPath.hasPrefix("/") {
                    isOrphaned = !fm.fileExists(atPath: execPath)
                }

                items.append(
                    LaunchAgentItem(
                        id: file.path,
                        label: label,
                        executablePath: execPath.isEmpty ? "Servizio di sistema / XPC" : execPath,
                        plistPath: file.path,
                        runAtLoad: runAtLoad,
                        isUserAgent: isUser,
                        isOrphaned: isOrphaned
                    )
                )
            }
        }

        // Metti in cima gli agenti orfani (da pulire), poi gli agenti utente
        items.sort {
            if $0.isOrphaned != $1.isOrphaned { return $0.isOrphaned && !$1.isOrphaned }
            if $0.isUserAgent != $1.isUserAgent { return $0.isUserAgent && !$1.isUserAgent }
            return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
        return items
    }
}
