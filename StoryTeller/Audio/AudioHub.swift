import AVFoundation
import Foundation
import UIKit

/// Single owner of the audio session. Configures it once, keeps it active, and
/// nudges playback back to life after an interruption (a phone call, a timer) or
/// when the app returns to the foreground.
final class AudioHub {
    static let shared = AudioHub()

    /// Playback components register here; called when the session comes back.
    var onShouldResume: (() -> Void)?

    private var configured = false
    private init() {}

    func activate() {
        let session = AVAudioSession.sharedInstance()
        if !configured {
            try? session.setCategory(.playback, mode: .spokenAudio, options: [])
            let nc = NotificationCenter.default
            nc.addObserver(self, selector: #selector(interruption(_:)),
                           name: AVAudioSession.interruptionNotification, object: nil)
            nc.addObserver(self, selector: #selector(cameToForeground),
                           name: UIApplication.didBecomeActiveNotification, object: nil)
            configured = true
        }
        try? session.setActive(true, options: [])
    }

    @objc private func interruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .ended {
            try? AVAudioSession.sharedInstance().setActive(true)
            DispatchQueue.main.async { self.onShouldResume?() }
        }
    }

    @objc private func cameToForeground() {
        try? AVAudioSession.sharedInstance().setActive(true)
        DispatchQueue.main.async { self.onShouldResume?() }
    }
}
