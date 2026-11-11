import SwiftUI

// MARK: - Bathys Flat Illustration System
//
// Tutte le illustrazioni della scena marina (sottomarino, pesci, coralli, alghe, fondale, rifiuti)
// sono disegnate in vettoriale con Canvas: stile piatto moderno, nitide a qualsiasi risoluzione
// e molto più leggere da comporre rispetto alle immagini 3D raster.

/// Tavolozza delle illustrazioni piatte
enum FlatInk {
    // Sottomarino
    static let subBody = Color(red: 1.00, green: 0.78, blue: 0.20)
    static let subShade = Color(red: 0.96, green: 0.62, blue: 0.10)
    static let subLight = Color(red: 1.00, green: 0.90, blue: 0.55)
    static let navy = Color(red: 0.16, green: 0.22, blue: 0.34)
    static let navySoft = Color(red: 0.24, green: 0.31, blue: 0.45)
    static let glass = Color(red: 0.50, green: 0.86, blue: 0.98)
    static let glassDeep = Color(red: 0.24, green: 0.62, blue: 0.86)

    // Fondale
    static let sandBack = Color(red: 0.83, green: 0.68, blue: 0.45)
    static let sandMid = Color(red: 0.90, green: 0.76, blue: 0.52)
    static let sandFront = Color(red: 0.95, green: 0.83, blue: 0.60)
    static let pebble = Color(red: 0.74, green: 0.58, blue: 0.38)
}

/// Illustrazione vettoriale piatta identificata dallo stesso nome delle vecchie immagini 3D
struct BathysArt: View {
    let name: String

    var body: some View {
        Canvas { context, size in
            FlatArtRenderer.draw(name, in: &context, size: size)
        }
        .accessibilityHidden(true)
    }
}

enum FlatArtRenderer {
    /// Dimensione di progetto di ogni illustrazione (viene adattata al riquadro mantenendo le proporzioni)
    private static func designSize(for name: String) -> CGSize {
        switch name {
        case "submarine_yellow", "submarine_hull": return CGSize(width: 200, height: 140)
        case _ where name.hasPrefix("fish_"): return CGSize(width: 60, height: 40)
        case "algae_green_tall", "algae_ribbon_center", "algae_blue_wavy": return CGSize(width: 40, height: 110)
        case "algae_green_mid", "algae_teal_small": return CGSize(width: 40, height: 70)
        case "coral_orange_branch", "coral_red_fingers": return CGSize(width: 60, height: 60)
        case "coral_purple_fan": return CGSize(width: 60, height: 56)
        case "coral_orange_anemone": return CGSize(width: 40, height: 36)
        case "trash_oil_drum": return CGSize(width: 40, height: 48)
        case "trash_tire": return CGSize(width: 48, height: 40)
        case "trash_wood_crate": return CGSize(width: 44, height: 40)
        case "trash_glass_bottle", "trash_plastic_bottle": return CGSize(width: 24, height: 48)
        case "trash_plastic_bag": return CGSize(width: 44, height: 40)
        default: return CGSize(width: 100, height: 100)
        }
    }

