import SwiftUI
import AppKit

/// Cronologia delle pulizie: ogni operazione con gli elementi spostati nel Cestino e il pulsante "Ripristina"
struct CleanupHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var history = CleanupHistory.shared
    @State private var expanded: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var confirmClear = false

    private var isItalian: Bool { L10n.lang == .italian }

    var body: some View {
        ZStack {
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
                header
                Divider().background(Color.white.opacity(0.07))

                if history.entries.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(history.entries) { entry in
                                entryCard(entry)
                            }
                        }
                        .padding(.horizontal, 26)
                        .padding(.vertical, 18)
                    }
                    .frame(maxHeight: .infinity)
                }

                Divider().background(Color.white.opacity(0.07))
                footer
            }
        }
        .frame(width: 660, height: 540)
        .alert(isItalian ? "Ripristino non riuscito" : "Restore failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            isItalian ? "Svuotare la cronologia?" : "Clear the history?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button(isItalian ? "Svuota cronologia" : "Clear history", role: .destructive) {
                withAnimation { history.clear() }
            }
            Button(isItalian ? "Annulla" : "Cancel", role: .cancel) {}
        } message: {
            Text(isItalian
                 ? "Si cancella solo l'elenco: gli elementi restano nel Cestino e si possono ancora ripristinare dal Finder."
                 : "Only the list is cleared: items stay in the Trash and can still be put back from Finder.")
        }
    }

    // MARK: Sezioni

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BathysPalette.sky.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(BathysPalette.sky.opacity(0.35), lineWidth: 1))
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BathysPalette.sky)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isItalian ? "Cronologia pulizie" : "Cleanup history")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(isItalian
                     ? "Cosa è finito nel Cestino e quando. Finché il Cestino non viene svuotato puoi rimetterlo a posto."
                     : "What went to the Trash and when. Until the Trash is emptied you can put it back.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(BathysPalette.textSecondary)
                    .lineLimit(2)
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
        .padding(.bottom, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(BathysPalette.textTertiary)
            Text(isItalian ? "Nessuna pulizia registrata" : "No cleanups recorded yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BathysPalette.textSecondary)
            Text(isItalian
                 ? "Le prossime pulizie, disinstallazioni ed eliminazioni dal Sonar compariranno qui."
                 : "Your next cleanups, uninstalls and Sonar removals will appear here.")
                .font(.system(size: 12))
                .foregroundStyle(BathysPalette.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if !history.entries.isEmpty {
                Button {
                    confirmClear = true
                } label: {
                    Text(isItalian ? "Svuota cronologia" : "Clear history")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BathysPalette.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text(isItalian ? "Fine" : "Done")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(BathysPalette.sky.opacity(0.35)))
                    .overlay(Capsule().strokeBorder(BathysPalette.sky.opacity(0.70), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 12)
    }

    // MARK: Card operazione

    private func entryCard(_ entry: CleanupEntry) -> some View {
        let isOpen = expanded.contains(entry.id)
        let restorable = history.restorableCount(in: entry)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                GlowMedallion(symbol: entry.module.symbol, tint: tint(for: entry.module), size: 34, isActive: restorable > 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle(for: entry, restorable: restorable))
                        .font(.system(size: 11.5))
                        .foregroundStyle(BathysPalette.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if entry.freedBytes > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: entry.freedBytes, countStyle: .file))
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .foregroundStyle(BathysPalette.textSecondary)
                }

                if restorable > 0 {
                    pillButton(isItalian ? "Ripristina tutto" : "Restore all", tint: BathysPalette.sky) {
                        let failed = history.restoreAll(in: entry.id)
                        if failed > 0 {
                            errorMessage = isItalian
                                ? "\(failed) elementi non sono stati ripristinati: esistono già nella posizione originale o servono permessi di amministratore."
                                : "\(failed) items could not be restored: they already exist at the original location or need administrator rights."
                        }
                    }
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(BathysPalette.textTertiary)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .frame(width: 18)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    if isOpen { expanded.remove(entry.id) } else { expanded.insert(entry.id) }
                }
            }

            if isOpen {
                Divider().background(Color.white.opacity(0.06))
                VStack(spacing: 2) {
                    ForEach(entry.records.prefix(200)) { record in
                        recordRow(record, entryId: entry.id)
                    }
                    if entry.records.count > 200 {
                        Text(isItalian ? "…e altri \(entry.records.count - 200) elementi" : "…and \(entry.records.count - 200) more items")
                            .font(.system(size: 11))
                            .foregroundStyle(BathysPalette.textTertiary)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(BathysPalette.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(BathysPalette.hairline, lineWidth: 1)
        )
    }

    private func recordRow(_ record: TrashRecord, entryId: UUID) -> some View {
        let inTrash = history.isInTrash(record)
        return HStack(spacing: 10) {
            Image(systemName: record.restoredAt != nil ? "arrow.uturn.backward.circle.fill" : (inTrash ? "trash" : "trash.slash"))
                .font(.system(size: 12))
                .foregroundStyle(record.restoredAt != nil ? BathysPalette.emerald : BathysPalette.textTertiary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(record.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(inTrash ? .white : BathysPalette.textSecondary)
                    .lineLimit(1)
                Text(record.displayOriginalPath)
                    .font(.system(size: 10.5))
                    .foregroundStyle(BathysPalette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .help(record.originalPath)

            Spacer(minLength: 8)

            if record.restoredAt != nil {
                Text(isItalian ? "Ripristinato" : "Restored")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(BathysPalette.emerald)
            } else if inTrash {
                BathysRoundIconButton(
                    icon: "magnifyingglass",
                    size: 22,
                    iconSize: 9.5,
                    tint: BathysPalette.sky,
                    helpText: isItalian ? "Mostra nel Cestino" : "Show in Trash"
                ) {
                    history.revealInTrash(record)
                }
                pillButton(isItalian ? "Ripristina" : "Restore", tint: BathysPalette.sky, compact: true) {
                    if let error = history.restore(recordId: record.id, in: entryId) {
                        errorMessage = error.message(italian: isItalian)
                    }
                }
            } else if record.trashedPath == nil {
                Button {
                    history.revealInTrash(record)
                } label: {
                    Text(isItalian ? "Apri il Cestino" : "Open Trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(BathysPalette.sky)
                }
                .buttonStyle(.plain)
                .help(isItalian ? "Spostato dal Finder: ripristinalo con \"Ripristina\" dal Cestino" : "Moved by Finder: use \"Put Back\" from the Trash")
            } else {
                Text(isItalian ? "Cestino svuotato" : "Trash emptied")
                    .font(.system(size: 11))
                    .foregroundStyle(BathysPalette.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: Utilità

    private func pillButton(_ title: String, tint: Color, compact: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: compact ? 11 : 11.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? 10 : 12)
                .padding(.vertical, compact ? 4 : 5)
                .background(Capsule().fill(tint.opacity(0.22)))
                .overlay(Capsule().strokeBorder(tint.opacity(0.50), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func tint(for module: CleanupEntry.Module) -> Color {
        switch module {
        case .deepClean: return BathysPalette.sky
        case .uninstaller: return BathysPalette.coral
        case .sonar: return BathysPalette.teal
        case .optimizer: return BathysPalette.emerald
        }
    }

    private func subtitle(for entry: CleanupEntry, restorable: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isItalian ? "it_IT" : "en_US")
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let when = formatter.string(from: entry.date)
        let module = entry.module.title(italian: isItalian)
        let count = entry.records.count
        let items = isItalian ? "\(count) \(count == 1 ? "elemento" : "elementi")" : "\(count) item\(count == 1 ? "" : "s")"
        let state: String
        if restorable == 0 {
            state = isItalian ? "non più nel Cestino" : "no longer in Trash"
        } else if restorable < count {
            state = isItalian ? "\(restorable) ancora nel Cestino" : "\(restorable) still in Trash"
        } else {
            state = isItalian ? "nel Cestino" : "in Trash"
        }
        return "\(when) • \(module) • \(items) • \(state)"
    }
}
