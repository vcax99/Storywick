import Foundation
import AVFoundation
import Observation
import SwiftData

enum SpeechEngineKind: String, CaseIterable, Identifiable {
    case kokoro   // neural, on-device — the natural-sounding one
    case apple    // AVSpeechSynthesizer — instant, lighter

    var id: String { rawValue }
    var label: String { self == .kokoro ? "Natural" : "System" }
    var blurb: String {
        self == .kokoro
            ? "Neural voice, sounds like a person reading. A short wait before it starts."
            : "Apple's built-in voices. Starts instantly, more robotic."
    }
}

/// Narration coordinator. Holds the sentence list and playback state the UI
/// observes, and drives either the Apple engine or the Kokoro neural engine.
@Observable
final class Narrator: NSObject {

    struct Sentence: Identifiable {
        let id: Int
        let text: String
    }

    private(set) var sentences: [Sentence] = []
    private(set) var currentIndex = 0
    private(set) var isSpeaking = false
    private(set) var isPaused = false
    /// True while the neural engine is synthesising the first sentence.
    private(set) var isPreparing = false

    var onIndexChange: ((Int) -> Void)?

    /// The chapter currently loaded, so navigating away and back doesn't restart it.
    private(set) var loadedStoryID: PersistentIdentifier?

    // MARK: Settings (persisted)

    var engineKind: SpeechEngineKind {
        didSet {
            defaults.set(engineKind.rawValue, forKey: Keys.engine)
            if oldValue != engineKind { stop() }
        }
    }
    var appleVoiceIdentifier: String? {
        didSet { defaults.set(appleVoiceIdentifier, forKey: Keys.appleVoice) }
    }
    var kokoroVoice: Int {
        didSet { defaults.set(kokoroVoice, forKey: Keys.kokoroVoice) }
    }
    /// 0.5–2.0 multiplier, 1.0 = natural. Shared by both engines.
    var speed: Float {
        didSet { defaults.set(speed, forKey: Keys.speed) }
    }
    /// Apple only (Kokoro has no pitch control).
    var pitch: Float {
        didSet { defaults.set(pitch, forKey: Keys.pitch) }
    }
    var volume: Float {
        didSet { defaults.set(volume, forKey: Keys.volume) }
    }
    /// Background mood level, 0–1 (the bed is always quiet; this trims within that).
    var musicLevel: Float {
        didSet {
            defaults.set(musicLevel, forKey: Keys.musicLevel)
            music.setLevel(musicLevel)
        }
    }

    private enum Keys {
        static let engine = "narrator.engine"
        static let appleVoice = "narrator.appleVoice"
        static let kokoroVoice = "narrator.kokoroVoice"
        static let speed = "narrator.speed"
        static let pitch = "narrator.pitch"
        static let volume = "narrator.volume"
        static let musicLevel = "narrator.musicLevel"
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    // Background mood bed
    @ObservationIgnored let music = MoodMusicEngine()
    private(set) var mood: Mood = .none

    // Lock screen / Control Center
    @ObservationIgnored private let nowPlaying = NowPlaying()
    var nowPlayingTitle = "Storywick"

    // Voice preview (settings sheet)
    @ObservationIgnored private lazy var previewer: VoicePreviewer = {
        let p = VoicePreviewer()
        p.onBusyChange = { [weak self] busy in self?.isPreviewing = busy }
        return p
    }()
    private(set) var isPreviewing = false

    // Apple engine — utterances are queued up front so they play back to back
    @ObservationIgnored private let synth = AVSpeechSynthesizer()
    @ObservationIgnored private var appleIndexByUtterance: [ObjectIdentifier: Int] = [:]
    @ObservationIgnored private var settingsDirty = false

    // Kokoro engine
    @ObservationIgnored private lazy var kokoro: KokoroPlayer = {
        let player = KokoroPlayer()
        player.onAdvance = { [weak self] index in
            guard let self else { return }
            self.currentIndex = index
            self.onIndexChange?(index)
            self.refreshNowPlaying()
        }
        player.onFinish = { [weak self] in
            guard let self else { return }
            self.isSpeaking = false
            self.isPaused = false
            self.isPreparing = false
            self.music.duck()
            self.onIndexChange?(self.currentIndex)
            self.refreshNowPlaying()
        }
        player.onPreparingChange = { [weak self] preparing in
            self?.isPreparing = preparing
        }
        return player
    }()

