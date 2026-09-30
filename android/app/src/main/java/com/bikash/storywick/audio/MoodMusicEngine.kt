package com.bikash.storywick.audio

import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.bikash.storywick.data.Mood
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Loops a mood's background bed quietly under the narration. Mirrors iOS
 * Audio/MoodMusicEngine.swift: every bed is preloaded once at startup so
 * switching moods is instant, volume is capped well under the voice, and
 * changes fade instead of jumping.
 */
class MoodMusicEngine(private val context: Context) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val players = mutableMapOf<String, ExoPlayer>()
    private var current: Mood = Mood.NONE
    private var fadeJob: Job? = null
    private var ducked = true

    /** Trim within the ceiling — 0..1, the "Background level" slider. */
    var level: Float = 1f
        set(value) {
            field = value.coerceIn(0f, 1f)
            if (!ducked) players[current.track]?.volume = MAX_VOLUME * field
        }

    fun preloadAll() {
        scope.launch(Dispatchers.IO) {
            Mood.entries.mapNotNull { it.track }.distinct().forEach { track ->
                runCatching { player(track) }
            }
        }
    }

    /** [play] mirrors whether narration is actively speaking right now. */
    fun setMood(mood: Mood, play: Boolean) {
        val previous = current
        current = mood
        ducked = !play
        if (previous.track != mood.track) {
            previous.track?.let { fadeOutAndPause(it) }
        }
        if (play) start() else duck()
    }

    fun start() {
        ducked = false
        val track = current.track ?: return
        val p = player(track)
        if (!p.isPlaying) p.play()
        fadeTo(track, MAX_VOLUME * level, FADE_IN_MS)
    }

    fun duck() {
        ducked = true
        current.track?.let { fadeOutAndPause(it) }
    }

    fun ensurePlaying() {
        if (!ducked) start()
    }

    fun stop() {
        fadeJob?.cancel()
        current.track?.let { fadeOutAndPause(it) }
    }

    fun release() {
        fadeJob?.cancel()
        players.values.forEach { it.release() }
        players.clear()
    }

    private fun player(track: String): ExoPlayer =
        players.getOrPut(track) {
            ExoPlayer.Builder(context).build().apply {
                setMediaItem(MediaItem.fromUri("asset:///MoodMusic/$track.m4a"))
                repeatMode = Player.REPEAT_MODE_ONE
                volume = 0f
                prepare()
            }
        }

    private fun fadeOutAndPause(track: String) {
        val p = players[track] ?: return
        fadeJob?.cancel()
        fadeJob = scope.launch {
            fadeVolume(p, p.volume, 0f, FADE_OUT_MS)
            p.pause()
        }
    }

    private fun fadeTo(track: String, target: Float, durationMs: Long) {
        val p = players[track] ?: return
        fadeJob?.cancel()
        fadeJob = scope.launch { fadeVolume(p, p.volume, target, durationMs) }
    }

    private suspend fun fadeVolume(player: ExoPlayer, from: Float, to: Float, durationMs: Long) {
        val steps = 12
        val stepMs = durationMs / steps
        for (i in 1..steps) {
            player.volume = from + (to - from) * (i / steps.toFloat())
            kotlinx.coroutines.delay(stepMs)
        }
    }

    companion object {
        private const val MAX_VOLUME = 0.22f
        private const val FADE_IN_MS = 300L
        private const val FADE_OUT_MS = 350L
    }
}
