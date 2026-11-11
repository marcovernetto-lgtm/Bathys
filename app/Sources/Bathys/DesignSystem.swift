import SwiftUI

// MARK: - Bathys Design System
//
// Un unico vocabolario per tutta l'interfaccia: spaziature, raggi, tipografia, superfici e controlli.
// Ogni schermata usa questi token; nessun controllo di sistema "nudo".

enum DS {
    // Spaziature (scala a base 4)
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
        /// Margine orizzontale di tutte le aree di lavoro
        static let gutter: CGFloat = 40
        /// Margine superiore di tutte le aree di lavoro
        static let top: CGFloat = 28
    }

    // Raggi
    enum Radius {
        static let control: CGFloat = 9
        static let row: CGFloat = 14
        static let card: CGFloat = 20
        static let sheet: CGFloat = 24
    }

    // Tipografia: SF Pro per l'interfaccia, SF Rounded solo per titoli e numeri (eco delle illustrazioni)
    enum Font {
        static let display = SwiftUI.Font.system(size: 30, weight: .semibold, design: .rounded)
        static let bigNumber = SwiftUI.Font.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit()
        static let title = SwiftUI.Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 13, weight: .regular)
        static let bodyEmphasis = SwiftUI.Font.system(size: 13, weight: .medium)
        static let caption = SwiftUI.Font.system(size: 11.5, weight: .regular)
        static let captionEmphasis = SwiftUI.Font.system(size: 11.5, weight: .semibold)
        static let control = SwiftUI.Font.system(size: 13, weight: .medium)
        static let value = SwiftUI.Font.system(size: 13, weight: .medium).monospacedDigit()
    }

    // Colori di interfaccia (contrasto AA sul fondo blu notte)
    enum Ink {
        static let ground = Color(red: 0.040, green: 0.071, blue: 0.122)        // #0A1220
        static let groundDeep = Color(red: 0.028, green: 0.050, blue: 0.090)    // #070D17
        static let primary = Color.white.opacity(0.96)
        static let secondary = Color.white.opacity(0.70)
        static let tertiary = Color.white.opacity(0.50)
        static let surface = Color.white.opacity(0.045)
        static let surfaceHover = Color.white.opacity(0.075)
        static let surfaceRaised = Color.white.opacity(0.065)
        static let hairline = Color.white.opacity(0.075)
        static let hairlineStrong = Color.white.opacity(0.14)
        /// Testo scuro sopra i colori d'accento pieni
        static let onAccent = Color(red: 0.03, green: 0.07, blue: 0.12)
    }

    // Movimento: transizioni brevi che comunicano stato
    enum Motion {
        static let quick = Animation.easeOut(duration: 0.16)
        static let standard = Animation.spring(response: 0.28, dampingFraction: 0.86)
    }
}

// MARK: - Superficie

extension View {
    /// Superficie standard (righe, riquadri): riempimento tenue + filo sottile, con stato hover/selezione
    func dsSurface(radius: CGFloat = DS.Radius.row, isHovered: Bool = false, isSelected: Bool = false, tint: Color = BathysPalette.sky) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(isSelected ? tint.opacity(0.12) : (isHovered ? DS.Ink.surfaceHover : DS.Ink.surface))
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(isSelected ? tint.opacity(0.40) : (isHovered ? DS.Ink.hairlineStrong : DS.Ink.hairline), lineWidth: 1)
        )
    }
}

// MARK: - Pulsanti

enum DSButtonKind {
    /// Azione principale: capsula piena nel colore d'accento
    case primary
    /// Azione secondaria: superficie tenue con filo
    case secondary
    /// Azione leggera: solo testo colorato, superficie al passaggio
    case quiet
    /// Azione distruttiva secondaria
    case destructive
}

enum DSButtonSize {
    case small, regular, large

    var height: CGFloat {
        switch self {
        case .small: return 28
        case .regular: return 32
        case .large: return 40
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 10
        case .regular: return 14
        case .large: return 20
        }
    }
}

struct DSButtonStyle: ButtonStyle {
    var kind: DSButtonKind = .secondary
    var size: DSButtonSize = .regular
    var tint: Color = BathysPalette.sky

    func makeBody(configuration: Configuration) -> some View {
        DSButtonBody(configuration: configuration, kind: kind, size: size, tint: tint)
    }
}

