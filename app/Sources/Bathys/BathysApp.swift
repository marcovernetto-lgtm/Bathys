import SwiftUI
import AppKit

/// Comportamento della finestra in stile "utility": chiudere la finestra (X rossa, anche da ridotta a icona)
/// chiude Bathys, invece di lasciare un processo nel Dock senza finestre.
final class BathysAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Clic sull'icona nel Dock: riporta in primo piano la finestra, anche se ridotta a icona
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let window = sender.windows.first(where: { $0.isMiniaturized && $0.canBecomeMain }) {
            window.deminiaturize(nil)
            return false
        }
        return true
    }
}

@main
struct BathysApp: App {
    @NSApplicationDelegateAdaptor(BathysAppDelegate.self) private var appDelegate

    init() {
        let args = CommandLine.arguments
        let defaultSandbox = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".test_sandbox").path
        let sandboxPath = ProcessInfo.processInfo.environment["BATHYS_SANDBOX_ROOT"] ?? defaultSandbox

        if args.contains("--self-test") {
            Task { @MainActor in
                let code = await SelfTestRunner.runAll(sandboxPath: sandboxPath)
                exit(code)
            }
            return
        }

        // Diagnostica: elenca i residui di app non più installate senza toccare nulla
        if args.contains("--list-orphans") {
            let groups = OrphanResidualScanner.scan()
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            for g in groups {
                let size = ByteCountFormatter.string(fromByteCount: g.bytes, countStyle: .file)
                print("\(g.isCertain ? "CERTO " : "VERIF.") \(size.padding(toLength: 10, withPad: " ", startingAt: 0)) \(g.lastModified.map(df.string) ?? "-")  \(g.name)  [\(g.items.map { "\($0.kind.rawValue):\($0.name)" }.joined(separator: ", "))]")
            }
            exit(0)
        }

        if args.contains("--populate-sandbox") {
            SelfTestRunner.populateSandbox(at: sandboxPath)
        }

        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }

    private var initialMode: BathysMode? {
        let args = CommandLine.arguments
        if args.contains("--deep-clean") { return .deepClean }
        if args.contains("--sonar") { return .sonar }
        if args.contains("--uninstaller") { return .uninstaller }
        if args.contains("--optimizer") { return .optimizer }
        return nil
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                autoScan: CommandLine.arguments.contains("--auto-scan"),
                initialMode: initialMode
            )
            .frame(minWidth: 1180, minHeight: 760)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        // Apertura più ampia: liste e pulsanti stanno interi senza schiacciare nulla
        .defaultSize(width: 1320, height: 860)
    }
}
