package com.bikash.storywick.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.min

/**
 * Plays a chapter with the Kokoro neural engine. Mirrors iOS Audio/KokoroPlayer.swift's
 * intent (stay far enough ahead of playback that a locked screen doesn't starve it)
 * but not its literal shape: unlike AVAudioPlayerNode, which happily queues many
 * small discrete buffers, a single AudioTrack ring buffer has to stay a modest,
 * hardware-sane size — asking it for minutes of audio throws
 * UnsupportedOperationException. So the "how far ahead" cushion lives in a bounded
 * Channel between two coroutines instead: one synthesises forward and can run up to
 * MAX_AHEAD sentences ahead of what's been written to the track, the other drains
 * the channel into the (small) AudioTrack buffer at real-time pace. Both coroutines
 * live inside PlaybackService's foreground-service process, which Android doesn't
 * throttle the way iOS throttles a backgrounded app, so this is comfortably more
 * resilient than the iOS equivalent needed to be.
 */
class KokoroPlayer(private val appContext: Context) {

    var onAdvance: ((Int) -> Unit)? = null
    var onFinish: (() -> Unit)? = null
    var onPreparingChange: ((Boolean) -> Unit)? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var genJob: Job? = null
    private var writeJob: Job? = null
    private var tickJob: Job? = null
    private var audioTrack: AudioTrack? = null
    private var queue: Channel<IndexedSamples>? = null

    private var sentences: List<String> = emptyList()
    private var voice = DEFAULT_VOICE_ID
    private var speed = 1f
    var volume: Float = 1f
        set(value) {
            field = value
            audioTrack?.setVolume(value)
        }

    private var generation = 0
    @Volatile private var wantsPlaying = false
    @Volatile private var playingIndex = 0

    /** Cumulative frame count at the start of each sentence, filled in as it's
     *  written to the track — lets the ticker map the play head back to
     *  "which sentence is coming out of the speaker right now". */
    private val boundaryFrames = mutableListOf<Long>()
    private var totalFrames = 0L

    private data class IndexedSamples(val index: Int, val samples: FloatArray)

    fun ensureAvailable(): Boolean = KokoroTts.isInstalled(appContext)

    fun configure(sentences: List<String>, voice: Int, speed: Float, volume: Float) {
        this.sentences = sentences
        this.voice = voice
        this.speed = speed
        this.volume = volume
    }

    fun play(fromIndex: Int) {
        if (sentences.isEmpty()) return
        hardStop()

        generation++
        val gen = generation
        playingIndex = fromIndex.coerceIn(0, sentences.lastIndex)
        boundaryFrames.clear()
        totalFrames = 0
        wantsPlaying = true

        // Model load (and, the very first time, copying ~150 MB out of assets)
        // can take real seconds — show "preparing" immediately and do all of
        // that off the calling (UI) thread, instead of freezing the tap.
        onPreparingChange?.invoke(true)
        scope.launch { setUpAndPlay(gen, playingIndex) }
    }

    private suspend fun setUpAndPlay(gen: Int, fromIndex: Int) {
        val tts = KokoroTts.getOrCreate(appContext)
        if (tts == null || gen != generation) {
            if (gen == generation) onPreparingChange?.invoke(false)
            return
        }
        val track = buildTrack(tts.sampleRate)
        if (track == null || gen != generation) {
            Log.e(TAG, "Could not create an AudioTrack for this device/sample rate")
            if (gen == generation) onPreparingChange?.invoke(false)
            return
        }

        // Not started yet — writeLoop calls .play() once a couple of sentences
        // are already buffered, so there's a real head start before any sound
        // plays. Writing to a stopped AudioTrack is fine; it just queues.
        audioTrack = track
        val ch = Channel<IndexedSamples>(capacity = MAX_AHEAD)
        queue = ch
        genJob = scope.launch { generateLoop(gen, tts, fromIndex, ch) }
        writeJob = scope.launch { writeLoop(gen, ch) }
        tickJob = scope.launch { tickLoop(gen) }
    }

    fun pause() {
        wantsPlaying = false
        audioTrack?.pause()
    }

    fun resume() {
        wantsPlaying = true
        audioTrack?.play()
    }

    fun stop() {
        wantsPlaying = false
        hardStop()
    }

    /** Re-assert playback after an interruption (audio focus loss ended, etc.). */
    fun reassert() {
        if (!wantsPlaying) return
        audioTrack?.play()
    }

    private fun hardStop() {
        generation++
        genJob?.cancel(); genJob = null
        writeJob?.cancel(); writeJob = null
        tickJob?.cancel(); tickJob = null
        queue?.close(); queue = null
        audioTrack?.runCatching { stop(); flush(); release() }
        audioTrack = null
    }