    override init() {
        let stored = UserDefaults.standard
        engineKind = SpeechEngineKind(rawValue: stored.string(forKey: Keys.engine) ?? "") ?? .kokoro
        appleVoiceIdentifier = stored.string(forKey: Keys.appleVoice)
        kokoroVoice = stored.object(forKey: Keys.kokoroVoice) as? Int ?? 1   // Bella
        speed = (stored.object(forKey: Keys.speed) as? Float) ?? 1.0
        pitch = (stored.object(forKey: Keys.pitch) as? Float) ?? 1.0
        volume = (stored.object(forKey: Keys.volume) as? Float) ?? 1.0
        musicLevel = (stored.object(forKey: Keys.musicLevel) as? Float) ?? 1.0
        super.init()
        synth.delegate = self
        synth.usesApplicationAudioSession = true
        music.setLevel(musicLevel)

        AudioHub.shared.activate()
        AudioHub.shared.onShouldResume = { [weak self] in self?.handleSystemResume() }

        nowPlaying.onTogglePlayPause = { [weak self] in self?.togglePlayPause() }
        nowPlaying.onNext = { [weak self] in self?.skip(by: 1) }
        nowPlaying.onPrevious = { [weak self] in self?.skip(by: -1) }
        nowPlaying.wire()
    }

    /// The session came back after an interruption or the app returned to foreground.
    private func handleSystemResume() {
        guard isSpeaking, !isPaused else { return }
        music.ensurePlaying()
        switch engineKind {
        case .kokoro:
            kokoro.reassert()
        case .apple:
            if synth.isPaused {
                synth.continueSpeaking()
            } else if !synth.isSpeaking {
                speakApple(from: currentIndex)
            }
        }
    }

    private func refreshNowPlaying() {
        guard !sentences.isEmpty else { nowPlaying.clear(); return }
        nowPlaying.update(
            title: "Chapter narration",
            chapter: nowPlayingTitle,
            sentence: currentIndex,
            total: sentences.count,
            playing: isSpeaking && !isPaused
        )
    }

    func setMood(_ newMood: Mood) {
        mood = newMood
        music.setMood(newMood, play: isSpeaking && !isPaused)
    }

    var kokoroAvailable: Bool { kokoro.ensureAvailable() }

    // MARK: Loading

    func load(_ text: String, startAt index: Int = 0) {
        stop()
        loadedStoryID = nil
        sentences = TextStats.sentences(text).enumerated().map { Sentence(id: $0.offset, text: $0.element) }
        currentIndex = clamp(index)
    }

    /// Load a chapter. If it's already the loaded one, keep playing (music-player style).
    func load(_ story: Story) {
        nowPlayingTitle = story.title
        if loadedStoryID == story.persistentModelID, !sentences.isEmpty {
            onIndexChange = { [weak story] in story?.progressIndex = $0 }
            return
        }
        stop()
        loadedStoryID = story.persistentModelID
        sentences = TextStats.sentences(story.text).enumerated().map { Sentence(id: $0.offset, text: $0.element) }
        currentIndex = clamp(story.isFinished ? 0 : story.progressIndex)
        onIndexChange = { [weak story] in story?.progressIndex = $0 }
        setMood(story.mood)
    }

    /// True when narration is loaded and either playing or paused — for a mini bar.
    var isActive: Bool { !sentences.isEmpty && (isSpeaking || isPaused) }

    var progress: Double {
        guard sentences.count > 1 else { return 0 }
        return Double(currentIndex) / Double(sentences.count - 1)
    }

    var currentSentenceText: String? {
        sentences.indices.contains(currentIndex) ? sentences[currentIndex].text : nil
    }

    var atEnd: Bool {
        !sentences.isEmpty && currentIndex >= sentences.count - 1
    }

    // MARK: Transport

    func togglePlayPause() {
        if isSpeaking && !isPaused {
            pause()
        } else if isPaused {
            resume()
        } else if atEnd {
            play(from: 0)
        } else {
            play(from: currentIndex)
        }
    }

    func play(from index: Int) {
        guard !sentences.isEmpty else { return }
        currentIndex = clamp(index)
        isSpeaking = true
        isPaused = false
        settingsDirty = false
        music.start()

        switch engineKind {
        case .apple:
            speakApple(from: currentIndex)
        case .kokoro:
            guard kokoro.ensureAvailable() else {
                engineKind = .apple
                play(from: index)
                return
            }
            kokoro.configure(sentences: sentences.map(\.text), voice: kokoroVoice, speed: speed, volume: volume)
            kokoro.play(from: currentIndex)
        }
        refreshNowPlaying()
    }

