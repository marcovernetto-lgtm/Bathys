import SwiftUI
import AppKit

/// Prima voce dell'elenco di Disinstalla: apre i residui di app non più installate
struct OrphanEntryRow: View {
    @Bindable var uninstaller: UninstallerEngine

    var body: some View {
        let isSelected = uninstaller.isShowingOrphans
        Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                uninstaller.showOrphans()
            }
        } label: {
            HStack(spacing: 10) {
                GlowMedallion(symbol: "questionmark.folder.fill", tint: BathysPalette.amber, size: 30, isActive: isSelected)

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(L10n.lang == .italian ? "App rimosse" : "Removed apps")
                        .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? .white : BathysPalette.textSecondary)
                        .lineLimit(1)
                    Group {
                        if uninstaller.isScanningOrphans {
                            Text(L10n.lang == .italian ? "Analisi…" : "Scanning…")
                        } else if uninstaller.hasScannedOrphans {
                            Text(uninstaller.orphanGroups.isEmpty
                                 ? (L10n.lang == .italian ? "Nessun residuo" : "No leftovers")
                                 : (L10n.lang == .italian ? "Residui • " : "Leftovers • ") + ByteCountFormatter.string(fromByteCount: uninstaller.totalOrphanBytes, countStyle: .file))
                        } else {
                            Text(L10n.lang == .italian ? "Residui rimasti" : "Leftover files")
                        }
                    }
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.65) : BathysPalette.textTertiary)
                    .lineLimit(1)
                }

                Spacer()

                if uninstaller.isScanningOrphans {
                    ProgressView().controlSize(.mini)
                } else if !uninstaller.orphanGroups.isEmpty {
                    Text("\(uninstaller.orphanGroups.count)")
                        .font(.system(size: 10.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(BathysPalette.amber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(BathysPalette.amber.opacity(0.16)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? BathysPalette.amber.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? BathysPalette.amber.opacity(0.35) : BathysPalette.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(L10n.lang == .italian ? "File lasciati in Libreria da app che non sono più installate" : "Files left in Library by apps that are no longer installed")
        .padding(.bottom, 6)
    }
}

/// Colonna destra in modalità "App rimosse": gruppi di residui con spunta e pulsante per il Cestino
struct OrphanResidualsPanel: View {
    @Bindable var uninstaller: UninstallerEngine

    private var isItalian: Bool { L10n.lang == .italian }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Intestazione (stessa struttura dell'app selezionata)
            HStack(spacing: 14) {
                GlowMedallion(symbol: "questionmark.folder.fill", tint: BathysPalette.amber, size: 50, isActive: true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isItalian ? "Residui di app rimosse" : "Leftovers of removed apps")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(BathysPalette.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text(ByteCountFormatter.string(fromByteCount: uninstaller.selectedOrphanBytes, countStyle: .file))
                        .font(.system(size: 26, weight: .light))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: uninstaller.selectedOrphanBytes)
                        .foregroundStyle(.white)

                    Button {
                        uninstaller.scanOrphans()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9.5, weight: .bold))
                            Text(isItalian ? "Rianalizza" : "Rescan")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(BathysPalette.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(uninstaller.isScanningOrphans)
                }
            }
            .padding(.bottom, 12)

            if uninstaller.isScanningOrphans && uninstaller.orphanGroups.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    ProgressView().controlSize(.regular)
                    Text(isItalian ? "Confronto la Libreria con le app installate…" : "Comparing your Library with installed apps…")
                        .font(.system(size: 13))
                        .foregroundStyle(BathysPalette.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if uninstaller.orphanGroups.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(BathysPalette.emerald)
                    Text(isItalian ? "Nessun residuo di app rimosse" : "No leftovers from removed apps")
                        .font(.system(size: 15))
                        .foregroundStyle(BathysPalette.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(isItalian
                     ? "Gli elementi \"Da verificare\" non sono spuntati: potrebbero essere di strumenti o progetti tuoi. Controllali prima."
                     : "Items marked \"Check first\" are not ticked: they may belong to tools or your own projects.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(BathysPalette.textTertiary)
                    .padding(.bottom, 10)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 7) {
                        ForEach($uninstaller.orphanGroups) { $group in
                            OrphanGroupRow(group: $group)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack {
                Spacer()
                CircularActionOrbButton(
                    label: uninstaller.isUninstalling
                        ? (isItalian ? "Attendi…" : "Working…")
                        : (isItalian ? "Nel Cestino" : "To Trash"),
                    iconName: "trash.fill",
                    tint: BathysPalette.coral,
                    isDisabled: !uninstaller.hasOrphanSelection || uninstaller.isUninstalling,
                    shortcutHint: "⌫"
                ) {
                    uninstaller.showOrphanConfirmation = true
                }
                Spacer()
            }
            .padding(.top, 14)
        }
    }

    private var subtitle: String {
        if uninstaller.isScanningOrphans { return isItalian ? "Analisi in corso…" : "Scanning…" }
        let groups = uninstaller.orphanGroups
        let certain = groups.filter(\.isCertain).count
        let toCheck = groups.count - certain
        return isItalian
            ? "\(groups.count) app • \(certain) certe • \(toCheck) da verificare"
            : "\(groups.count) apps • \(certain) certain • \(toCheck) to check"
    }
}

struct OrphanGroupRow: View {
    @Binding var group: OrphanGroup
    @State private var isHovered = false
    @State private var isExpanded = false

    private var isItalian: Bool { L10n.lang == .italian }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                BathysRoundCheckButton(
                    isSelected: $group.isSelected,
                    tint: BathysPalette.teal,
                    size: 18
                )

                GlowMedallion(
                    symbol: group.isCertain ? "folder.badge.minus" : "questionmark.folder",
                    tint: group.isCertain ? BathysPalette.teal : BathysPalette.amber,
                    size: 32,
                    isActive: group.isSelected
                )

                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 7) {
                        Text(group.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(group.isSelected ? .white : BathysPalette.textSecondary)
                            .lineLimit(1)
                        if !group.isCertain {
                            Text(isItalian ? "Da verificare" : "Check first")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(BathysPalette.amber)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(BathysPalette.amber.opacity(0.14)))
                        }
                    }
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(BathysPalette.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                OrphanInfoSearchButton(term: group.name, kindHint: group.items.first?.kind)

                Text(ByteCountFormatter.string(fromByteCount: group.bytes, countStyle: .file))
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(group.isSelected ? BathysPalette.textSecondary : BathysPalette.textTertiary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BathysPalette.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 16)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8.5)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) { isExpanded.toggle() }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.items) { item in
                        HStack(spacing: 8) {
                            Text(item.kind.rawValue)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(BathysPalette.textTertiary)
                                .frame(width: 84, alignment: .leading)
                            Text(item.displayPath)
                                .font(.system(size: 11))
                                .foregroundStyle(BathysPalette.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 6)
                            Text(item.formattedSize)
                                .font(.system(size: 11))
                                .monospacedDigit()
                                .foregroundStyle(BathysPalette.textTertiary)
                            BathysRoundIconButton(
                                icon: "globe",
                                size: 22,
                                iconSize: 9.5,
                                tint: BathysPalette.sky,
                                helpText: isItalian ? "Cerca \"\(OrphanInfoSearch.term(forItemName: item.name))\" su Google" : "Search Google for \"\(OrphanInfoSearch.term(forItemName: item.name))\""
                            ) {
                                OrphanInfoSearch.open(term: OrphanInfoSearch.term(forItemName: item.name), kindHint: item.kind)
                            }
                            BathysRoundIconButton(
                                icon: "magnifyingglass",
                                size: 22,
                                iconSize: 9.5,
                                tint: BathysPalette.teal,
                                helpText: isItalian ? "Mostra nel Finder" : "Show in Finder"
                            ) {
                                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                            }
                        }
                    }
                }
                .padding(.leading, 62)
                .padding(.trailing, 14)
                .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isHovered ? BathysPalette.surfaceFillHover : BathysPalette.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(isHovered ? BathysPalette.hairlineHover : BathysPalette.hairline, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) { isHovered = hovering }
        }
    }

    private var detail: String {
        let count = group.items.count
        let items = isItalian ? "\(count) \(count == 1 ? "elemento" : "elementi")" : "\(count) item\(count == 1 ? "" : "s")"
        guard let date = group.lastModified else { return items }
        let df = DateFormatter()
        df.locale = Locale(identifier: isItalian ? "it_IT" : "en_US")
        df.dateFormat = "MMM yyyy"
        return items + (isItalian ? " • ultimo uso " : " • last used ") + df.string(from: date)
    }
}

