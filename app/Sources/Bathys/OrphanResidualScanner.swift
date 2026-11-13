import Foundation
import AppKit

/// Residui (cartelle e file in ~/Library) di un'app che non è più installata, raggruppati per app
struct OrphanGroup: Identifiable, Sendable {
    let id = UUID()
    /// Nome mostrato (es. "Accusonus" o "com.vendor.app")
    let name: String
    let items: [AppResidualItem]
    let lastModified: Date?
    /// Certo = identificativo in formato com.azienda.app di un'app che non risulta da nessuna parte.
    /// Da verificare = nome semplice che non corrisponde a nessuna app, comando o processo conosciuto.
    let isCertain: Bool
    var isSelected: Bool

    var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
}

/// Trova i dati lasciati in ~/Library da app che non sono più installate.
///
/// Regole prudenti: mai nulla di Apple o di sistema, mai dati di un'app installata (in qualunque cartella
/// Spotlight la trovi, inclusi helper ed estensioni), di un processo in esecuzione o di un comando da Terminale,
/// mai elementi modificati negli ultimi giorni (qualcosa li sta ancora usando).
enum OrphanResidualScanner {
    /// Identità conosciute di software presente sul Mac
    struct KnownSoftware: Sendable {
        var bundleIds: Set<String> = []          // minuscolo
        var vendors: Set<String> = []            // "com.vendor" minuscolo
        var normalizedNames: Set<String> = []    // nomi app, eseguibili, prodotti, vendor normalizzati
    }

    /// Nomi semplici di dati di sistema macOS presenti in Application Support (non hanno un .app associato)
    nonisolated static let systemNames: Set<String> = [
        "addressbook", "animoji", "appstore", "automator", "callhistorydb", "callhistorytransactions",
        "clouddocs", "controlcenter", "crashreporter", "differentialprivacy", "diskimages", "dock",
        "facetime", "fileprovider", "gnpdatastore", "intelligenceflow", "knowledge", "mobilesync",
        "music", "proapps", "syncservices", "tv", "icloud", "caches", "db", "temp", "tmp", "photos",
        "mail", "messages", "safari", "books", "podcasts", "news", "stocks", "notes", "reminders",
        "calendars", "contacts", "preview", "quicktimeplayer", "siri", "spotlight", "wallpaper",
        "networkserviceproxy", "summaryevents", "coremlcache", "defaultstore", "familycircle",
        "accounts", "keychains", "cloudkit", "homekit", "passkit", "shortcuts", "weather", "maps",
        "screentime", "storeassets", "ubiquity", "applemediaservices", "xcode", "developer",
        "instruments", "simulator", "coresimulator", "iphonesimulator", "journal", "freeform"
    ]

    /// Cartelle condivise da molte app (framework, SDK di analisi, runtime): non appartengono a una sola app
    nonisolated static let sharedRuntimeNames: Set<String> = [
        "electron", "cef", "chromium", "sentry", "iosentry", "segment", "iobranch", "branch",
        "firestore", "firebase", "crashlytics", "googleheartbeatstorage", "squirrel", "sparkle",
        "frontend", "backend", "node", "npm", "python", "java", "jupyter", "pip", "go", "rust",
        "cargo", "kotlin", "gradle", "pyinstaller", "unity", "steam", "epic", "plugins", "presets",
        "aeframework", "blaceplugins", "aescripts", "vst", "vst3", "audiounits", "components"
    ]

    /// Componenti condivisi, servizi di sistema non Apple e runtime: non sono residui di un'app rimossa
    nonisolated static let sharedComponentPrefixes: [String] = [
        "org.cups.", "org.sparkle-project.", "com.breakpad.", "com.segment.", "io.sentry.", "com.crashlytics.",
        "com.google.gmp.", "com.google.keystone", "com.google.googleupdater", "com.google.softwareupdate",
        "com.microsoft.autoupdate", "com.microsoft.shared", "com.microsoft.office", "com.microsoft.errorreporting",
        "com.adobe.csxs", "com.adobe.acc", "com.adobe.cc.", "com.adobe.dunamis", "com.adobe.dynamiclinkmediaserver",
        "com.adobe.aerendercore", "com.adobe.crashreporter", "com.adobe.coresync", "com.adobe.creativecloud",
        "net.java.", "org.openjdk.", "com.oracle.", "org.python.", "org.mozilla.", "com.github.electron",
        "com.electron.", "org.chromium.", "com.squirrel.", "org.videolan.vlc"
    ]