    private fun buildTrack(sampleRate: Int): AudioTrack? {
        val format = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
            .setSampleRate(sampleRate)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .build()
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val minBuf = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT)
        if (minBuf <= 0) {
            Log.e(TAG, "getMinBufferSize returned $minBuf for sampleRate=$sampleRate")
            return null
        }
        // ~24s of headroom (a few MB) — enough that a sentence which takes longer
        // to synthesise than it does to play doesn't audibly starve playback; the
        // few-hundred-KB size tried earlier was nowhere near enough for that.
        // AudioTrack is fine with buffers this size; it's *minutes* it refuses.
        val bufferBytes = (sampleRate * 4 * 24).coerceAtLeast(minBuf * 4)
        return runCatching {
            AudioTrack.Builder()
                .setAudioAttributes(attrs)
                .setAudioFormat(format)
                .setBufferSizeInBytes(bufferBytes)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
                .apply { setVolume(volume) }
        }.onFailure { Log.e(TAG, "AudioTrack.Builder.build failed", it) }.getOrNull()
    }

    /** Runs on Dispatchers.Default. Synthesises forward; `send` suspends once
     *  MAX_AHEAD sentences are queued and not yet written to the track. */
    private suspend fun generateLoop(gen: Int, tts: KokoroTts, startIndex: Int, ch: Channel<IndexedSamples>) {
        for (i in startIndex until sentences.size) {
            if (gen != generation) return
            val audio = runCatching { tts.synthesize(sentences[i], voice, speed) }
                .onFailure { Log.e(TAG, "synth failed", it) }
                .getOrNull() ?: continue
            if (gen != generation) return
            val samples = trimSilence(audio.samples)
            val sent = runCatching { ch.send(IndexedSamples(i, samples)) }
            if (sent.isFailure) return
        }
        if (gen == generation) runCatching { ch.close() }
    }

    /** Runs on Dispatchers.Default. Drains the channel into the AudioTrack;
     *  `write(.., WRITE_BLOCKING)` blocks here (not the generate loop) once the
     *  hardware buffer is briefly full. */
    private suspend fun writeLoop(gen: Int, ch: Channel<IndexedSamples>) {
        var announced = false
        var started = false
        var sentencesBuffered = 0
        for (item in ch) {
            if (gen != generation) return
            val track = audioTrack ?: return
            boundaryFrames.add(totalFrames)
            totalFrames += item.samples.size
            if (!announced) {
                announced = true
                onPreparingChange?.invoke(false)
                onAdvance?.invoke(item.index)
            }
            var offset = 0
            while (offset < item.samples.size && gen == generation) {
                val written = track.write(item.samples, offset, item.samples.size - offset, AudioTrack.WRITE_BLOCKING)
                if (written <= 0) break
                offset += written
            }
            // Hold off actually starting playback until a couple of sentences
            // are already sitting in the buffer, so a slow one later doesn't
            // immediately run the track dry — the gap the user is hearing.
            sentencesBuffered++
            if (!started && sentencesBuffered >= PREBUFFER_SENTENCES && gen == generation) {
                started = true
                track.play()
            }
        }
        if (!started && gen == generation) {
            // Chapter finished synthesising before we hit the pre-buffer target
            // (a very short one) — nothing queued to wait for, just start.
            started = true
            audioTrack?.play()
        }
        if (gen == generation) {
            val track = audioTrack
            val tailFrames = totalFrames
            while (gen == generation && track != null && track.playbackHeadPosition < tailFrames) {
                delay(150)
            }
            if (gen == generation) {
                wantsPlaying = false
                onFinish?.invoke()
            }
        }
    }

    /** Polls the play head a few times a second and maps it to a sentence index. */
    private suspend fun tickLoop(gen: Int) {
        while (gen == generation) {
            val track = audioTrack
            if (track != null && wantsPlaying) {
                val head = track.playbackHeadPosition.toLong()
                val idx = indexForFrame(head)
                if (idx != playingIndex) {
                    playingIndex = idx
                    onAdvance?.invoke(idx)
                }
            }
            delay(200)
        }
    }

    private fun indexForFrame(frame: Long): Int {
        if (boundaryFrames.isEmpty()) return playingIndex
        var lo = 0
        var hi = boundaryFrames.lastIndex
        while (lo < hi) {
            val mid = (lo + hi + 1) / 2
            if (boundaryFrames[mid] <= frame) lo = mid else hi = mid - 1
        }
        return min(lo, sentences.lastIndex)
    }

    /** Strips near-silence at both ends so sentences butt together instead of
     *  lurching, same threshold approach as iOS's trimmedForSpeech(). */
    private fun trimSilence(samples: FloatArray): FloatArray {
        if (samples.isEmpty()) return samples
        val threshold = 0.006f
        var start = 0
        while (start < samples.size && kotlin.math.abs(samples[start]) < threshold) start++
        var end = samples.size
        while (end > start && kotlin.math.abs(samples[end - 1]) < threshold) end--
        val leadPad = (0.015f * 24000).toInt().coerceAtMost(start)
        val tailPad = (0.1f * 24000).toInt().coerceAtMost(samples.size - end)
        val from = (start - leadPad).coerceAtLeast(0)
        val to = (end + tailPad).coerceAtMost(samples.size)
        return if (from == 0 && to == samples.size) samples else samples.copyOfRange(from, to)
    }

    companion object {
        private const val TAG = "KokoroPlayer"
        const val DEFAULT_VOICE_ID = 1 // Bella
        private const val MAX_AHEAD = 50
        private const val PREBUFFER_SENTENCES = 2
    }
}
