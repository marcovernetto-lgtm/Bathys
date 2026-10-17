import SwiftUI
import AppKit

@main
struct BathysApp: App {
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
            .frame(minWidth: 1120, minHeight: 680)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