    /// Cartelle cercate: (percorso relativo a ~/Library, accetta anche nomi semplici)
    nonisolated static let searchFolders: [(String, AppResidualItem.Kind, Bool)] = [
        ("Application Support", .appSupport, true),
        ("Containers", .container, false),
        ("Caches", .cache, false),
        ("HTTPStorages", .cache, false),
        ("WebKit", .cache, false),
        ("Preferences", .preferences, false),
        ("Saved Application State", .stateAndLogs, false),
        ("Logs", .stateAndLogs, false)
    ]

    // MARK: - Software conosciuto

    nonisolated static func collectKnownSoftware() -> KnownSoftware {
        var known = KnownSoftware()
        var appURLs = Set<URL>()

        // 1. Tutte le app indicizzate da Spotlight (anche fuori da /Applications, helper ed estensioni incluse)
        if MacSafetyIntelligence.sandboxRootURL == nil,
           let result = SafeFileOps.runProcess("/usr/bin/mdfind", ["kMDItemContentType == 'com.apple.application-bundle'"], timeout: 30) {
            for line in result.output.split(separator: "\n") where !line.isEmpty {
                appURLs.insert(URL(fileURLWithPath: String(line)))
            }
        }
        // 2. Cartelle Applicazioni (Spotlight potrebbe essere disattivato)
        for app in UninstallerEngine.scanApplicationsFolders() { appURLs.insert(app.url) }
        if let sandbox = MacSafetyIntelligence.sandboxRootURL {
            appURLs.insert(sandbox.appendingPathComponent("Applications"))
        }

        for url in appURLs {
            addBundle(at: url, to: &known)
            // Helper, estensioni e login item annidati (es. com.vendor.app.helper)
            for sub in ["Contents/Library/LoginItems", "Contents/PlugIns", "Contents/XPCServices", "Contents/Helpers", "Contents/Frameworks"] {
                let dir = url.appendingPathComponent(sub)
                guard let children = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
                for child in children where ["app", "appex", "xpc"].contains(child.pathExtension.lowercased()) {
                    addBundle(at: child, to: &known)
                }
            }
        }

        // 3. Processi in esecuzione (demoni e strumenti senza .app, es. ollama)
        if MacSafetyIntelligence.sandboxRootURL == nil,
           let ps = SafeFileOps.runProcess("/bin/ps", ["-axo", "comm="], timeout: 10) {
            for line in ps.output.split(separator: "\n") {
                let name = (String(line) as NSString).lastPathComponent
                insertName(name, into: &known)
            }
        }
        for app in NSWorkspace.shared.runningApplications {
            if let id = app.bundleIdentifier?.lowercased() { known.bundleIds.insert(id); known.vendors.insert(vendor(of: id)) }
            if let n = app.localizedName { insertName(n, into: &known) }
        }

        // 4. Comandi da Terminale (go, kotlin, ollama, comfy-cli…)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let binDirs = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/opt/local/bin", home + "/.local/bin", home + "/bin", home + "/.cargo/bin", home + "/go/bin"]
        for dir in binDirs {
            for name in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] {
                insertName(name, into: &known)
            }
        }
        return known
    }

    nonisolated private static func addBundle(at url: URL, to known: inout KnownSoftware) {
        let dict = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")) as? [String: Any]
            ?? NSDictionary(contentsOf: url.appendingPathComponent("Info.plist")) as? [String: Any]
        if let id = (dict?["CFBundleIdentifier"] as? String)?.lowercased(), !id.isEmpty {
            known.bundleIds.insert(id)
            known.vendors.insert(vendor(of: id))
            let parts = id.split(separator: ".").map(String.init)
            if parts.count >= 2 { insertName(parts[1], into: &known) }           // vendor (es. "adobe")
            if parts.count >= 3 { insertName(parts[2], into: &known) }           // prodotto (es. "chrome")
            if parts.count >= 3 { insertName(parts.suffix(from: 1).joined(), into: &known) }
        }
        for key in ["CFBundleName", "CFBundleDisplayName", "CFBundleExecutable"] {
            if let n = dict?[key] as? String { insertName(n, into: &known) }
        }
        insertName(url.deletingPathExtension().lastPathComponent, into: &known)
    }

    nonisolated private static func insertName(_ raw: String, into known: inout KnownSoftware) {
        let n = normalize(raw)
        if n.count >= 3 { known.normalizedNames.insert(n) }
    }

    // MARK: - Classificazione

    nonisolated static func normalize(_ s: String) -> String {
        let noVersion = s.replacingOccurrences(of: #"[\s_-]*v?\d+(\.\d+)*$"#, with: "", options: .regularExpression)
        return String(noVersion.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    nonisolated static func vendor(of bundleId: String) -> String {
        bundleId.split(separator: ".").prefix(2).joined(separator: ".")
    }

    /// Estrae un bundle ID dal nome di un elemento (toglie prefisso Team ID ed estensioni note), oppure nil
    nonisolated static func bundleIdentifier(fromItemName name: String) -> String? {
        var base = name
        for ext in [".plist", ".savedState", ".binarycookies", ".log"] where base.hasSuffix(ext) {
            base = String(base.dropLast(ext.count))
        }
        if let r = base.range(of: #"^[A-Z0-9]{10}\."#, options: .regularExpression) { base.removeSubrange(r) }
        guard base.range(of: #"^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9_-]+){2,}$"#, options: .regularExpression) != nil else { return nil }
        let first = base.split(separator: ".").first.map { String($0).lowercased() } ?? ""
        guard ["com", "org", "net", "io", "ai", "app", "co", "me", "de", "fr", "it", "uk", "us", "dev", "tv", "info", "jp", "ch", "nl", "se", "at", "eu", "cc", "gg", "so", "sh", "xyz", "pro", "studio", "company"].contains(first) else { return nil }
        return base.lowercased()
    }

    enum Verdict: Equatable { case owned, certainOrphan, possibleOrphan }

    nonisolated static func classifyBundleId(_ id: String, known: KnownSoftware) -> Verdict {
        if id.hasPrefix("com.apple.") || id.hasPrefix("group.com.apple.") || id.contains(".apple.") { return .owned }
        if sharedComponentPrefixes.contains(where: { id.hasPrefix($0) || id + "." == $0 }) { return .owned }
        if known.bundleIds.contains(where: { id == $0 || id.hasPrefix($0 + ".") || $0.hasPrefix(id + ".") }) { return .owned }
        let parts = id.split(separator: ".").map(String.init)
        // Il nome del prodotto corrisponde a un'app o comando conosciuto (es. com.braun.spotteck ↔ Spotteck)
        if parts.count >= 3 {
            let product = normalize(parts[2])
            if product.count >= 4 && known.normalizedNames.contains(product) { return .owned }
            let tail = normalize(parts.suffix(from: 2).joined())
            if tail.count >= 4 && known.normalizedNames.contains(tail) { return .owned }
        }
        // Stesso produttore di un'app installata: potrebbe essere un suo componente → da verificare
        let genericVendors: Set<String> = ["com.github", "io.github", "com.electron", "org.mozilla", "com.google.code", "org.python", "org.chromium"]
        let v = vendor(of: id)
        if known.vendors.contains(v) && !genericVendors.contains(v) { return .possibleOrphan }
        // Strumenti da Terminale e identificativi segnaposto: meglio far decidere all'utente
        if parts.contains(where: { $0 == "cli" || $0.hasSuffix("-cli") }) { return .possibleOrphan }
        if ["mycompany", "yourcompany", "example", "company", "test"].contains(parts.count > 1 ? parts[1] : "") { return .possibleOrphan }
        return .certainOrphan
    }

    nonisolated static func classifyPlainName(_ name: String, known: KnownSoftware) -> Verdict {
        let base = (name as NSString).deletingPathExtension
        let n = normalize(base)
        guard n.count >= 3 else { return .owned }
        let lower = base.lowercased()
        if lower.hasPrefix("com.apple") || lower.hasPrefix("apple") || lower.hasPrefix(".") { return .owned }
        if systemNames.contains(n) || sharedRuntimeNames.contains(n) { return .owned }
        // Demoni di sistema (contactsd, tipsd, icdd…)
        if base.range(of: #"^[a-z]+d$"#, options: .regularExpression) != nil && base.count <= 26 { return .owned }
        // Corrisponde a un'app, a un produttore, a un processo o a un comando conosciuto
        for k in known.normalizedNames {
            if k == n { return .owned }
            if k.count >= 4 && n.count >= 4 && (k.hasPrefix(n) || n.hasPrefix(k)) { return .owned }
        }
        return .possibleOrphan
    }

    // MARK: - Scansione

    nonisolated static func scan(minimumAgeDays: Double = 7) -> [OrphanGroup] {
        let fm = FileManager.default
        let known = collectKnownSoftware()
        let home = MacSafetyIntelligence.sandboxRootURL ?? fm.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")
        let cutoff = Date.now.addingTimeInterval(-minimumAgeDays * 86_400)

        struct Bucket { var name: String; var items: [AppResidualItem]; var lastModified: Date?; var certain: Bool }
        var buckets: [String: Bucket] = [:]

        for (relative, kind, allowsPlain) in searchFolders {
            let dir = lib.appendingPathComponent(relative)
            guard let children = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isSymbolicLinkKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for child in children {
                let name = child.lastPathComponent
                let values = try? child.resourceValues(forKeys: [.isSymbolicLinkKey, .contentModificationDateKey])
                if values?.isSymbolicLink == true { continue }
                if name.lowercased().contains("bathys") { continue }
                if MacSafetyIntelligence.protectedCacheIdentifiers.contains(name) { continue }
                if MacSafetyIntelligence.specializedCacheIdentifiers.contains(name) { continue }

                let key: String
                let certain: Bool
                if let id = bundleIdentifier(fromItemName: name) {
                    switch classifyBundleId(id, known: known) {
                    case .owned: continue
                    case .certainOrphan: certain = true
                    case .possibleOrphan: certain = false
                    }
                    key = id.split(separator: ".").prefix(3).joined(separator: ".")
                } else {
                    guard allowsPlain, classifyPlainName(name, known: known) == .possibleOrphan else { continue }
                    certain = false
                    key = "name:" + normalize((name as NSString).deletingPathExtension)
                }

                // Usato di recente da qualcosa: non è un residuo abbandonato
                let modified = latestModification(of: child, shallow: values?.contentModificationDate)
                if let modified, modified > cutoff { continue }
                let path = child.standardizedFileURL.path
                guard !MacSafetyIntelligence.isForbiddenToDelete(path: path) || relative == "Preferences" || relative == "Containers" else { continue }

                let bytes = UninstallerEngine.computeAllocatedSize(at: child)
                let item = AppResidualItem(
                    name: name,
                    path: path,
                    kind: kind,
                    bytes: bytes,
                    isSelected: certain,
                    isStrongMatch: certain
                )
                var bucket = buckets[key] ?? Bucket(
                    name: key.hasPrefix("name:") ? (name as NSString).deletingPathExtension : key,
                    items: [],
                    lastModified: nil,
                    certain: true
                )
                bucket.items.append(item)
                bucket.certain = bucket.certain && certain
                if let modified, modified > (bucket.lastModified ?? .distantPast) { bucket.lastModified = modified }
                buckets[key] = bucket
            }
        }

        return buckets.values
            .map { OrphanGroup(name: $0.name, items: $0.items.sorted { $0.bytes > $1.bytes }, lastModified: $0.lastModified, isCertain: $0.certain, isSelected: $0.certain) }
            .sorted { lhs, rhs in
                if lhs.isCertain != rhs.isCertain { return lhs.isCertain }
                return lhs.bytes > rhs.bytes
            }
    }

    /// Data di modifica più recente: la cartella stessa e il suo primo livello (economico ma affidabile)
    nonisolated private static func latestModification(of url: URL, shallow: Date?) -> Date? {
        var latest = shallow
        if let children = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey], options: []) {
            for child in children.prefix(200) {
                if let d = (try? child.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                   d > (latest ?? .distantPast) {
                    latest = d
                }
            }
        }
        return latest
    }

    // MARK: - Rimozione

    /// Verifica finale prima di cestinare un residuo orfano: deve stare dentro una delle cartelle di ricerca
    nonisolated static func isRemovableOrphan(_ item: AppResidualItem) -> Bool {
        let fm = FileManager.default
        let home = MacSafetyIntelligence.sandboxRootURL ?? fm.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library").standardizedFileURL.path
        let p = (item.path as NSString).standardizingPath
        let roots = searchFolders.map { (lib as NSString).appendingPathComponent($0.0) }
        guard roots.contains(where: { p.hasPrefix($0 + "/") }) else { return false }
        // Solo figli diretti delle cartelle di ricerca
        return roots.contains { ($0 as NSString).standardizingPath == (p as NSString).deletingLastPathComponent }
    }
}