    func pause() {
        isPaused = true
        music.duck()
        switch engineKind {
        case .apple: synth.pauseSpeaking(at: .word)
        case .kokoro: kokoro.pause()
        }
        refreshNowPlaying()
    }

    func resume() {
        activateSession()
        isPaused = false
        isSpeaking = true
        music.resume()
        switch engineKind {
        case .apple:
            if settingsDirty || !synth.isPaused {
                settingsDirty = false
                speakApple(from: currentIndex)
            } else {
                synth.continueSpeaking()
            }
        case .kokoro:
            if settingsDirty {
                settingsDirty = false
                kokoro.play(from: currentIndex)
            } else {
                kokoro.resume()
            }
        }
        refreshNowPlaying()
    }

    func stop() {
        isSpeaking = false
        isPaused = false
        isPreparing = false
        appleIndexByUtterance.removeAll()
        synth.stopSpeaking(at: .immediate)
        kokoro.stop()
        music.duck()
        nowPlaying.clear()
    }

    func seek(to index: Int) {
        let target = clamp(index)
        if isSpeaking && !isPaused {
            play(from: target)
        } else {
            stop()
            currentIndex = target
            onIndexChange?(target)
        }
    }

    func skip(by delta: Int) {
        seek(to: currentIndex + delta)
    }

    /// Reset speed / pitch / volume to their defaults (1.00× / 1.00 / 100%).
    func resetEqualizer() {
        speed = 1.0
        pitch = 1.0
        volume = 1.0
        applyLiveChange()
    }

    /// Reset the background music level to 100%.
    func resetMusicLevel() {
        musicLevel = 1.0
    }

    /// Play a one-line sample in the current voice. Pauses narration first if it's running.
    func previewVoice() {
        if isSpeaking && !isPaused { pause() }
        previewer.preview(
            engine: engineKind,
            kokoroVoice: kokoroVoice,
            appleVoiceID: appleVoiceIdentifier,
            speed: speed,
            pitch: pitch,
            volume: volume
        )
    }

    func stopPreview() {
        previewer.stop()
    }

    /// A setting changed — apply it right away.
    func applyLiveChange() {
        if engineKind == .kokoro {
            kokoro.updateLive(voice: kokoroVoice, speed: speed, volume: volume)
        }
        if isSpeaking && !isPaused {
            play(from: currentIndex)
        } else if isPaused {
            settingsDirty = true
        }
    }

    // MARK: Apple engine

    /// Queue every remaining sentence into the synthesiser at once so they play
    /// back to back without the round-trip gap of speaking one at a time.
    private func speakApple(from index: Int) {
        activateSession()
        synth.stopSpeaking(at: .immediate)
        appleIndexByUtterance.removeAll()
        let start = clamp(index)
        onIndexChange?(start)
        for i in start..<sentences.count {
            let utterance = makeUtterance(for: sentences[i].text)
            appleIndexByUtterance[ObjectIdentifier(utterance)] = i
            synth.speak(utterance)
        }
    }

    private func makeUtterance(for string: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: string)
        if let id = appleVoiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-US")
        }
        let scaled = AVSpeechUtteranceDefaultSpeechRate * speed
        utterance.rate = min(max(scaled, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        utterance.postUtteranceDelay = 0.02
        return utterance
    }

    // MARK: Shared

    private func clamp(_ index: Int) -> Int {
        guard !sentences.isEmpty else { return 0 }
        return min(max(index, 0), sentences.count - 1)
    }

    private func activateSession() {
        AudioHub.shared.activate()
    }
}

extension Narrator: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard engineKind == .apple, let index = appleIndexByUtterance[ObjectIdentifier(utterance)] else { return }
        DispatchQueue.main.async {
            guard self.engineKind == .apple else { return }
            self.currentIndex = index
            self.onIndexChange?(index)
            self.refreshNowPlaying()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard engineKind == .apple, let index = appleIndexByUtterance[ObjectIdentifier(utterance)] else { return }
        guard index == sentences.count - 1 else { return }
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
            self.appleIndexByUtterance.removeAll()
            self.music.duck()
            self.onIndexChange?(self.currentIndex)
            self.refreshNowPlaying()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Ignored: a cancel is always something we asked for.
    }
}
