import AVFoundation
import Foundation

/// Plays the bundled music bed for the current mood, quietly, on a gapless loop.
/// All beds are decoded and prepared up front, so switching moods starts the new
/// bed within a fraction of a second. Kept well under the narration by a hard
/// volume ceiling; the user's level trims within that.
final class MoodMusicEngine: NSObject, AVAudioPlayerDelegate {

    /// Absolute ceiling — the bed never gets louder than this, even at level 1.0.
    private let maxVolume: Float = 0.22

    private let fadeIn: TimeInterval = 0.3
    private let fadeOut: TimeInterval = 0.35

    private var players: [String: AVAudioPlayer] = [:]
    private var current: AVAudioPlayer?
    private var level: Float = 0.5
    private var ducked = true          // true = should be silent (paused / stopped)

    private(set) var currentMood: Mood = .none
    private let prepQueue = DispatchQueue(label: "com.bikash.StoryTeller.mood-prep", qos: .userInitiated)

    override init() {
        super.init()
        preloadAll()
    }

    // MARK: Preload

    private func preloadAll() {
        let names = Set(Mood.allCases.compactMap(\.track))
        prepQueue.async { [weak self] in
            guard let self else { return }
            for name in names {
                guard let url = Self.url(for: name),
                      let player = try? AVAudioPlayer(contentsOf: url) else { continue }
                player.numberOfLoops = -1
                player.volume = 0
                player.prepareToPlay()
                DispatchQueue.main.async {
                    player.delegate = self
                    self.players[name] = player
                }
            }
        }
    }

    private func player(for name: String, then use: @escaping (AVAudioPlayer?) -> Void) {
        if let ready = players[name] { use(ready); return }
        prepQueue.async { [weak self] in
            guard let self else { use(nil); return }
            guard let url = Self.url(for: name),
                  let player = try? AVAudioPlayer(contentsOf: url) else {
                DispatchQueue.main.async { use(nil) }
                return
            }
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            DispatchQueue.main.async {
                player.delegate = self
                self.players[name] = player
                use(player)
            }
        }
    }

    // MARK: Control

    func setLevel(_ value: Float) {
        level = max(0, min(value, 1))
        if !ducked { current?.setVolume(maxVolume * level, fadeDuration: 0.2) }
    }

    /// Switch mood. `play` is the narration state — true means bring the new bed
    /// in now, false means keep it silent until narration starts.
    func setMood(_ mood: Mood, play: Bool) {
        guard mood != currentMood else {
            if play { start() } else { duck() }
            return
        }
        currentMood = mood
        ducked = !play
        let outgoing = current

        guard let name = mood.track else {
            current = nil
            fadeAway(outgoing)
            return
        }

        player(for: name) { [weak self] player in
            guard let self, self.currentMood == mood else { return }
            self.current = player
            guard let player else { return }
            if !self.ducked {
                AudioHub.shared.activate()
                player.currentTime = 0
                if !player.isPlaying { player.play() }
                player.setVolume(self.maxVolume * self.level, fadeDuration: self.fadeIn)
            }
            if outgoing !== player { self.fadeAway(outgoing) }
        }
    }

    func start() {
        ducked = false
        guard currentMood != .none, let player = current else { return }
        AudioHub.shared.activate()
        if !player.isPlaying { player.play() }
        player.setVolume(maxVolume * level, fadeDuration: fadeIn)
    }

    /// Fade to silence but keep the loop running (narration paused).
    func duck() {
        ducked = true
        current?.setVolume(0, fadeDuration: fadeOut)
    }

    func resume() {
        guard currentMood != .none, let player = current else { return }
        AudioHub.shared.activate()
        if !player.isPlaying { player.play() }
        ducked = false
        player.setVolume(maxVolume * level, fadeDuration: fadeIn)
    }

    func stop() {
        ducked = true
        current?.setVolume(0, fadeDuration: fadeOut)
        let fading = current
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut + 0.1) { [weak self] in
            if self?.ducked == true { fading?.pause() }
        }
    }

    /// Called after an interruption / foreground — restart if it should be playing.
    func ensurePlaying() {
        guard currentMood != .none, !ducked, let player = current else { return }
        AudioHub.shared.activate()
        if !player.isPlaying {
            player.play()
            player.setVolume(maxVolume * level, fadeDuration: fadeIn)
        }
    }

    private func fadeAway(_ player: AVAudioPlayer?) {
        guard let player else { return }
        player.setVolume(0, fadeDuration: 0.25)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            if player !== self?.current { player.pause() }
        }
    }

    private static func url(for name: String) -> URL? {
        if let u = Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "MoodMusic") {
            return u
        }
        if let u = Bundle.main.url(forResource: name, withExtension: "m4a") {
            return u
        }
        let guess = Bundle.main.resourceURL?.appendingPathComponent("MoodMusic/\(name).m4a")
        return guess.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
    }

    // MARK: AVAudioPlayerDelegate

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let name = players.first(where: { $0.value === player })?.key {
            players[name] = nil
        }
        let mood = currentMood
        let wasPlaying = !ducked
        currentMood = .none
        setMood(mood, play: wasPlaying)
    }

    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        ensurePlaying()
    }
}
