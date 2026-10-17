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
            titleIT: "Rigenera anteprime QuickLook e icone Finder",
            titleEN: "Rebuild QuickLook Previews & Finder Icons",
            subtitleIT: "Ripristina le miniature dei file bloccate o non aggiornate",
            subtitleEN: "Resets stuck or outdated file thumbnails across Finder",
            symbol: "eye"
        ),
        .init(
            id: "dns",
            titleIT: "Svuota cache DNS locale",
            titleEN: "Flush Local DNS Cache",
            subtitleIT: "Aggiorna la risoluzione dei domini e velocizza le connessioni di rete",
            subtitleEN: "Refreshes domain resolution and speeds up network lookups",
            symbol: "network"
        ),
        .init(
            id: "savedstate",
            titleIT: "Pulisci stati finestre obsoleti",
            titleEN: "Purge Stale Window States",
            subtitleIT: "Rimuove i salvataggi automatici delle finestre più vecchi di 30 giorni",
            subtitleEN: "Removes saved application window states older than 30 days",
            symbol: "macwindow"
        ),
        .init(
            id: "dsstore",
            titleIT: "Rimuovi file di vista .DS_Store",
            titleEN: "Clean .DS_Store View Files",
            subtitleIT: "Ripristina l'ordine di visualizzazione nelle cartelle Download e Documenti",
            subtitleEN: "Resets folder view metadata in Downloads, Documents, and Desktop",
            symbol: "square.grid.2x2"
        ),
        .init(
            id: "brokenplist",
            titleIT: "Ripara file di preferenze danneggiati",
            titleEN: "Repair Corrupted Preference Files",
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

    func removeLaunchAgent(_ agent: LaunchAgentItem) {
        let url = URL(fileURLWithPath: agent.plistPath)
        let fm = FileManager.default
        if let sandbox = MacSafetyIntelligence.sandboxRootURL {
            let sbPath = (sandbox.path as NSString).standardizingPath
            let targetPath = (url.path as NSString).standardizingPath
            guard targetPath.hasPrefix(sbPath + "/") else { return }
            if (try? fm.removeItem(at: url)) != nil {
                launchAgents.removeAll { $0.id == agent.id }
            }
            return
        }
        do {
            try fm.trashItem(at: url, resultingItemURL: nil)
            launchAgents.removeAll { $0.id == agent.id }
        } catch {}
    }

    func runSelectedOptimizations() {
        guard !isRunningTasks else { return }
        isRunningTasks = true

        Task {
            for i in tasks.indices where tasks[i].isSelected {
                tasks[i].status = .running
                let taskId = tasks[i].id

                let outcome = await Task.detached(priority: .userInitiated) {
                    OptimizerEngine.executeTask(id: taskId)
                }.value

                try? await Task.sleep(for: .milliseconds(350))
                tasks[i].status = .completed(outcome)
            }

            refreshTelemetry()
            isRunningTasks = false
            SoundManager.shared.playChime()
        }
    }

    // MARK: - Task Handlers (Native macOS Optimization Routines)

    nonisolated static func executeTask(id: String) -> String {
        let fm = FileManager.default
        let sandbox = MacSafetyIntelligence.sandboxRootURL
        let home = sandbox ?? fm.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")

        func safeRemoveOrTrash(_ item: URL) -> Bool {
            if let sb = sandbox {
                let sbPath = (sb.path as NSString).standardizingPath
                let targetPath = (item.path as NSString).standardizingPath
                guard targetPath.hasPrefix(sbPath + "/") else { return false }
                return (try? fm.removeItem(at: item)) != nil
            }
            return (try? fm.trashItem(at: item, resultingItemURL: nil)) != nil
        }

        switch id {
        case "quicklook":
            if sandbox == nil {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
                proc.arguments = ["-r", "cache"]
                proc.standardOutput = Pipe()
                proc.standardError = Pipe()
                try? proc.run()
                proc.waitUntilExit()
            }
            return "Cache miniature rigenerata"

        case "dns":
            if sandbox == nil {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
                proc.arguments = ["-flushcache"]
                proc.standardOutput = Pipe()
                proc.standardError = Pipe()
                try? proc.run()
                proc.waitUntilExit()
            }
            return "Cache DNS svuotata"

        case "savedstate":
            let stateDir = lib.appendingPathComponent("Saved Application State")
            var removed = 0
            let cutoff = Date.now.addingTimeInterval(-30 * 24 * 3600)
            if let items = try? fm.contentsOfDirectory(at: stateDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
                for item in items {
                    if let mod = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                       mod < cutoff {
                        if safeRemoveOrTrash(item) {
                            removed += 1
                        }
                    }
                }
            }
            return removed > 0 ? "\(removed) stati obsoleti rimossi" : "Nessuno stato obsoleto (>30g)"

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
            return removed > 0 ? "\(removed) file .DS_Store rimossi" : "Cartelle già pulite"

        case "brokenplist":
            let prefDir = lib.appendingPathComponent("Preferences")
            var repaired = 0
            if let items = try? fm.contentsOfDirectory(at: prefDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for item in items where item.pathExtension == "plist" {
                    let size = (try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
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
            return repaired > 0 ? "\(repaired) plist corrotti rimossi" : "Tutti i plist sono integri"

        default:
            return "Completato"
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
