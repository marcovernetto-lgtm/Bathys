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

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "bathys_language")
        }
    }

    var soundNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundNotificationsEnabled, forKey: "bathys_sound_enabled")
        }
    }

    var systemNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(systemNotificationsEnabled, forKey: "bathys_sys_notifications")
        }
    }

    var confirmBeforeClean: Bool {
        didSet {
            UserDefaults.standard.set(confirmBeforeClean, forKey: "bathys_confirm_clean")
        }
    }

    var sonarThresholdMB: Int {
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
            ? "Scegli cosa fare."
            : "Choose what to do."
    }

    static var protectionActive: String {
        lang == .italian ? "Protezione & Privacy ✓" : "Protection & Privacy ✓"
    }

    static var grantFullDiskAccess: String {
        lang == .italian ? "Attiva Accesso al Disco" : "Grant Disk Access"
    }

    static var deepScanTitle: String {
        lang == .italian ? "Scansione Profonda" : "Deep Scan"
    }

    static var deepScanDesc: String {
        lang == .italian
            ? "Libera spazio da cache e file inutili."
            : "Free up space from caches and junk."
    }

    static var sonarTitle: String {
        lang == .italian ? "Sonar Spazio" : "Space Sonar"
    }

    static var sonarDesc: String {
        lang == .italian
            ? "Scopri cosa occupa il disco."
            : "See what fills your disk."
    }

    static var uninstallerTitle: String {
        lang == .italian ? "Disinstalla App" : "App Uninstaller"
    }

    static var uninstallerDesc: String {
        lang == .italian
            ? "Rimuovi app e i loro avanzi."
            : "Remove apps and their leftovers."
    }

    static var optimizerTitle: String {
        lang == .italian ? "Prestazioni" : "Performance"
    }

    static var optimizerDesc: String {
        lang == .italian
            ? "Piccole cure per il tuo Mac."
            : "Small care for your Mac."
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