private struct DSButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: DSButtonKind
    let size: DSButtonSize
    let tint: Color

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(size == .large ? DS.Font.headline : DS.Font.control)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(foreground)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .background(background(pressed: pressed))
            .overlay(border)
            .contentShape(shape)
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(DS.Motion.quick, value: pressed)
            .animation(DS.Motion.quick, value: isHovered)
            .onHover { isHovered = $0 && isEnabled }
    }

    private var shape: some InsettableShape {
        RoundedRectangle(cornerRadius: kind == .primary ? size.height / 2 : DS.Radius.control, style: .continuous)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return DS.Ink.onAccent
        case .secondary: return isHovered ? DS.Ink.primary : DS.Ink.primary.opacity(0.9)
        case .quiet: return tint
        case .destructive: return BathysPalette.coral
        }
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        switch kind {
        case .primary:
            shape.fill(tint)
                .overlay(shape.fill(Color.white.opacity(isHovered && !pressed ? 0.14 : 0)))
                .overlay(shape.fill(Color.black.opacity(pressed ? 0.14 : 0)))
        case .secondary:
            shape.fill(pressed ? DS.Ink.surfaceHover.opacity(1.4) : (isHovered ? DS.Ink.surfaceHover : DS.Ink.surfaceRaised))
        case .quiet:
            shape.fill(tint.opacity(pressed ? 0.18 : (isHovered ? 0.11 : 0)))
        case .destructive:
            shape.fill(BathysPalette.coral.opacity(pressed ? 0.22 : (isHovered ? 0.15 : 0.08)))
        }
    }

    @ViewBuilder
    private var border: some View {
        switch kind {
        case .secondary:
            shape.strokeBorder(isHovered ? DS.Ink.hairlineStrong : DS.Ink.hairline, lineWidth: 1)
        case .destructive:
            shape.strokeBorder(BathysPalette.coral.opacity(0.30), lineWidth: 1)
        default:
            EmptyView()
        }
    }
}

extension ButtonStyle where Self == DSButtonStyle {
    static func ds(_ kind: DSButtonKind = .secondary, size: DSButtonSize = .regular, tint: Color = BathysPalette.sky) -> DSButtonStyle {
        DSButtonStyle(kind: kind, size: size, tint: tint)
    }
}

// MARK: - Etichetta di stato

struct DSBadge: View {
    let text: String
    var icon: String? = nil
    var tint: Color = BathysPalette.sky

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .bold))
            }
            Text(text)
                .font(DS.Font.captionEmphasis)
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Capsule().fill(tint.opacity(0.13)))
    }
}

// MARK: - Barra di avanzamento sottile

struct DSProgressBar: View {
    let value: Double
    var tint: Color = BathysPalette.sky
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, geo.size.width * CGFloat(min(max(value, 0), 1))))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.25), value: value)
    }
}

// MARK: - Controllo segmentato

struct DSSegmented<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    var tint: Color = BathysPalette.sky
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let isOn = option.value == selection
                Button {
                    withAnimation(DS.Motion.standard) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(DS.Font.control)
                        .foregroundStyle(isOn ? DS.Ink.primary : DS.Ink.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background {
                            if isOn {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(tint.opacity(0.22))
                                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(tint.opacity(0.45), lineWidth: 1))
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DS.Ink.surface))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(DS.Ink.hairline, lineWidth: 1))
    }
}

// MARK: - Campo di ricerca

struct DSSearchField: View {
    let placeholder: String
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    var width: CGFloat = 200

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(DS.Ink.tertiary)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(DS.Ink.tertiary))
                .textFieldStyle(.plain)
                .font(DS.Font.body)
                .foregroundStyle(DS.Ink.primary)
                .focused(focus)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Ink.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.lang == .italian ? "Cancella ricerca" : "Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: 32)
        .background(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous).fill(DS.Ink.surface))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                .strokeBorder(focus.wrappedValue ? BathysPalette.sky.opacity(0.7) : DS.Ink.hairline, lineWidth: focus.wrappedValue ? 1.5 : 1)
        )
        .animation(DS.Motion.quick, value: focus.wrappedValue)
    }
}

// MARK: - Indicatore compatto (etichetta, valore, barra)

struct DSMeter: View {
    let icon: String
    let label: String
    let value: String
    let fraction: Double
    var tint: Color = BathysPalette.sky
    var barWidth: CGFloat = 96

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Ink.tertiary)
                    Text(value)
                        .font(DS.Font.captionEmphasis.monospacedDigit())
                        .foregroundStyle(DS.Ink.primary)
                }
                .lineLimit(1)
                .fixedSize()
                DSProgressBar(value: max(fraction, 0.03), tint: tint, height: 3)
                    .frame(width: barWidth)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Interruttore

struct DSToggleStyle: ToggleStyle {
    var tint: Color = BathysPalette.sky

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(DS.Motion.standard) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: DS.Space.xs) {
                configuration.label
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? tint : Color.white.opacity(0.14))
                        .frame(width: 38, height: 22)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                        .padding(2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? Text("On") : Text("Off"))
    }
}
