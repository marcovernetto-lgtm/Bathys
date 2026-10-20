import SwiftUI
import AppKit

private enum SettingsTab: Int, CaseIterable, Identifiable {
    case general
    case cleanup
    case updates

    var id: Int { rawValue }

    func title(isItalian: Bool) -> String {
        switch self {
        case .general: return isItalian ? "Generali" : "General"
        case .cleanup: return isItalian ? "Pulizia & Sonar" : "Cleanup & Sonar"
        case .updates: return isItalian ? "Aggiornamenti" : "Updates"
        }
    }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .cleanup: return "sparkles"
        case .updates: return "arrow.triangle.2.circlepath"
        }
    }
}

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.shared
    @State private var updateManager = UpdateManager.shared
    @State private var selectedTab: SettingsTab = .general

    var isItalian: Bool {
        settings.language == .italian
    }

    var body: some View {
        ZStack {
            // Sfondo abissale raffinato
            LinearGradient(
                colors: [
                    Color(red: 0.052, green: 0.075, blue: 0.120),
                    Color(red: 0.035, green: 0.050, blue: 0.085)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header Compatto & Elegante
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(BathysPalette.sky.opacity(0.12))
                            .frame(width: 36, height: 36)
                            .overlay(Circle().strokeBorder(BathysPalette.sky.opacity(0.35), lineWidth: 1))

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BathysPalette.sky)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isItalian ? "Impostazioni" : "Settings")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text(isItalian ? "Preferenze di sistema e configurazione di Bathys" : "System preferences and Bathys configuration")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(BathysPalette.textSecondary)
                    }

                    Spacer()

                    BathysRoundIconButton(
                        icon: "xmark",
                        size: 28,
                        iconSize: 11,
                        tint: BathysPalette.sky,
                        helpText: isItalian ? "Chiudi (Esc)" : "Close (Esc)"
                    ) {
                        dismiss()
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 20)
                .padding(.bottom, 14)

                // MARK: - Barra di Navigazione Tab Native-Style
                HStack(spacing: 6) {
                    ForEach(SettingsTab.allCases) { tab in
                        Button {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                                selectedTab = tab
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11.5, weight: .semibold))
                                Text(tab.title(isItalian: isItalian))
                                    .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))

                                if tab == .updates, case .available = updateManager.status {
                                    Circle()
                                        .fill(BathysPalette.amber)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedTab == tab ? BathysPalette.sky.opacity(0.18) : Color.white.opacity(0.035))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        selectedTab == tab ? BathysPalette.sky.opacity(0.55) : Color.white.opacity(0.07),
                                        lineWidth: 1
                                    )
                            )
                            .foregroundStyle(selectedTab == tab ? Color.white : BathysPalette.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 14)

                Divider()
                    .background(Color.white.opacity(0.07))

                // MARK: - Corpo Scheda Contenuto (Scroll protetto anti-taglio)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case .general:
                            generalTabContent
                        case .cleanup:
                            cleanupTabContent
                        case .updates:
                            updatesTabContent
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 20)
                }
                .frame(maxHeight: .infinity)

                Divider()
                    .background(Color.white.opacity(0.07))

                // MARK: - Footer Fisso Ancorato (Sempre Visibile)
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(BathysPalette.emerald)
                            .frame(width: 6, height: 6)

                        Text("Bathys ⚓️ v\(updateManager.currentVersion) • Universal (Apple Silicon & Intel)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(BathysPalette.textMuted)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text(isItalian ? "Fine" : "Done")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(BathysPalette.sky.opacity(0.35))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(BathysPalette.sky.opacity(0.70), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 630, height: 460)
    }

    // MARK: - 1. Tab Generali

    private var generalTabContent: some View {
        ModernSectionGroup {
            VStack(spacing: 14) {
                // Lingua dell'applicazione
                HStack(spacing: 14) {
                    Image(systemName: "globe")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BathysPalette.sky)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isItalian ? "Lingua dell'applicazione" : "Application language")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white)

                        Text(isItalian ? "Testi, notifiche e categorie di analisi" : "Texts, alerts, and analysis categories")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(BathysPalette.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        LanguagePillButton(
                            title: "Italiano",
                            flag: "🇮🇹",
                            isSelected: settings.language == .italian
                        ) {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                settings.language = .italian
                            }
                        }

                        LanguagePillButton(
                            title: "English",
                            flag: "🇬🇧",
                            isSelected: settings.language == .english
                        ) {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                settings.language = .english
                            }
                        }
                    }
                }

                Divider().background(Color.white.opacity(0.06))

                // Rintocco sonoro al completamento
                HStack(spacing: 14) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BathysPalette.sky)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isItalian ? "Rintocco sonoro al completamento" : "Completion chime")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white)

                        Text(isItalian ? "Suono discreto al termine della scansione o pulizia" : "Play subtle chime when tasks complete")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(BathysPalette.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $settings.soundNotificationsEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Divider().background(Color.white.opacity(0.06))

                // Notifiche del Centro Notifiche macOS
                HStack(spacing: 14) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BathysPalette.sky)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isItalian ? "Notifiche del Centro Notifiche macOS" : "macOS Notification Center")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white)

                        Text(isItalian ? "Banner a schermo quando Bathys opera in background" : "Banners when running tasks in background")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(BathysPalette.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $settings.systemNotificationsEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
        }
    }

    // MARK: - 2. Tab Pulizia & Sonar

    private var cleanupTabContent: some View {
        ModernSectionGroup {
            VStack(spacing: 14) {
                // Conferma di sicurezza prima della pulizia
                HStack(spacing: 14) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BathysPalette.amber)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isItalian ? "Conferma di sicurezza prima della pulizia" : "Confirmation before cleanup")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white)

                        Text(isItalian ? "Mostra un pannello di riepilogo prima di spostare gli elementi nel Cestino" : "Display a confirmation summary before moving items to Trash")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(BathysPalette.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $settings.confirmBeforeClean)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Divider().background(Color.white.opacity(0.06))

                // Soglia minima Sonar Radar
                HStack(spacing: 14) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BathysPalette.sky)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isItalian ? "Soglia minima Sonar Radar" : "Sonar Radar threshold")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white)

                        Text(isItalian ? "Dimensione minima per mappare elementi voluminosi" : "Minimum size to highlight large elements")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(BathysPalette.textSecondary)
                    }

                    Spacer()

                    Picker("", selection: $settings.sonarThresholdMB) {
                        Text("50 MB").tag(50)
                        Text("100 MB").tag(100)
                        Text("250 MB").tag(250)
                        Text("500 MB").tag(500)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
        }
    }

    // MARK: - 3. Tab Aggiornamenti

    private var updatesTabContent: some View {
        ModernSectionGroup {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(BathysPalette.sky.opacity(0.12))
                            .frame(width: 42, height: 42)
                            .overlay(Circle().strokeBorder(BathysPalette.sky.opacity(0.35), lineWidth: 1))

                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(BathysPalette.sky)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("Bathys v\(updateManager.currentVersion)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white)

                            switch updateManager.status {
                            case .upToDate:
                                Text(isItalian ? "AGGIORNATO ✓" : "UP TO DATE ✓")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(BathysPalette.emerald)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(BathysPalette.emerald.opacity(0.18)))
                            case .available(let ver, _, _):
                                Text("v\(ver) " + (isItalian ? "DISPONIBILE" : "AVAILABLE"))
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(BathysPalette.amber)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(BathysPalette.amber.opacity(0.18)))
                            case .readyToRestart:
                                Text(isItalian ? "PRONTO AL RIAVVIO" : "READY TO RESTART")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(BathysPalette.sky)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(BathysPalette.sky.opacity(0.18)))
                            default:
                                EmptyView()
                            }
                        }

                        switch updateManager.status {
                        case .idle:
                            Text(isItalian ? "Controllo automatico attivo ad ogni avvio di Bathys" : "Automatic check enabled on launch")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(BathysPalette.textSecondary)
                        case .checking:
                            Text(isItalian ? "Connessione al server di rilascio..." : "Connecting to update server...")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(BathysPalette.sky)
                        case .upToDate:
                            Text(isItalian ? "Stai utilizzando l'ultima versione disponibile per il tuo Mac." : "You are using the latest version available.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(BathysPalette.textSecondary)
                        case .available(_, let notes, _):
                            Text(notes)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .lineLimit(2)
                        case .downloading(let progress):
                            Text(isItalian ? "Download e installazione: \(Int(progress * 100))%" : "Downloading & installing: \(Int(progress * 100))%")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(BathysPalette.sky)
                        case .readyToRestart:
                            Text(isItalian ? "Nuova versione pronta. Riavvia per iniziare ad usarla." : "New version ready. Relaunch Bathys to complete.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(BathysPalette.emerald)
                        case .error(let msg):
                            Text(msg)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color.red.opacity(0.9))
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    switch updateManager.status {
                    case .idle, .upToDate:
                        Button {
                            updateManager.checkForUpdates(silent: false)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10.5, weight: .semibold))
                                Text(isItalian ? "Verifica ora" : "Check now")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(BathysPalette.sky.opacity(0.12)))
                            .overlay(Capsule().strokeBorder(BathysPalette.sky.opacity(0.40), lineWidth: 1))
                            .foregroundStyle(BathysPalette.sky)
                        }
                        .buttonStyle(.plain)

                    case .checking:
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 80)

                    case .available:
                        Button {
                            updateManager.downloadAndInstallUpdate()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 11.5, weight: .semibold))
                                Text(isItalian ? "Aggiorna ora" : "Update now")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(BathysPalette.emerald.opacity(0.28)))
                            .overlay(Capsule().strokeBorder(BathysPalette.emerald, lineWidth: 1))
                            .foregroundStyle(Color.white)
                        }
                        .buttonStyle(.plain)

                    case .downloading(let progress):
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .frame(width: 100)
                            .tint(BathysPalette.sky)

                    case .readyToRestart:
                        Button {
                            updateManager.relaunchApplication()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 11.5, weight: .bold))
                                Text(isItalian ? "Riavvia ora" : "Relaunch now")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(BathysPalette.emerald.opacity(0.35)))
                            .overlay(Capsule().strokeBorder(BathysPalette.emerald, lineWidth: 1))
                            .foregroundStyle(Color.white)
                        }
                        .buttonStyle(.plain)

                    case .error:
                        Button {
                            updateManager.checkForUpdates(silent: false)
                        } label: {
                            Text(isItalian ? "Riprova" : "Retry")
                                .font(.system(size: 11.5, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.red.opacity(0.15)))
                                .overlay(Capsule().strokeBorder(Color.red.opacity(0.5), lineWidth: 1))
                                .foregroundStyle(Color.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Pulsante Lingua Moderno & Tattile

private struct LanguagePillButton: View {
    let title: String
    let flag: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(flag)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? BathysPalette.sky.opacity(0.22)
                            : (isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.025))
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? BathysPalette.sky.opacity(0.70)
                            : (isHovered ? Color.white.opacity(0.20) : Color.white.opacity(0.08)),
                        lineWidth: 1
                    )
            )
            .foregroundStyle(isSelected ? Color.white : BathysPalette.textSecondary)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Modern Section Group Container

private struct ModernSectionGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}
