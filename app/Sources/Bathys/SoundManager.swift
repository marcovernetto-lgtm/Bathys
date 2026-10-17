import Foundation
import AVFoundation
import AppKit
import UserNotifications

final class SoundManager: @unchecked Sendable {
    static let shared = SoundManager()
    private var audioPlayer: AVAudioPlayer?

    private init() {}

    func playChime(notificationTitle: String? = nil, notificationBody: String? = nil) {
        if AppSettings.shared.systemNotificationsEnabled {
            postSystemNotification(
                title: notificationTitle ?? (AppSettings.shared.language == .english ? "Bathys • Analysis Complete" : "Bathys • Operazione Completata"),
                body: notificationBody ?? (AppSettings.shared.language == .english ? "Bathys has finished processing your Mac." : "Bathys ha completato l'operazione richiesta.")
            )
        }
        guard AppSettings.shared.soundNotificationsEnabled else { return }
        playChimeImmediately()
    }

    private func postSystemNotification(title: String, body: String) {
        // Evita popup di sistema durante i test in sandbox
        guard MacSafetyIntelligence.sandboxRootURL == nil else { return }
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(req)
        }
    }

    func playChimeImmediately() {
        // Evita riproduzione sonora bloccante durante gli autotest automatici
        if CommandLine.arguments.contains("--self-test") { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var soundUrl: URL?

            // 1. Try Bundle.module (SwiftPM package bundle)
            if let url = Bundle.module.url(forResource: "bathys_chime", withExtension: "mp3", subdirectory: "Assets")
                ?? Bundle.module.url(forResource: "bathys_chime", withExtension: "mp3") {
                soundUrl = url
            }
            // 2. Try Bundle.main
            if soundUrl == nil, let url = Bundle.main.url(forResource: "bathys_chime", withExtension: "mp3", subdirectory: "Assets")
                ?? Bundle.main.url(forResource: "bathys_chime", withExtension: "mp3")
                ?? Bundle.main.resourceURL?.appendingPathComponent("Assets/bathys_chime.mp3") {
                soundUrl = url
            }
            // 3. Fallback relative to source directory for direct execution
            if soundUrl == nil {
                let devUrl = URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .appendingPathComponent("Assets/bathys_chime.mp3")
                if FileManager.default.fileExists(atPath: devUrl.path) {
                    soundUrl = devUrl
                }
            }

            guard let url = soundUrl else {
                return
            }

            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
            } catch {
                print("SoundManager chime playback error: \(error)")
            }
        }
    }
}
