import Foundation
import AVFoundation

/// Plays a chapter with the Kokoro neural engine. A background loop synthesises
/// sentences ahead of playback and schedules each PCM buffer on an
/// `AVAudioPlayerNode` as soon as it's ready — the node plays them back to back
/// with no gap, as long as synthesis keeps up on average (it does on a device;
/// on the simulator it stays a few sentences ahead).
final class KokoroPlayer {

    var onAdvance: ((Int) -> Void)?
    var onFinish: (() -> Void)?
    var onPreparingChange: ((Bool) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!

    private var genQueue = DispatchQueue(label: "kokoro-gen.0", qos: .userInitiated)
    private var genSeq = 0

    private var sentences: [String] = []
    private var voice = 0
    private var speed: Float = 1.0

    private var generation = 0          // bumped to invalidate in-flight work
    private var scheduledUpTo = -1      // highest sentence index handed to the node
    private var playingIndex = 0        // sentence currently coming out of the speaker
    private var announcedFirst = false
    private var wantsPlaying = false

    /// How many sentences may sit synthesised-and-queued ahead of the one playing.
    private let maxAhead = 8

    init() {
        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
    }

    func ensureAvailable() -> Bool { KokoroTTS.isInstalled }

    var voiceCount: Int { KokoroTTS.shared?.voiceCount ?? 11 }

    func configure(sentences: [String], voice: Int, speed: Float, volume: Float) {
        self.sentences = sentences
        self.voice = voice
        self.speed = speed
        node.volume = volume
    }

    func setVolume(_ v: Float) { node.volume = v }

    func updateLive(voice: Int, speed: Float, volume: Float) {
        self.voice = voice
        self.speed = speed
        node.volume = volume
    }

    func play(from index: Int) {
        guard ensureAvailable(), !sentences.isEmpty else { return }
        hardStop()

        generation += 1
        genSeq += 1
        genQueue = DispatchQueue(label: "kokoro-gen.\(genSeq)", qos: .userInitiated)
        let gen = generation

        playingIndex = clampIndex(index)
        scheduledUpTo = playingIndex - 1
        announcedFirst = false
        wantsPlaying = true

        AudioHub.shared.activate()
        startEngineIfNeeded()
        node.play()
        onPreparingChange?(true)

        genQueue.async { [weak self] in self?.generateLoop(gen: gen) }
    }

    func pause() {
        wantsPlaying = false
        node.pause()
    }

    func resume() {
        wantsPlaying = true
        AudioHub.shared.activate()
        startEngineIfNeeded()
        node.play()
    }

    func stop() {
        wantsPlaying = false
        hardStop()
    }

    /// Re-assert playback after an interruption / foreground, without restarting.
    func reassert() {
        guard wantsPlaying else { return }
        AudioHub.shared.activate()
        startEngineIfNeeded()
        if !node.isPlaying { node.play() }
    }

    // MARK: - Pipeline

    private func startEngineIfNeeded() {
        if !audioEngine.isRunning {
            audioEngine.prepare()
            try? audioEngine.start()
        }
    }

    private func hardStop() {
        generation += 1
        node.stop()
        if audioEngine.isRunning { audioEngine.pause() }
        scheduledUpTo = -1
    }

    private func clampIndex(_ i: Int) -> Int {
        guard !sentences.isEmpty else { return 0 }
        return min(max(i, 0), sentences.count - 1)
    }

    /// Runs on `genQueue`. Synthesises forward, scheduling each buffer as ready,
    /// pausing when it gets too far ahead of playback.
    private func generateLoop(gen: Int) {
        while gen == generation {
            let ahead = scheduledUpTo - playingIndex
            if ahead >= maxAhead {
                Thread.sleep(forTimeInterval: 0.12)
                continue
            }
            let next = scheduledUpTo + 1
            guard next < sentences.count else { break }

            guard let tts = KokoroTTS.shared, gen == generation else { break }

            let clip = tts.synthesize(sentences[next], voice: voice, speed: speed).trimmedForSpeech()
            guard gen == generation else { break }

            guard let buffer = clip.pcmBuffer(format: format) else {
                scheduledUpTo = next
                continue
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, gen == self.generation else { return }
                if !self.announcedFirst {
                    self.announcedFirst = true
                    self.onPreparingChange?(false)
                    self.onAdvance?(self.playingIndex)
                }
                self.node.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                    DispatchQueue.main.async {
                        guard let self, gen == self.generation else { return }
                        if next + 1 < self.sentences.count {
                            self.playingIndex = next + 1
                            self.onAdvance?(self.playingIndex)
                        } else {
                            self.wantsPlaying = false
                            self.onFinish?()
                            self.hardStop()
                        }
                    }
                }
            }
            scheduledUpTo = next
        }
    }

}
