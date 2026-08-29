import AVFoundation
import Foundation

/// Plays a one-line sample in the currently selected voice — works for both
/// engines, and stands on its own (no chapter needs to be playing).
final class VoicePreviewer {

    private let sample = "The night was quiet, and the old house held its breath, and somewhere far off a bell began to ring."

    private let appleSynth = AVSpeechSynthesizer()

    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!
    private let queue = DispatchQueue(label: "com.bikash.StoryTeller.voice-preview", qos: .userInitiated)
    private var generation = 0

    private(set) var isBusy = false
    var onBusyChange: ((Bool) -> Void)?

    init() {
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    func preview(engine kind: SpeechEngineKind,
                 kokoroVoice: Int,
                 appleVoiceID: String?,
                 speed: Float,
                 pitch: Float,
                 volume: Float) {
        stop()
        AudioHub.shared.activate()

        switch kind {
        case .apple:
            let utterance = AVSpeechUtterance(string: sample)
            if let id = appleVoiceID, let voice = AVSpeechSynthesisVoice(identifier: id) {
                utterance.voice = voice
            }
            let scaled = AVSpeechUtteranceDefaultSpeechRate * speed
            utterance.rate = min(max(scaled, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
            utterance.pitchMultiplier = pitch
            utterance.volume = volume
            appleSynth.speak(utterance)

        case .kokoro:
            guard KokoroTTS.isInstalled else { return }
            generation += 1
            let gen = generation
            setBusy(true)
            node.volume = volume
            if !engine.isRunning { try? engine.start() }
            node.play()
            queue.async { [weak self] in
                guard let self, gen == self.generation, let tts = KokoroTTS.shared else {
                    DispatchQueue.main.async { self?.setBusy(false) }
                    return
                }
                let clip = tts.synthesize(self.sample, voice: kokoroVoice, speed: speed).trimmedForSpeech()
                guard gen == self.generation, let buffer = clip.pcmBuffer(format: self.format) else {
                    DispatchQueue.main.async { self.setBusy(false) }
                    return
                }
                DispatchQueue.main.async {
                    guard gen == self.generation else { return }
                    self.node.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                        DispatchQueue.main.async {
                            guard let self, gen == self.generation else { return }
                            self.setBusy(false)
                        }
                    }
                    self.setBusy(false)
                }
            }
        }
    }

    func stop() {
        generation += 1
        appleSynth.stopSpeaking(at: .immediate)
        node.stop()
        setBusy(false)
    }

    private func setBusy(_ value: Bool) {
        guard isBusy != value else { return }
        isBusy = value
        onBusyChange?(value)
    }
}