/// Ricerca su Google per capire di quale app è un residuo e a cosa serve
enum OrphanInfoSearch {
    /// Nome "pulito" da cercare: identificativo dell'app se c'è, altrimenti il nome senza estensione
    static func term(forItemName name: String) -> String {
        if let id = OrphanResidualScanner.bundleIdentifier(fromItemName: name) { return id }
        var base = name
        for ext in [".plist", ".savedState", ".binarycookies", ".log", ".app"] where base.hasSuffix(ext) {
            base = String(base.dropLast(ext.count))
        }
        return base
    }

    static func query(term: String, kindHint: AppResidualItem.Kind?) -> String {
        let looksLikeBundleId = term.contains(".") && !term.contains(" ")
        if looksLikeBundleId {
            return "\"\(term)\" mac app"
        }
        // Nome generico: aggiungo il contesto della cartella per evitare risultati fuori tema
        let folder = kindHint == .appSupport ? " \"Application Support\"" : " Library"
        return "\"\(term)\" mac\(folder)"
    }

    static func open(term: String, kindHint: AppResidualItem.Kind?) {
        var comps = URLComponents(string: "https://www.google.com/search")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: query(term: term, kindHint: kindHint)),
            URLQueryItem(name: "hl", value: L10n.lang == .italian ? "it" : "en")
        ]
        if let url = comps.url { NSWorkspace.shared.open(url) }
    }
}

/// Pulsante "Cerca info" nella riga di un gruppo di residui
struct OrphanInfoSearchButton: View {
    let term: String
    var kindHint: AppResidualItem.Kind?
    @State private var isHovered = false

    var body: some View {
        Button {
            OrphanInfoSearch.open(term: term, kindHint: kindHint)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 9.5, weight: .bold))
                Text(L10n.lang == .italian ? "Cerca info" : "Look up")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isHovered ? Color.white : BathysPalette.sky)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(Capsule().fill(BathysPalette.sky.opacity(isHovered ? 0.28 : 0.14)))
            .overlay(Capsule().strokeBorder(BathysPalette.sky.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(L10n.lang == .italian ? "Cerca su Google di quale app è e a cosa serve" : "Search Google for which app this belongs to")
        .onHover { h in withAnimation(.easeOut(duration: 0.14)) { isHovered = h } }
    }
}
