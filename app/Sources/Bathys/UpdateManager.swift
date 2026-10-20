import SwiftUI
import AppKit

struct RemoteVersionInfo: Codable, Sendable {
    let version: String
    let build: Int
    let releaseDate: String
    let notes: [String: String]
    let downloads: [String: String]
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String, notes: String, url: URL)
    case downloading(progress: Double)
    case readyToRestart(newAppURL: URL)
    case error(message: String)
}

@MainActor
@Observable
final class UpdateManager {
    static let shared = UpdateManager()

    var status: UpdateStatus = .idle
    var showUpdateBanner: Bool = false
    var availableVersionString: String = ""
    var updateNotesString: String = ""

    private let versionURL = URL(string: "https://raw.githubusercontent.com/marcovernetto-lgtm/Bathys/main/version.json")!

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.2"
    }

    var currentBuild: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "3") ?? 3
    }

    private init() {}

    func checkForUpdates(silent: Bool = false) {
        switch status {
        case .checking, .downloading:
            return
        default:
            break
        }

        if !silent { status = .checking }

        Task {
            do {
                var request = URLRequest(url: versionURL)
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                request.timeoutInterval = 10.0

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    if !silent { status = .error(message: "Impossibile contattare il server di aggiornamento.") }
                    return
                }

                let info = try JSONDecoder().decode(RemoteVersionInfo.self, from: data)
                let isNewer = isVersion(info.version, newerThan: currentVersion) || info.build > currentBuild

                if isNewer {
                    #if arch(x86_64)
                    let dlKey = (ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 14) ? "intelLegacy" : "universal"
                    #else
                    let dlKey = "universal"
                    #endif

                    let dlString = info.downloads[dlKey] ?? info.downloads["universal"] ?? ""
                    guard let downloadURL = URL(string: dlString) else {
                        if !silent { status = .error(message: "URL di download non valido.") }
                        return
                    }

                    let lang = AppSettings.shared.language.rawValue
                    let notes = info.notes[lang] ?? info.notes["it"] ?? info.notes["en"] ?? "Aggiornamento disponibile."

                    self.availableVersionString = info.version
                    self.updateNotesString = notes
                    self.status = .available(version: info.version, notes: notes, url: downloadURL)
                    self.showUpdateBanner = true

                    // Avvia subito il download in background automaticamente!
                    self.downloadAndInstallUpdate()
                } else {
                    if !silent {
                        self.status = .upToDate
                    }
                }
            } catch {
                if !silent {
                    self.status = .error(message: error.localizedDescription)
                }
            }
        }
    }

    func downloadAndInstallUpdate() {
        guard case let .available(version: _, notes: _, url: downloadURL) = status else { return }
        status = .downloading(progress: 0.15)

        Task {
            do {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let targetDMG = tempDir.appendingPathComponent("BathysUpdate.dmg")

                // Download diretto ad alta velocità
                let (downloadedFile, _) = try await URLSession.shared.download(from: downloadURL)
                if FileManager.default.fileExists(atPath: targetDMG.path) {
                    try? FileManager.default.removeItem(at: targetDMG)
                }
                try FileManager.default.moveItem(at: downloadedFile, to: targetDMG)
                self.status = .downloading(progress: 0.85)

                // Monta il DMG in una cartella temporanea isolata
                let mountPoint = tempDir.appendingPathComponent("mount")
                try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

                let attachProc = Process()
                attachProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                attachProc.arguments = ["attach", targetDMG.path, "-mountpoint", mountPoint.path, "-nobrowse", "-quiet"]
                try attachProc.run()
                attachProc.waitUntilExit()

                guard attachProc.terminationStatus == 0 else {
                    self.status = .error(message: "Impossibile aprire l'immagine di aggiornamento.")
                    return
                }

                defer {
                    let detachProc = Process()
                    detachProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    detachProc.arguments = ["detach", mountPoint.path, "-quiet"]
                    try? detachProc.run()
                    detachProc.waitUntilExit()
                }

                let contents = (try? FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)) ?? []
                guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
                    self.status = .error(message: "Applicazione non trovata nell'aggiornamento.")
                    return
                }

                // Trova la destinazione in /Applications
                var destURL = URL(fileURLWithPath: "/Applications/Bathys.app")
                let currentPath = Bundle.main.bundleURL.path
                if currentPath.hasPrefix("/Applications/") {
                    destURL = Bundle.main.bundleURL
                }

                // Sostituzione sicura con rollback
                let backupURL = tempDir.appendingPathComponent("Bathys_Old.app")
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try? FileManager.default.moveItem(at: destURL, to: backupURL)
                }

                do {
                    try FileManager.default.copyItem(at: newApp, to: destURL)

                    // Rimuovi attributi di quarantena se presenti
                    let xattrProc = Process()
                    xattrProc.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                    xattrProc.arguments = ["-cr", destURL.path]
                    try? xattrProc.run()
                    xattrProc.waitUntilExit()

                    self.status = .readyToRestart(newAppURL: destURL)
                    self.showUpdateBanner = true
                } catch {
                    // Ripristina backup
                    if FileManager.default.fileExists(atPath: backupURL.path) {
                        try? FileManager.default.moveItem(at: backupURL, to: destURL)
                    }
                    self.status = .error(message: "Permessi insufficienti per aggiornare in /Applications.")
                }
            } catch {
                self.status = .error(message: error.localizedDescription)
            }
        }
    }

    func relaunchApplication() {
        guard case let .readyToRestart(newAppURL) = status else { return }
        let pid = ProcessInfo.processInfo.processIdentifier

        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done
        /usr/bin/xattr -cr "\(newAppURL.path)" 2>/dev/null
        /usr/bin/open "\(newAppURL.path)"
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", script]
        try? proc.run()
        exit(0)
    }

    private func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let p1 = v1.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".").compactMap { Int($0) }
        let p2 = v2.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".").compactMap { Int($0) }
        let maxCount = max(p1.count, p2.count)
        for i in 0..<maxCount {
            let n1 = i < p1.count ? p1[i] : 0
            let n2 = i < p2.count ? p2[i] : 0
            if n1 > n2 { return true }
            if n1 < n2 { return false }
        }
        return false
    }
}
