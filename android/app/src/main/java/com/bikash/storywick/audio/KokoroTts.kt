package com.bikash.storywick.audio

import android.content.Context
import android.util.Log
import com.k2fsa.sherpa.onnx.GeneratedAudio
import com.k2fsa.sherpa.onnx.OfflineTts
import com.k2fsa.sherpa.onnx.OfflineTtsConfig
import com.k2fsa.sherpa.onnx.OfflineTtsKokoroModelConfig
import com.k2fsa.sherpa.onnx.OfflineTtsModelConfig
import java.io.File

/** Loads the Kokoro-82M model and runs synthesis. Mirrors iOS Audio/KokoroTTS.swift:
 *  same model files, same 11-voice set, same on-device inference via sherpa-onnx —
 *  just the Kotlin binding instead of the Swift one. */
class KokoroTts private constructor(private val tts: OfflineTts) {

    val voiceCount: Int get() = 11
    val sampleRate: Int get() = tts.sampleRate()

    /** Blocking synth — call off the main thread. Speed 1.0 = natural. */
    fun synthesize(text: String, voice: Int, speed: Float): GeneratedAudio =
        tts.generate(text = text, sid = voice, speed = speed)

    companion object {
        private const val TAG = "KokoroTts"
        private const val ASSET_DIR = "KokoroModel"

        @Volatile private var shared: KokoroTts? = null

        /** True once the model has been copied out of assets and is ready to load
         *  — cheap to call repeatedly (falls back to Android's built-in TTS if false). */
        fun isInstalled(context: Context): Boolean =
            modelDir(context).let { File(it, "model.int8.onnx").exists() } ||
                runCatching { context.assets.list(ASSET_DIR)?.isNotEmpty() == true }.getOrDefault(false)

        /** Model load is ~0.4s on-device; call once and reuse. */
        fun getOrCreate(context: Context): KokoroTts? {
            shared?.let { return it }
            return synchronized(this) {
                shared ?: runCatching { create(context) }
                    .onFailure { Log.e(TAG, "Kokoro load failed", it) }
                    .getOrNull()
                    ?.also { shared = it }
            }
        }

        private fun modelDir(context: Context) = File(context.filesDir, ASSET_DIR)

        private fun create(context: Context): KokoroTts {
            val dir = ensureCopiedFromAssets(context)
            val kokoro = OfflineTtsKokoroModelConfig(
                model = File(dir, "model.int8.onnx").absolutePath,
                voices = File(dir, "voices.bin").absolutePath,
                tokens = File(dir, "tokens.txt").absolutePath,
                dataDir = File(dir, "espeak-ng-data").absolutePath,
            )
            val config = OfflineTtsConfig(
                model = OfflineTtsModelConfig(kokoro = kokoro, numThreads = 2, debug = false, provider = "cpu"),
            )
            val tts = OfflineTts(assetManager = null, config = config)
            Log.i(TAG, "Kokoro ready: ${tts.sampleRate()} Hz")
            return KokoroTts(tts)
        }

        /** espeak-ng needs real filesystem paths (it isn't read through Android's
         *  asset manager), so the model is extracted once into internal storage —
         *  same end state as the iOS folder-reference bundle, just copied instead
         *  of already-on-disk. */
        private fun ensureCopiedFromAssets(context: Context): File {
            val dest = modelDir(context)
            val marker = File(dest, ".complete")
            if (marker.exists()) return dest
            dest.deleteRecursively()
            copyAssetDirRecursively(context, ASSET_DIR, dest)
            marker.createNewFile()
            return dest
        }

        private fun copyAssetDirRecursively(context: Context, assetPath: String, destDir: File) {
            val am = context.assets
            val entries = am.list(assetPath) ?: return
            destDir.mkdirs()
            for (entry in entries) {
                val childAssetPath = "$assetPath/$entry"
                val childDest = File(destDir, entry)
                val subEntries = am.list(childAssetPath)
                if (!subEntries.isNullOrEmpty()) {
                    copyAssetDirRecursively(context, childAssetPath, childDest)
                } else {
                    am.open(childAssetPath).use { input ->
                        childDest.outputStream().use { output -> input.copyTo(output) }
                    }
                }
            }
        }
    }
}
