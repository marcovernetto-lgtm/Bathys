import Foundation
import Observation
import AppKit

/// Un elemento spostato nel Cestino da Bathys
struct TrashRecord: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    let originalPath: String
    /// Posizione nel Cestino (nil se lo ha spostato il Finder e non ne conosciamo il nome finale)
    let trashedPath: String?
    var restoredAt: Date? = nil

    var name: String { (originalPath as NSString).lastPathComponent }

    var displayOriginalPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return originalPath.replacingOccurrences(of: home, with: "~")
    }
}

/// Un'operazione completata (una pulizia, una disinstallazione…) con gli elementi che ha cestinato
struct CleanupEntry: Codable, Identifiable, Sendable {
    enum Module: String, Codable, Sendable {
        case deepClean, uninstaller, sonar, optimizer

        var symbol: String {
            switch self {
            case .deepClean: return "sparkles"
            case .uninstaller: return "trash.fill"
            case .sonar: return "dot.radiowaves.left.and.right"
            case .optimizer: return "bolt.fill"
            }
        }

        func title(italian: Bool) -> String {
            switch self {
            case .deepClean: return italian ? "Scansione Profonda" : "Deep Scan"
            case .uninstaller: return italian ? "Disinstalla App" : "App Uninstaller"
            case .sonar: return italian ? "Sonar Spazio" : "Space Sonar"
            case .optimizer: return italian ? "Prestazioni" : "Performance"
            }
        }
    }

    var id = UUID()
    let date: Date
    let module: Module
    let title: String
    let freedBytes: Int64
    var records: [TrashRecord]
}

/// Raccoglitore thread-safe degli elementi cestinati durante l'operazione in corso.
/// `SafeFileOps.moveToTrash` registra qui ogni spostamento riuscito; il motore che ha avviato l'operazione,
/// al termine, li consegna alla cronologia con `CleanupHistory.commitPending`.
enum TrashJournal {
    private final class Store: @unchecked Sendable {
        let lock = NSLock()
        var pending: [TrashRecord] = []
    }
    private static let store = Store()

    nonisolated static func record(original: URL, trashed: URL?) {
        let rec = TrashRecord(originalPath: original.standardizedFileURL.path, trashedPath: trashed?.standardizedFileURL.path)
        store.lock.lock()
        store.pending.append(rec)
        store.lock.unlock()
    }

    nonisolated static func drain() -> [TrashRecord] {
        store.lock.lock()
        defer { store.lock.unlock() }
        let out = store.pending
        store.pending = []
        return out
    }
}

/// Cronologia delle pulizie: cosa è stato spostato nel Cestino, quando, e la possibilità di rimetterlo a posto.
@MainActor @Observable
final class CleanupHistory {
    static let shared = CleanupHistory()
    static let restoredNotification = Notification.Name("BathysItemsRestored")

    private(set) var entries: [CleanupEntry] = []
    private let maxEntries = 80

    enum RestoreError: Error {
        case notInTrash, destinationExists, permissionDenied, unknown(String)

        func message(italian: Bool) -> String {
            switch self {
            case .notInTrash:
                return italian ? "Non è più nel Cestino (forse è stato svuotato)." : "No longer in the Trash (it may have been emptied)."
            case .destinationExists:
                return italian ? "Nella posizione originale c'è già un elemento con lo stesso nome." : "An item with the same name already exists at the original location."
            case .permissionDenied:
                return italian ? "Permessi insufficienti: usa \"Ripristina\" dal Cestino del Finder." : "Not enough permissions: use \"Put Back\" from the Finder Trash."
            case .unknown(let detail):
                return detail
            }
        }
    }

    private init() {
        load()
    }

    private var storeURL: URL {
        let fm = FileManager.default
        let base = MacSafetyIntelligence.sandboxRootURL?.appendingPathComponent("BathysSupport")
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Bathys")
        return base.appendingPathComponent("cleanup-history.json")
    }

    // MARK: Registrazione

    /// Consegna alla cronologia gli elementi cestinati dall'operazione appena conclusa
    func commitPending(module: CleanupEntry.Module, title: String, freedBytes: Int64) {
        let records = TrashJournal.drain()
        guard !records.isEmpty else { return }
        let entry = CleanupEntry(date: .now, module: module, title: title, freedBytes: freedBytes, records: records)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries = Array(entries.prefix(maxEntries)) }
        save()
    }

    /// Scarta elementi registrati che non appartengono a un'operazione da mostrare (es. manutenzione automatica)
    func discardPending() {
        _ = TrashJournal.drain()
    }

    // MARK: Stato

    func isInTrash(_ record: TrashRecord) -> Bool {
        guard record.restoredAt == nil, let trashed = record.trashedPath else { return false }
        return FileManager.default.fileExists(atPath: trashed)
    }

    func restorableCount(in entry: CleanupEntry) -> Int {
        entry.records.filter { isInTrash($0) }.count
    }

    // MARK: Ripristino

    @discardableResult
    func restore(recordId: UUID, in entryId: UUID) -> RestoreError? {
        guard let e = entries.firstIndex(where: { $0.id == entryId }),
              let r = entries[e].records.firstIndex(where: { $0.id == recordId }) else { return .unknown("") }
        let record = entries[e].records[r]
        let result = Self.moveBack(record)
        if result == nil {
            entries[e].records[r].restoredAt = .now
            save()
            NotificationCenter.default.post(name: Self.restoredNotification, object: nil)
        }
        return result
    }

    /// Ripristina tutti gli elementi ancora nel Cestino di un'operazione; restituisce quanti non è stato possibile ripristinare
    @discardableResult
    func restoreAll(in entryId: UUID) -> Int {
        guard let e = entries.firstIndex(where: { $0.id == entryId }) else { return 0 }
        var failures = 0
        var restoredAny = false
        for r in entries[e].records.indices where isInTrash(entries[e].records[r]) {
            if Self.moveBack(entries[e].records[r]) == nil {
                entries[e].records[r].restoredAt = .now
                restoredAny = true
            } else {
                failures += 1
            }
        }
        if restoredAny {
            save()
            NotificationCenter.default.post(name: Self.restoredNotification, object: nil)
        }
        return failures
    }

    func revealInTrash(_ record: TrashRecord) {
        if let trashed = record.trashedPath, FileManager.default.fileExists(atPath: trashed) {
            NSWorkspace.shared.selectFile(trashed, inFileViewerRootedAtPath: "")
        } else {
            let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
            NSWorkspace.shared.open(trash)
        }
    }

    func clear() {
        entries = []
        save()
    }

    private static func moveBack(_ record: TrashRecord) -> RestoreError? {
        let fm = FileManager.default
        guard record.restoredAt == nil, let trashedPath = record.trashedPath, fm.fileExists(atPath: trashedPath) else {
            return .notInTrash
        }
        let destination = URL(fileURLWithPath: record.originalPath)
        if fm.fileExists(atPath: destination.path) { return .destinationExists }
        do {
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: URL(fileURLWithPath: trashedPath), to: destination)
            return nil
        } catch let error as CocoaError where error.code == .fileWriteNoPermission || error.code == .fileReadNoPermission {
            return .permissionDenied
        } catch {
            let ns = error as NSError
            if ns.domain == NSPOSIXErrorDomain && (ns.code == Int(EPERM) || ns.code == Int(EACCES)) {
                return .permissionDenied
            }
            return .unknown(error.localizedDescription)
        }
    }

    // MARK: Persistenza

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([CleanupEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        let url = storeURL
        let snapshot = entries
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("[Bathys] Impossibile salvare la cronologia delle pulizie: \(error.localizedDescription)")
        }
    }
}
