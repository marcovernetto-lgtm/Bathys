import Foundation
import AppKit

/// Operazioni sui file condivise da tutti i motori: spostamento nel Cestino, esecuzione di processi e risorse.
enum SafeFileOps {
    /// Sposta un elemento nel Cestino di macOS.
    /// - In modalità sandbox di test elimina solo elementi interni alla sandbox.
    /// - `permanently` è riservato al contenuto del Cestino stesso (svuotamento definitivo).
    /// - Il fallback su `NSWorkspace.recycle` (che può chiedere l'autenticazione del Finder) viene usato solo
    ///   fuori dal Main Thread e solo se richiesto, per non bloccare mai l'interfaccia.
    /// - `record`: annota lo spostamento per la Cronologia delle pulizie (con la posizione nel Cestino, per il ripristino).
    nonisolated static func moveToTrash(_ url: URL, permanently: Bool = false, allowWorkspaceFallback: Bool = false, record: Bool = true) -> Bool {
        let fm = FileManager.default
        if let sandbox = MacSafetyIntelligence.sandboxRootURL {
            let sbPath = (sandbox.path as NSString).standardizingPath
            let target = (url.path as NSString).standardizingPath
            guard target.hasPrefix(sbPath + "/") else { return false }
            return (try? fm.removeItem(at: url)) != nil
        }

        if permanently {
            return (try? fm.removeItem(at: url)) != nil
        }

        do {
            var resulting: NSURL?
            try fm.trashItem(at: url, resultingItemURL: &resulting)
            if record { TrashJournal.record(original: url, trashed: resulting as URL?) }
            return true
        } catch {
            // L'elemento potrebbe essere già sparito (es. rimosso dall'app proprietaria): nulla da fare
            if !fm.fileExists(atPath: url.path) { return true }
            guard allowWorkspaceFallback, !Thread.isMainThread else { return false }

            let sema = DispatchSemaphore(value: 0)
            let box = RecycleResultBox()
            NSWorkspace.shared.recycle([url]) { dict, err in
                box.recycled = (err == nil && !dict.isEmpty)
                box.newURL = dict.values.first
                sema.signal()
            }
            // Attesa generosa: il Finder può mostrare una richiesta di password all'utente
            _ = sema.wait(timeout: .now() + 60)
            let done = box.recycled || !fm.fileExists(atPath: url.path)
            if done && record { TrashJournal.record(original: url, trashed: box.newURL) }
            return done
        }
    }

    private final class RecycleResultBox: @unchecked Sendable {
        var recycled = false
        var newURL: URL?
    }

    struct ProcessResult: Sendable {
        let status: Int32
        let output: String
    }

    /// Esegue un eseguibile di sistema in modo sicuro: nessun `waitUntilExit` su processi mai avviati,
    /// output letto prima dell'attesa (evita deadlock sul buffer della pipe) e timeout di sicurezza.
    @discardableResult
    nonisolated static func runProcess(_ executable: String, _ arguments: [String], timeout: TimeInterval = 60) -> ProcessResult? {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        proc.standardInput = FileHandle.nullDevice

        do {
            try proc.run()
        } catch {
            return nil
        }

        let killer = DispatchWorkItem { [weak proc] in
            if let proc, proc.isRunning { proc.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: killer)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        killer.cancel()
        return ProcessResult(status: proc.terminationStatus, output: String(data: data, encoding: .utf8) ?? "")
    }
}

/// Localizzatore sicuro del bundle risorse SwiftPM: a differenza di `Bundle.module` non termina l'app
/// con un `fatalError` se il bundle non viene trovato (es. eseguibile copiato fuori dal pacchetto .app).
enum ResourceLocator {
    nonisolated static let bundle: Bundle? = {
        let bundleName = "Bathys_Bathys.bundle"
        let candidates: [URL?] = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.executableURL?.deletingLastPathComponent()
        ]
        for candidate in candidates {
            if let url = candidate?.appendingPathComponent(bundleName), let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }()

    /// Cerca una risorsa nel bundle SwiftPM, nel bundle principale e infine nella cartella sorgente (esecuzione da sviluppo).
    nonisolated static func url(forResource name: String, withExtension ext: String) -> URL? {
        if let b = bundle,
           let url = b.url(forResource: name, withExtension: ext, subdirectory: "Assets") ?? b.url(forResource: name, withExtension: ext) {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Assets")
            ?? Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        let devUrl = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Assets/\(name).\(ext)")
        return FileManager.default.fileExists(atPath: devUrl.path) ? devUrl : nil
    }
}
