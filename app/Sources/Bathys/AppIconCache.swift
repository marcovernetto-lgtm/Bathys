import SwiftUI
import AppKit

/// Icone delle app nitide e calcolate una sola volta.
///
/// `NSWorkspace.icon(forFile:)` restituisce un'immagine di dimensione nominale 32×32: ingrandita a 50–64 pt
/// (e ancor più dentro la scena animata, composta con `drawingGroup()`) appare sgranata. Qui l'icona viene
/// ridisegnata in una bitmap della risoluzione esatta richiesta (punti × 2 per gli schermi Retina), scegliendo
/// la rappresentazione migliore dell'.icns, e messa in cache: la scena a 30–60 fps non interroga più
/// NSWorkspace a ogni fotogramma.
@MainActor
enum AppIconCache {
    private static var cache: [String: Image] = [:]

    static func image(for url: URL, points: CGFloat) -> Image {
        let path = url.standardizedFileURL.path
        let pixels = max(16, Int((points * 2).rounded(.up)))
        let key = "\(pixels)|\(path)"
        if let hit = cache[key] { return hit }

        let icon = NSWorkspace.shared.icon(forFile: path)
        let rendered = render(icon, pixels: pixels).map { Image(decorative: $0, scale: 2) } ?? Image(nsImage: icon)
        cache[key] = rendered
        return rendered
    }

    /// Dimentica le icone di un'app (es. dopo la disinstallazione)
    static func evict(_ url: URL) {
        let path = url.standardizedFileURL.path
        cache = cache.filter { !$0.key.hasSuffix("|" + path) }
    }

    private static func render(_ icon: NSImage, pixels: Int) -> CGImage? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        icon.draw(
            in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }
}

/// Icona di un'app alla dimensione indicata, sempre nitida
struct AppIconView: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        AppIconCache.image(for: url, points: size)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