    static func draw(_ name: String, in ctx: inout GraphicsContext, size: CGSize) {
        // Il fondale riempie tutto il riquadro (non mantiene le proporzioni)
        if name.hasPrefix("seafloor_") {
            drawSeafloor(foreground: name == "seafloor_sand_foreground", in: &ctx, size: size)
            return
        }

        let design = designSize(for: name)
        let scale = min(size.width / design.width, size.height / design.height)
        guard scale > 0 else { return }
        var c = ctx
        c.translateBy(x: (size.width - design.width * scale) / 2, y: (size.height - design.height * scale) / 2)
        c.scaleBy(x: scale, y: scale)

        switch name {
        case "submarine_yellow": drawSubmarine(in: &c, withPropeller: true)
        case "submarine_hull": drawSubmarine(in: &c, withPropeller: false)
        case "fish_blue_1": drawFish(in: &c, body: rgb(0.27, 0.69, 1.00), belly: rgb(0.66, 0.87, 1.00), stripe: false)
        case "fish_blue_2": drawFish(in: &c, body: rgb(0.18, 0.52, 0.91), belly: rgb(0.49, 0.77, 1.00), stripe: true)
        case "fish_orange_1": drawFish(in: &c, body: rgb(1.00, 0.55, 0.23), belly: rgb(1.00, 0.77, 0.54), stripe: true)
        case "fish_orange_2": drawFish(in: &c, body: rgb(1.00, 0.42, 0.24), belly: rgb(1.00, 0.68, 0.52), stripe: false)
        case "fish_pink_1": drawFish(in: &c, body: rgb(1.00, 0.49, 0.72), belly: rgb(1.00, 0.75, 0.87), stripe: false)
        case "fish_pink_2": drawFish(in: &c, body: rgb(0.91, 0.35, 0.61), belly: rgb(1.00, 0.66, 0.82), stripe: true)
        case "algae_green_tall":
            drawBlades(in: &c, base: 20, height: 110, color: rgb(0.20, 0.79, 0.56), blades: [(-9, 0.86, -6), (0, 1.0, 5), (9, 0.72, 7)], width: 9)
        case "algae_blue_wavy":
            drawBlades(in: &c, base: 20, height: 110, color: rgb(0.29, 0.66, 0.94), blades: [(-8, 0.80, 9), (1, 1.0, -9), (9, 0.66, 8)], width: 8)
        case "algae_ribbon_center":
            drawBlades(in: &c, base: 20, height: 110, color: rgb(0.18, 0.77, 0.71), blades: [(-5, 1.0, 10), (6, 0.84, -10)], width: 10)
        case "algae_green_mid":
            drawBlades(in: &c, base: 20, height: 70, color: rgb(0.24, 0.74, 0.50), blades: [(-6, 0.9, -5), (5, 1.0, 5)], width: 9)
        case "algae_teal_small":
            drawBlades(in: &c, base: 20, height: 70, color: rgb(0.16, 0.71, 0.66), blades: [(-8, 0.7, -4), (0, 1.0, 3), (8, 0.8, 5)], width: 8)
        case "coral_orange_branch": drawBranchCoral(in: &c, color: rgb(1.00, 0.54, 0.30), tip: rgb(1.00, 0.72, 0.45))
        case "coral_red_fingers": drawFingerCoral(in: &c, color: rgb(1.00, 0.36, 0.42), tip: rgb(1.00, 0.58, 0.60))
        case "coral_purple_fan": drawFanCoral(in: &c)
        case "coral_orange_anemone": drawAnemone(in: &c)
        case "trash_oil_drum": drawDrum(in: &c)
        case "trash_tire": drawTire(in: &c)
        case "trash_wood_crate": drawCrate(in: &c)
        case "trash_glass_bottle": drawBottle(in: &c, body: rgb(0.37, 0.83, 0.65).opacity(0.88), cap: rgb(0.22, 0.60, 0.46), label: false)
        case "trash_plastic_bottle": drawBottle(in: &c, body: rgb(0.56, 0.85, 1.00).opacity(0.85), cap: rgb(0.18, 0.52, 0.91), label: true)
        case "trash_plastic_bag": drawBag(in: &c)
        default: break
        }
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }

    // MARK: Sottomarino (muso a sinistra)

