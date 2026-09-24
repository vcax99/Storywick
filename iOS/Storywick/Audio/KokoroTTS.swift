import AVFoundation
import Foundation
import OSLog
import SherpaOnnx

/// Low-level wrapper around the bundled Kokoro neural TTS model (sherpa-onnx / ONNX Runtime, CPU).
/// Synthesis is blocking — always call `synthesize` off the main thread.
final class KokoroTTS {

    struct Clip {
        let samples: [Float]
        let sampleRate: Double
    }

    static let log = Logger(subsystem: "com.bikash.Storywick", category: "Kokoro")

    /// One shared model instance — loaded on first access (~0.4 s), off the main
    /// thread if that's where it's first touched. Nil if the files are missing.
    static let shared: KokoroTTS? = KokoroTTS()

    let sampleRate: Double
    let voiceCount: Int

    private let tts: SherpaOnnxOfflineTtsWrapper

    /// Returns nil if the model files are missing or the engine fails to start.
    init?() {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("KokoroModel", isDirectory: true) else {
            KokoroTTS.log.error("No resourceURL")
            return nil
        }

        let model = root.appendingPathComponent("model.int8.onnx").path
        let voices = root.appendingPathComponent("voices.bin").path
        let tokens = root.appendingPathComponent("tokens.txt").path
        let dataDir = root.appendingPathComponent("espeak-ng-data").path

        guard FileManager.default.fileExists(atPath: model),
              FileManager.default.fileExists(atPath: voices),
              FileManager.default.fileExists(atPath: tokens),
              FileManager.default.fileExists(atPath: dataDir) else {
            KokoroTTS.log.error("Kokoro model files missing under \(root.path, privacy: .public)")
            return nil
        }

        let kokoro = sherpaOnnxOfflineTtsKokoroModelConfig(
            model: model,
            voices: voices,
            tokens: tokens,
            dataDir: dataDir,
            lengthScale: 1.0
        )
        let modelConfig = sherpaOnnxOfflineTtsModelConfig(
            kokoro: kokoro,
            numThreads: 2,
            debug: 0,
            provider: "cpu"
        )
        var config = sherpaOnnxOfflineTtsConfig(model: modelConfig, maxNumSentences: 1)

        tts = SherpaOnnxOfflineTtsWrapper(config: &config)
        sampleRate = Double(tts.sampleRate)
        voiceCount = Int(tts.numSpeakers)

        guard voiceCount > 0, sampleRate > 0 else {
            KokoroTTS.log.error("Kokoro init failed: speakers=\(self.voiceCount) rate=\(self.sampleRate)")
            return nil
        }
        KokoroTTS.log.info("Kokoro ready: \(self.voiceCount) voices @ \(Int(self.sampleRate)) Hz")
    }

    /// Blocking synthesis. `speed` 0.5–2.0 (1.0 = natural). Run off the main thread.
    func synthesize(_ text: String, voice: Int, speed: Float) -> Clip {
        let audio = tts.generate(
            text: text,
            sid: max(0, min(voice, voiceCount - 1)),
            speed: max(0.5, min(speed, 2.0))
        )
        return Clip(samples: audio.samples, sampleRate: Double(audio.sampleRate))
    }

    /// Whether the bundled model files are present (fast — no model load).
    static var isInstalled: Bool {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("KokoroModel", isDirectory: true) else {
            return false
        }
        return FileManager.default.fileExists(atPath: root.appendingPathComponent("model.int8.onnx").path)
    }

    #if DEBUG
    /// One-shot smoke test — logs timing and sample count.
    static func runSelfTest() {
        DispatchQueue.global(qos: .userInitiated).async {
            let start = Date()
            guard let engine = KokoroTTS() else {
                log.error("SELFTEST: engine init returned nil")
                return
            }
            let loaded = Date().timeIntervalSince(start)
            let genStart = Date()
            let clip = engine.synthesize(
                "The night was quiet, and the old house held its breath.",
                voice: 0,
                speed: 1.0
            )
            let gen = Date().timeIntervalSince(genStart)
            let seconds = Double(clip.samples.count) / clip.sampleRate
            log.info("""
            SELFTEST ok — load \(String(format: "%.2f", loaded))s, \
            gen \(String(format: "%.2f", gen))s for \(String(format: "%.1f", seconds))s of audio \
            (\(clip.samples.count) samples @ \(Int(clip.sampleRate)) Hz)
            """)
        }
    }
    #endif
}

extension KokoroTTS.Clip {
    /// Strip near-silence from both ends, keeping a short lead-in and a small beat
    /// after so sentences butt together instead of lurching.
    func trimmedForSpeech() -> KokoroTTS.Clip {
        guard samples.count > 32 else { return self }
        let threshold: Float = 0.006
        var lo = 0
        while lo < samples.count, abs(samples[lo]) < threshold { lo += 1 }
        var hi = samples.count - 1
        while hi > lo, abs(samples[hi]) < threshold { hi -= 1 }
        guard lo < hi else { return self }
        let leadPad = Int(sampleRate * 0.015)
        let tailPad = Int(sampleRate * 0.10)
        let a = max(0, lo - leadPad)
        let b = min(samples.count, hi + tailPad + 1)
        return KokoroTTS.Clip(samples: Array(samples[a..<b]), sampleRate: sampleRate)
    }

    func pcmBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              abs(sampleRate - format.sampleRate) < 1,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            channel[0].update(from: src.baseAddress!, count: src.count)
        }
        return buffer
    }
}
