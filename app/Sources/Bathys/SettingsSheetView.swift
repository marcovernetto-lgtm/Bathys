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
            DS.Ink.groundDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header Compatto & Elegante
                HStack(spacing: 14) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BathysPalette.sky)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(BathysPalette.sky.opacity(0.14)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isItalian ? "Impostazioni" : "Settings")
                            .font(DS.Font.title)
                            .foregroundStyle(DS.Ink.primary)

                        Text(isItalian ? "Lingua, avvisi, pulizia e aggiornamenti" : "Language, alerts, cleanup and updates")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Ink.secondary)
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
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedTab == tab ? BathysPalette.sky.opacity(0.18) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(selectedTab == tab ? BathysPalette.sky.opacity(0.45) : Color.clear, lineWidth: 1)
                            )
                            .foregroundStyle(selectedTab == tab ? DS.Ink.primary : DS.Ink.secondary)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 14)

                Rectangle()
                    .fill(DS.Ink.hairline)
                    .frame(height: 1)

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

                Rectangle()
                    .fill(DS.Ink.hairline)
                    .frame(height: 1)

                // MARK: - Footer Fisso Ancorato (Sempre Visibile)
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(BathysPalette.emerald)
                            .frame(width: 6, height: 6)

                        Text("Bathys \(updateManager.currentVersion)")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Ink.tertiary)
                    }

                    Spacer()

                    Button(isItalian ? "Fine" : "Done") {
                        dismiss()
                    }
                    .buttonStyle(.ds(.primary))
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
                        .toggleStyle(DSToggleStyle())
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
                        .toggleStyle(DSToggleStyle())
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
                        .toggleStyle(DSToggleStyle())
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

                    DSSegmented(
                        options: [(value: 50, label: "50 MB"), (value: 100, label: "100 MB"), (value: 250, label: "250 MB"), (value: 500, label: "500 MB")],
                        selection: $settings.sonarThresholdMB
                    )
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
                                .foregroundStyle(BathysPalette.coral)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    switch updateManager.status {
                    case .idle, .upToDate:
                        Button {
                            updateManager.checkForUpdates(silent: false)
                        } label: {
                            Label(isItalian ? "Verifica ora" : "Check now", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.ds(.secondary))

                    case .checking:
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 80)

                    case .available:
                        Button {
                            updateManager.downloadAndInstallUpdate()
                        } label: {
                            Label(isItalian ? "Aggiorna ora" : "Update now", systemImage: "arrow.down")
                        }
                        .buttonStyle(.ds(.primary, tint: BathysPalette.emerald))

                    case .downloading(let progress):
                        DSProgressBar(value: progress, tint: BathysPalette.sky, height: 5)
                            .frame(width: 120)

                    case .readyToRestart:
                        Button {
                            updateManager.relaunchApplication()
                        } label: {
                            Label(isItalian ? "Riavvia ora" : "Relaunch now", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.ds(.primary, tint: BathysPalette.emerald))

                    case .error:
                        Button(isItalian ? "Riprova" : "Retry") {
                            updateManager.checkForUpdates(silent: false)
                        }
                        .buttonStyle(.ds(.secondary))
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
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? BathysPalette.sky.opacity(0.22)
                            : (isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.025))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? BathysPalette.sky.opacity(0.55)
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
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, DS.Space.s)
        .dsSurface(radius: DS.Radius.row)
    }
}