    private static func drawSubmarine(in c: inout GraphicsContext, withPropeller: Bool) {
        // Periscopio
        let periscope = Path { p in
            p.addRoundedRect(in: CGRect(x: 109, y: 10, width: 7, height: 24), cornerSize: CGSize(width: 3, height: 3))
            p.addRoundedRect(in: CGRect(x: 95, y: 6, width: 21, height: 8), cornerSize: CGSize(width: 4, height: 4))
        }
        c.fill(periscope, with: .color(FlatInk.navy))
        c.fill(Path(ellipseIn: CGRect(x: 93, y: 7, width: 5, height: 6)), with: .color(FlatInk.glass))

        // Torretta
        let tower = Path(roundedRect: CGRect(x: 76, y: 28, width: 50, height: 32), cornerRadius: 12)
        c.fill(tower, with: .color(FlatInk.subBody))
        c.fill(Path(roundedRect: CGRect(x: 76, y: 28, width: 50, height: 7), cornerRadius: 4), with: .color(FlatInk.subShade))
        for x in [88.0, 97.0, 106.0] {
            c.fill(Path(ellipseIn: CGRect(x: x, y: 41, width: 5, height: 5)), with: .color(FlatInk.navy))
        }

        // Pinne di coda (dietro lo scafo)
        let topFin = Path { p in
            p.move(to: CGPoint(x: 156, y: 64))
            p.addLine(to: CGPoint(x: 178, y: 44))
            p.addQuadCurve(to: CGPoint(x: 186, y: 50), control: CGPoint(x: 186, y: 42))
            p.addLine(to: CGPoint(x: 178, y: 72))
            p.closeSubpath()
        }
        let bottomFin = Path { p in
            p.move(to: CGPoint(x: 156, y: 98))
            p.addLine(to: CGPoint(x: 178, y: 120))
            p.addQuadCurve(to: CGPoint(x: 186, y: 114), control: CGPoint(x: 186, y: 122))
            p.addLine(to: CGPoint(x: 178, y: 92))
            p.closeSubpath()
        }
        c.fill(topFin, with: .color(FlatInk.subShade))
        c.fill(bottomFin, with: .color(FlatInk.subShade))

        // Scafo
        let hullRect = CGRect(x: 18, y: 52, width: 160, height: 60)
        let hull = Path(roundedRect: hullRect, cornerRadius: 30)
        c.fill(hull, with: .color(FlatInk.subBody))
        var shaded = c
        shaded.clip(to: hull)
        shaded.fill(Path(CGRect(x: 0, y: 94, width: 200, height: 20)), with: .color(FlatInk.subShade))
        shaded.fill(Path(roundedRect: CGRect(x: 44, y: 60, width: 96, height: 6), cornerRadius: 3), with: .color(FlatInk.subLight))
        // Fascia di giunzione
        shaded.fill(Path(CGRect(x: 146, y: 52, width: 4, height: 60)), with: .color(FlatInk.subShade.opacity(0.8)))

        // Faro anteriore
        c.fill(Path(ellipseIn: CGRect(x: 26, y: 76, width: 11, height: 11)), with: .color(FlatInk.navy))
        c.fill(Path(ellipseIn: CGRect(x: 28.5, y: 78.5, width: 6, height: 6)), with: .color(FlatInk.subLight))

        // Oblò
        for cx in [70.0, 106.0] {
            c.fill(Path(ellipseIn: CGRect(x: cx - 14, y: 68, width: 28, height: 28)), with: .color(FlatInk.navy))
            c.fill(Path(ellipseIn: CGRect(x: cx - 9.5, y: 72.5, width: 19, height: 19)), with: .color(FlatInk.glassDeep))
            c.fill(Path(ellipseIn: CGRect(x: cx - 9.5, y: 72.5, width: 15, height: 15)), with: .color(FlatInk.glass))
            c.fill(Path(ellipseIn: CGRect(x: cx - 6, y: 75.5, width: 5, height: 5)), with: .color(.white.opacity(0.85)))
        }

        // Chiglia
        c.fill(Path(roundedRect: CGRect(x: 88, y: 108, width: 32, height: 9), cornerRadius: 4), with: .color(FlatInk.subShade))

        if withPropeller {
            c.fill(Path(roundedRect: CGRect(x: 176, y: 77, width: 10, height: 8), cornerRadius: 2), with: .color(FlatInk.navySoft))
            c.fill(Path(ellipseIn: CGRect(x: 185, y: 62, width: 9, height: 19)), with: .color(FlatInk.navy))
            c.fill(Path(ellipseIn: CGRect(x: 185, y: 81, width: 9, height: 19)), with: .color(FlatInk.navy))
            c.fill(Path(ellipseIn: CGRect(x: 184, y: 76, width: 10, height: 10)), with: .color(FlatInk.navySoft))
        } else {
            c.fill(Path(roundedRect: CGRect(x: 176, y: 77, width: 8, height: 8), cornerRadius: 2), with: .color(FlatInk.navySoft))
        }
    }

    // MARK: Pesce (rivolto a destra)

    private static func drawFish(in c: inout GraphicsContext, body: Color, belly: Color, stripe: Bool) {
        let tail = Path { p in
            p.move(to: CGPoint(x: 16, y: 20))
            p.addLine(to: CGPoint(x: 2, y: 7))
            p.addQuadCurve(to: CGPoint(x: 2, y: 33), control: CGPoint(x: 8, y: 20))
            p.closeSubpath()
        }
        c.fill(tail, with: .color(body))

        let dorsal = Path { p in
            p.move(to: CGPoint(x: 22, y: 10))
            p.addQuadCurve(to: CGPoint(x: 36, y: 9), control: CGPoint(x: 28, y: 0))
            p.closeSubpath()
        }
        c.fill(dorsal, with: .color(body))

        let bodyPath = Path(ellipseIn: CGRect(x: 10, y: 7, width: 44, height: 26))
        c.fill(bodyPath, with: .color(body))
        var inner = c
        inner.clip(to: bodyPath)
        inner.fill(Path(ellipseIn: CGRect(x: 14, y: 20, width: 40, height: 18)), with: .color(belly))
        if stripe {
            inner.fill(Path(roundedRect: CGRect(x: 27, y: 4, width: 5, height: 34), cornerRadius: 2.5), with: .color(.white.opacity(0.55)))
        }

        // Pinna pettorale e occhio
        c.fill(Path(ellipseIn: CGRect(x: 30, y: 21, width: 9, height: 5)), with: .color(body.opacity(0.75)))
        c.fill(Path(ellipseIn: CGRect(x: 40, y: 13, width: 8, height: 8)), with: .color(.white))
        c.fill(Path(ellipseIn: CGRect(x: 42.5, y: 15, width: 4.5, height: 4.5)), with: .color(FlatInk.navy))
    }

