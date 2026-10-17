import SwiftUI
import AppKit

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.shared
    @State private var isPlayingTestChime = false

    var isItalian: Bool {
        settings.language == .italian
    }

    var body: some View {
        ZStack {
            // Fondo abissale obsidian con sfumatura d'atmosfera
            LinearGradient(
                colors: [
                    Color(red: 0.050, green: 0.075, blue: 0.120),
                    Color(red: 0.035, green: 0.050, blue: 0.085)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header Moderno & Arioso
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(BathysPalette.sky.opacity(0.12))
                            .frame(width: 42, height: 42)
                            .overlay(Circle().strokeBorder(BathysPalette.sky.opacity(0.35), lineWidth: 1))

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(BathysPalette.sky)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isItalian ? "Impostazioni" : "Settings")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text(isItalian ? "Configura preferenze di sistema, suoni di notifica e sicurezza di Bathys" : "Configure system preferences, notification chimes, and security options")
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(BathysPalette.textSecondary)
                    }

                    Spacer()

                    BathysRoundIconButton(
                        icon: "xmark",
                        size: 30,
                        iconSize: 11.5,
                        tint: BathysPalette.sky,
                        helpText: isItalian ? "Chiudi (Esc)" : "Close (Esc)"
                    ) {
                        dismiss()
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 40)
                .padding(.bottom, 16)

                Divider()
                    .background(Color.white.opacity(0.07))

                // MARK: - Contenuto Spazioso (Zero Scroll, Layout a Sezioni Inset Moderne)
                VStack(spacing: 20) {

                    // 1. SEZIONE LINGUA & INTERFACCIA
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isItalian ? "INTERFACCIA & LINGUA" : "INTERFACE & LANGUAGE")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(BathysPalette.sky.opacity(0.85))
                            .tracking(1.0)
                            .padding(.leading, 4)

                        ModernSectionGroup {
                            HStack(spacing: 16) {
                                Image(systemName: "globe")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(BathysPalette.sky)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isItalian ? "Lingua dell'applicazione" : "Application language")
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundStyle(Color.white)

                                    Text(isItalian ? "Tutti i testi e le etichette si aggiornano all'istante" : "All application texts and labels update immediately")
                                        .font(.system(size: 11.5, weight: .regular))
                                        .foregroundStyle(BathysPalette.textSecondary)
                                }

                                Spacer()

                                // Pulsanti bandiera dedicati grandi e tattili
                                HStack(spacing: 10) {
                                    FlagButton(
                                        flag: "🇮🇹",
                                        isSelected: settings.language == .italian,
                                        tooltip: "Italiano"
                                    ) {
                                        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                                            settings.language = .italian
                                        }
                                    }

                                    FlagButton(
                                        flag: "🇬🇧",
                                        isSelected: settings.language == .english,
                                        tooltip: "English"
                                    ) {
                                        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                                            settings.language = .english
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    // 2. SEZIONE AUDIO & NOTIFICHE
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isItalian ? "AUDIO & FEEDBACK" : "AUDIO & FEEDBACK")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(BathysPalette.sky.opacity(0.85))
                            .tracking(1.0)
                            .padding(.leading, 4)

                        ModernSectionGroup {
                            VStack(spacing: 12) {
                                HStack(spacing: 16) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(BathysPalette.sky)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isItalian ? "Rintocco sonoro al completamento" : "Analysis completion chime")
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .foregroundStyle(Color.white)

                                        Text(isItalian ? "Riproduce il chime nautico a fine scansione o pulizia" : "Plays nautical chime when scan or cleanup is complete")
                                            .font(.system(size: 11.5, weight: .regular))
                                            .foregroundStyle(BathysPalette.textSecondary)
                                    }

                                    Spacer()

                                    // Pulsante test audio raffinato
                                    Button {
                                        isPlayingTestChime = true
                                        SoundManager.shared.playChimeImmediately()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                            isPlayingTestChime = false
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: isPlayingTestChime ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                                .font(.system(size: 11.5, weight: .semibold))
                                            Text(isItalian ? "Ascolta anteprima ♫" : "Play preview ♫")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(BathysPalette.sky.opacity(0.12)))
                                        .overlay(Capsule().strokeBorder(BathysPalette.sky.opacity(0.40), lineWidth: 1))
                                        .foregroundStyle(BathysPalette.sky)
                                    }
                                    .buttonStyle(.plain)

                                    Toggle("", isOn: $settings.soundNotificationsEnabled)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }

                                Divider().background(Color.white.opacity(0.06))

                                HStack(spacing: 16) {
                                    Image(systemName: "bell.badge.fill")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(BathysPalette.sky)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isItalian ? "Notifiche del Centro Notifiche macOS" : "macOS Notification Center banners")
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .foregroundStyle(Color.white)

                                        Text(isItalian ? "Mostra un banner a schermo quando Bathys sta operando in background" : "Shows a banner when Bathys finishes tasks in the background")
                                            .font(.system(size: 11.5, weight: .regular))
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

                    // 3. SEZIONE SICUREZZA & RADAR
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isItalian ? "SICUREZZA & RADAR DISCO" : "SAFETY & SPACE SONAR")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(BathysPalette.sky.opacity(0.85))
                            .tracking(1.0)
                            .padding(.leading, 4)

                        ModernSectionGroup {
                            VStack(spacing: 12) {
                                HStack(spacing: 16) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(BathysPalette.emerald)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 8) {
                                            Text(isItalian ? "Filosofia Cestino Nativo (Trash-Only)" : "Trash-Only Philosophy")
                                                .font(.system(size: 13.5, weight: .semibold))
                                                .foregroundStyle(Color.white)

                                            Text(isItalian ? "ATTIVA ✓" : "ACTIVE ✓")
                                                .font(.system(size: 9.5, weight: .bold))
                                                .foregroundStyle(BathysPalette.emerald)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(BathysPalette.emerald.opacity(0.18)))
                                        }

                                        Text(isItalian ? "I file eliminati vengono spostati nel Cestino di macOS e possono essere ripristinati in ogni momento" : "Removed files are sent to macOS Trash and can be restored at any time")
                                            .font(.system(size: 11.5, weight: .regular))
                                            .foregroundStyle(BathysPalette.textSecondary)
                                    }

                                    Spacer()
                                }

                                Divider().background(Color.white.opacity(0.06))

                                HStack(spacing: 16) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(BathysPalette.amber)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isItalian ? "Conferma di sicurezza prima della pulizia" : "Safety confirmation before cleanup")
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .foregroundStyle(Color.white)

                                        Text(isItalian ? "Mostra un pannello di riepilogo prima di spostare gli elementi nel Cestino" : "Display a confirmation summary before moving items to Trash")
                                            .font(.system(size: 11.5, weight: .regular))
                                            .foregroundStyle(BathysPalette.textSecondary)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $settings.confirmBeforeClean)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }

                                Divider().background(Color.white.opacity(0.06))

                                HStack(spacing: 16) {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(BathysPalette.sky)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isItalian ? "Soglia minima Sonar Radar" : "Sonar Radar threshold")
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .foregroundStyle(Color.white)

                                        Text(isItalian ? "Dimensione minima per evidenziare elementi voluminosi" : "Minimum size to highlight large elements")
                                            .font(.system(size: 11.5, weight: .regular))
                                            .foregroundStyle(BathysPalette.textSecondary)
                                    }

                                    Spacer()

                                    // Picker largo con spazio generoso per tutte le etichette senza troncatura
                                    Picker("", selection: $settings.sonarThresholdMB) {
                                        Text("50 MB").tag(50)
                                        Text("100 MB").tag(100)
                                        Text("250 MB").tag(250)
                                        Text("500 MB").tag(500)
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 250)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)

                Spacer()

                Divider()
                    .background(Color.white.opacity(0.07))

                // MARK: - Footer Raffinato
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(BathysPalette.emerald)
                            .frame(width: 7, height: 7)

                        Text("Bathys ⚓️ v1.0 • Universal (Apple Silicon & Intel)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(BathysPalette.textMuted)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text(isItalian ? "Fine" : "Done")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 7)
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
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
            }
        }
        .frame(width: 740, height: 630)
    }
}

// MARK: - Flag Button (Pulsanti Rotondi Lavorati, Tattili, Anti-AI)

private struct FlagButton: View {
    let flag: String
    let isSelected: Bool
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [
                                    BathysPalette.sky.opacity(0.28),
                                    BathysPalette.sky.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.09 : 0.045),
                                    Color.black.opacity(0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        isSelected ? Color.white.opacity(0.55) : Color.white.opacity(isHovered ? 0.24 : 0.12),
                                        isSelected ? BathysPalette.sky.opacity(0.85) : Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 1.4 : 1.0
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)

                Text(flag)
                    .font(.system(size: 23))
            }
            .scaleEffect(isSelected ? 1.04 : (isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isSelected)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(TactileRoundMicroButtonStyle())
        .help(tooltip)
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
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}
