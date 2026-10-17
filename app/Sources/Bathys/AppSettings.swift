import SwiftUI
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case italian = "it"
    case english = "en"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .italian: return "Italiano"
        case .english: return "English"
        }
    }

    var flag: String {
        switch self {
        case .italian: return "🇮🇹"
        case .english: return "🇬🇧"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "bathys_language")
        }
    }

    @Published var soundNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundNotificationsEnabled, forKey: "bathys_sound_enabled")
        }
    }

    @Published var systemNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(systemNotificationsEnabled, forKey: "bathys_sys_notifications")
        }
    }

    @Published var confirmBeforeClean: Bool {
        didSet {
            UserDefaults.standard.set(confirmBeforeClean, forKey: "bathys_confirm_clean")
        }
    }

    @Published var sonarThresholdMB: Int {
        didSet {
            UserDefaults.standard.set(sonarThresholdMB, forKey: "bathys_sonar_threshold")
        }
    }

    private init() {
        let savedLang = UserDefaults.standard.string(forKey: "bathys_language") ?? "it"
        self.language = AppLanguage(rawValue: savedLang) ?? .italian
        self.soundNotificationsEnabled = UserDefaults.standard.object(forKey: "bathys_sound_enabled") as? Bool ?? true
        self.systemNotificationsEnabled = UserDefaults.standard.object(forKey: "bathys_sys_notifications") as? Bool ?? false
        self.confirmBeforeClean = UserDefaults.standard.object(forKey: "bathys_confirm_clean") as? Bool ?? true
        self.sonarThresholdMB = UserDefaults.standard.object(forKey: "bathys_sonar_threshold") as? Int ?? 100
    }
}

enum L10n {
    static var lang: AppLanguage {
        AppSettings.shared.language
    }

    static var homeSubtitle: String {
        lang == .italian
            ? "Seleziona uno strumento per scandagliare il disco, rimuovere file inutili e ottimizzare il tuo Mac."
            : "Select a tool to scan disk space, remove junk files and optimize your Mac."
    }

    static var protectionActive: String {
        lang == .italian ? "Protezione & Privacy ✓" : "Protection & Privacy ✓"
    }

    static var grantFullDiskAccess: String {
        lang == .italian ? "Attiva Accesso Completo al Disco" : "Grant Full Disk Access"
    }

    static var deepScanTitle: String {
        lang == .italian ? "Scansione Profonda" : "Deep Scan"
    }

    static var deepScanDesc: String {
        lang == .italian
            ? "Rimuovi cache di sistema, file temporanei e residui di sviluppo."
            : "Remove system caches, temporary files, and development remnants."
    }

    static var sonarTitle: String {
        lang == .italian ? "Sonar Spazio" : "Space Sonar"
    }

    static var sonarDesc: String {
        lang == .italian
            ? "Esplora la mappa del disco e individua subito i file più pesanti."
            : "Explore your disk map and instantly spot the largest files."
    }

    static var uninstallerTitle: String {
        lang == .italian ? "Disinstalla App" : "App Uninstaller"
    }

    static var uninstallerDesc: String {
        lang == .italian
            ? "Elimina le applicazioni insieme a tutti i loro file nascosti."
            : "Delete applications together with all their hidden remnants."
    }

    static var optimizerTitle: String {
        lang == .italian ? "Prestazioni" : "Performance"
    }

    static var optimizerDesc: String {
        lang == .italian
            ? "Ottimizza la memoria, ripara le cache e gestisci l'avvio."
            : "Optimize memory, purge caches, and manage startup items."
    }

    static var toolsBack: String {
        lang == .italian ? "Strumenti" : "Tools"
    }

    static var settingsTitle: String {
        lang == .italian ? "Impostazioni" : "Settings"
    }

    static var scanBtn: String {
        lang == .italian ? "SCANSIONA" : "SCAN"
    }

    static var cleanBtn: String {
        lang == .italian ? "PULISCI" : "CLEAN"
    }

    static var rescanBtn: String {
        lang == .italian ? "Riscansiona" : "Rescan"
    }

    static var deselectAll: String {
        lang == .italian ? "Deseleziona tutto" : "Deselect All"
    }

    static var selectAll: String {
        lang == .italian ? "Seleziona tutto" : "Select All"
    }

    static var readyForCleanup: String {
        lang == .italian ? "pronti per la pulizia" : "ready for cleanup"
    }

    static var scanningInProgress: String {
        lang == .italian ? "Analisi in corso..." : "Scanning in progress..."
    }

    static var cleanupComplete: String {
        lang == .italian ? "Pulizia completata!" : "Cleanup completed!"
    }
}