    // MARK: Alghe

    /// Disegna steli a forma di fronda: (offset X della punta, altezza relativa, curvatura)
    private static func drawBlades(
        in c: inout GraphicsContext,
        base: CGFloat,
        height: CGFloat,
        color: Color,
        blades: [(CGFloat, CGFloat, CGFloat)],
        width: CGFloat
    ) {
        for (index, blade) in blades.enumerated() {
            let (tipOffset, relHeight, bend) = blade
            let baseX = base + tipOffset * 0.35
            let tip = CGPoint(x: base + tipOffset, y: height * (1 - relHeight) + 2)
            let half = width / 2
            let midY = (height + tip.y) / 2
            let path = Path { p in
                p.move(to: CGPoint(x: baseX - half, y: height))
                p.addQuadCurve(to: tip, control: CGPoint(x: baseX - half + bend * 2, y: midY))
                p.addQuadCurve(to: CGPoint(x: baseX + half, y: height), control: CGPoint(x: baseX + half + bend * 2, y: midY))
                p.closeSubpath()
            }
            let shade = index % 2 == 0 ? color : color.opacity(0.82)
            c.fill(path, with: .color(shade))
        }
    }

    // MARK: Coralli

    private static func drawBranchCoral(in c: inout GraphicsContext, color: Color, tip: Color) {
        let branches: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 30, y: 60), CGPoint(x: 30, y: 30)),
            (CGPoint(x: 30, y: 42), CGPoint(x: 14, y: 20)),
            (CGPoint(x: 30, y: 36), CGPoint(x: 44, y: 12)),
            (CGPoint(x: 31, y: 48), CGPoint(x: 52, y: 32)),
            (CGPoint(x: 29, y: 52), CGPoint(x: 9, y: 38)),
            (CGPoint(x: 30, y: 30), CGPoint(x: 28, y: 8))
        ]
        let style = StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
        for (a, b) in branches {
            var p = Path()
            p.move(to: a)
            p.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2 + 3, y: (a.y + b.y) / 2))
            c.stroke(p, with: .color(color), style: style)
            c.fill(Path(ellipseIn: CGRect(x: b.x - 4.5, y: b.y - 4.5, width: 9, height: 9)), with: .color(tip))
        }
    }

    private static func drawFingerCoral(in c: inout GraphicsContext, color: Color, tip: Color) {
        let fingers: [(CGFloat, CGFloat)] = [(9, 30), (19, 44), (29, 52), (39, 40), (49, 32)]
        for (x, h) in fingers {
            let rect = CGRect(x: x - 5, y: 60 - h, width: 10, height: h)
            c.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(color))
            c.fill(Path(ellipseIn: CGRect(x: x - 5, y: 60 - h, width: 10, height: 10)), with: .color(tip))
        }
    }

    private static func drawFanCoral(in c: inout GraphicsContext) {
        let fan = Path { p in
            p.move(to: CGPoint(x: 30, y: 52))
            p.addCurve(to: CGPoint(x: 30, y: 4), control1: CGPoint(x: -6, y: 40), control2: CGPoint(x: 4, y: 4))
            p.addCurve(to: CGPoint(x: 30, y: 52), control1: CGPoint(x: 56, y: 4), control2: CGPoint(x: 66, y: 40))
            p.closeSubpath()
        }
        c.fill(fan, with: .color(Color(red: 0.62, green: 0.49, blue: 1.00).opacity(0.92)))
        let veinStyle = StrokeStyle(lineWidth: 1.6, lineCap: .round)
        for angle in stride(from: -60.0, through: 60.0, by: 20.0) {
            let rad = (angle - 90) * .pi / 180
            var p = Path()
            p.move(to: CGPoint(x: 30, y: 52))
            p.addLine(to: CGPoint(x: 30 + cos(rad) * 40, y: 52 + sin(rad) * 40))
            c.stroke(p, with: .color(Color(red: 0.45, green: 0.33, blue: 0.86)), style: veinStyle)
        }
        c.fill(Path(roundedRect: CGRect(x: 27, y: 46, width: 6, height: 10), cornerRadius: 3), with: .color(Color(red: 0.45, green: 0.33, blue: 0.86)))
    }

    private static func drawAnemone(in c: inout GraphicsContext) {
        let tentacleStyle = StrokeStyle(lineWidth: 4, lineCap: .round)
        for i in 0..<9 {
            let angle = (-150.0 + Double(i) * 15.0) * .pi / 180
            var p = Path()
            let start = CGPoint(x: 20 + cos(angle) * 8, y: 26 + sin(angle) * 5)
            p.move(to: start)
            p.addQuadCurve(
                to: CGPoint(x: 20 + cos(angle) * 18, y: 24 + sin(angle) * 20),
                control: CGPoint(x: 20 + cos(angle) * 14 + 3, y: 24 + sin(angle) * 10)
            )
            c.stroke(p, with: .color(Color(red: 1.00, green: 0.77, blue: 0.42)), style: tentacleStyle)
        }
        c.fill(Path(ellipseIn: CGRect(x: 7, y: 22, width: 26, height: 14)), with: .color(Color(red: 1.00, green: 0.56, blue: 0.26)))
    }

    // MARK: Fondale

    private static func drawSeafloor(foreground: Bool, in c: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        if !foreground {
            // Duna di fondo + duna intermedia
            let back = Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.40))
                p.addCurve(to: CGPoint(x: w * 0.55, y: h * 0.30), control1: CGPoint(x: w * 0.18, y: h * 0.22), control2: CGPoint(x: w * 0.36, y: h * 0.42))
                p.addCurve(to: CGPoint(x: w, y: h * 0.34), control1: CGPoint(x: w * 0.72, y: h * 0.20), control2: CGPoint(x: w * 0.86, y: h * 0.40))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.closeSubpath()
            }
            c.fill(back, with: .color(FlatInk.sandBack))
            let mid = Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.58))
                p.addCurve(to: CGPoint(x: w, y: h * 0.52), control1: CGPoint(x: w * 0.30, y: h * 0.44), control2: CGPoint(x: w * 0.66, y: h * 0.66))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.closeSubpath()
            }
            c.fill(mid, with: .color(FlatInk.sandMid))
        } else {
            // Cresta di primo piano con qualche sassolino
            let front = Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.76))
                p.addCurve(to: CGPoint(x: w, y: h * 0.72), control1: CGPoint(x: w * 0.34, y: h * 0.62), control2: CGPoint(x: w * 0.62, y: h * 0.86))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.closeSubpath()
            }
            c.fill(front, with: .color(FlatInk.sandFront))
            let pebbles: [(CGFloat, CGFloat, CGFloat)] = [(0.14, 0.88, 5), (0.22, 0.92, 3), (0.63, 0.90, 4), (0.81, 0.86, 6), (0.88, 0.93, 3)]
            for (x, y, r) in pebbles {
                c.fill(Path(ellipseIn: CGRect(x: w * x, y: h * y, width: r * 1.6, height: r)), with: .color(FlatInk.pebble.opacity(0.55)))
            }
        }
    }

    // MARK: Rifiuti

    private static func drawDrum(in c: inout GraphicsContext) {
        let body = Path(roundedRect: CGRect(x: 6, y: 6, width: 28, height: 40), cornerRadius: 5)
        c.fill(body, with: .color(Color(red: 0.31, green: 0.45, blue: 0.60)))
        for y in [17.0, 33.0] {
            c.fill(Path(CGRect(x: 6, y: y, width: 28, height: 3)), with: .color(Color(red: 0.22, green: 0.33, blue: 0.46)))
        }
        c.fill(Path(ellipseIn: CGRect(x: 6, y: 3, width: 28, height: 7)), with: .color(Color(red: 0.42, green: 0.57, blue: 0.72)))
        c.fill(Path(ellipseIn: CGRect(x: 19, y: 23, width: 8, height: 6)), with: .color(Color(red: 0.80, green: 0.48, blue: 0.24).opacity(0.8)))
    }

    private static func drawTire(in c: inout GraphicsContext) {
        c.fill(Path(ellipseIn: CGRect(x: 2, y: 6, width: 44, height: 30)), with: .color(Color(red: 0.17, green: 0.20, blue: 0.25)))
        c.fill(Path(ellipseIn: CGRect(x: 14, y: 14, width: 20, height: 13)), with: .color(Color(red: 0.07, green: 0.10, blue: 0.15)))
        let tread = StrokeStyle(lineWidth: 2, lineCap: .round)
        for i in 0..<8 {
            let a = Double(i) / 8 * 2 * .pi
            var p = Path()
            p.move(to: CGPoint(x: 24 + cos(a) * 17, y: 21 + sin(a) * 11))
            p.addLine(to: CGPoint(x: 24 + cos(a) * 21, y: 21 + sin(a) * 14))
            c.stroke(p, with: .color(Color(red: 0.30, green: 0.34, blue: 0.40)), style: tread)
        }
    }

    private static func drawCrate(in c: inout GraphicsContext) {
        let box = CGRect(x: 4, y: 4, width: 36, height: 32)
        c.fill(Path(roundedRect: box, cornerRadius: 3), with: .color(Color(red: 0.77, green: 0.54, blue: 0.31)))
        let plank = Color(red: 0.62, green: 0.41, blue: 0.22)
        for y in [14.0, 25.0] {
            c.fill(Path(CGRect(x: 4, y: y, width: 36, height: 2)), with: .color(plank))
        }
        var brace = Path()
        brace.move(to: CGPoint(x: 7, y: 33))
        brace.addLine(to: CGPoint(x: 37, y: 7))
        c.stroke(brace, with: .color(plank), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
    }

    private static func drawBottle(in c: inout GraphicsContext, body: Color, cap: Color, label: Bool) {
        let bottle = Path { p in
            p.addRoundedRect(in: CGRect(x: 9, y: 4, width: 6, height: 12), cornerSize: CGSize(width: 2, height: 2))
            p.addRoundedRect(in: CGRect(x: 4, y: 14, width: 16, height: 32), cornerSize: CGSize(width: 6, height: 6))
        }
        c.fill(bottle, with: .color(body))
        c.fill(Path(roundedRect: CGRect(x: 8.5, y: 1, width: 7, height: 5), cornerRadius: 1.5), with: .color(cap))
        if label {
            c.fill(Path(CGRect(x: 4, y: 26, width: 16, height: 8)), with: .color(.white.opacity(0.65)))
        }
        c.fill(Path(roundedRect: CGRect(x: 6.5, y: 18, width: 3, height: 22), cornerRadius: 1.5), with: .color(.white.opacity(0.45)))
    }

    private static func drawBag(in c: inout GraphicsContext) {
        let bag = Path { p in
            p.move(to: CGPoint(x: 8, y: 12))
            p.addQuadCurve(to: CGPoint(x: 36, y: 12), control: CGPoint(x: 22, y: 16))
            p.addQuadCurve(to: CGPoint(x: 38, y: 36), control: CGPoint(x: 42, y: 26))
            p.addQuadCurve(to: CGPoint(x: 6, y: 36), control: CGPoint(x: 22, y: 40))
            p.addQuadCurve(to: CGPoint(x: 8, y: 12), control: CGPoint(x: 2, y: 26))
            p.closeSubpath()
        }
        c.fill(bag, with: .color(Color(red: 0.92, green: 0.96, blue: 1.00).opacity(0.72)))
        let handle = StrokeStyle(lineWidth: 2.5, lineCap: .round)
        for (a, b) in [(CGFloat(11), CGFloat(18)), (CGFloat(26), CGFloat(33))] {
            var p = Path()
            p.move(to: CGPoint(x: a, y: 13))
            p.addQuadCurve(to: CGPoint(x: b, y: 13), control: CGPoint(x: (a + b) / 2, y: 2))
            c.stroke(p, with: .color(Color(red: 0.92, green: 0.96, blue: 1.00).opacity(0.8)), style: handle)
        }
        c.fill(Path(roundedRect: CGRect(x: 12, y: 20, width: 4, height: 12), cornerRadius: 2), with: .color(.white.opacity(0.5)))
    }
}

/// Logo testuale moderno: mini sottomarino + scritta arrotondata con sfumatura oceano
struct BathysWordmark: View {
    var height: CGFloat = 64

    var body: some View {
        HStack(alignment: .center, spacing: height * 0.18) {
            BathysArt(name: "submarine_yellow")
                .frame(width: height * 1.15, height: height * 0.8)
            Text("BATHYS")
                .font(.system(size: height * 0.86, weight: .black, design: .rounded))
                .tracking(height * 0.04)
                .foregroundStyle(DS.Ink.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bathys")
    }
}
