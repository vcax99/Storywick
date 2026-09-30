package com.bikash.storywick.audio

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.bikash.storywick.data.AppDatabase
import com.bikash.storywick.data.Mood
import com.bikash.storywick.data.Story
import com.bikash.storywick.data.TextStats
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class Sentence(val index: Int, val text: String)

/**
 * App-level narration coordinator — the Kotlin sibling of iOS Audio/Narrator.swift,
 * minus the dual-engine branching (Kokoro is the only voice on Android; there's no
 * System-TTS fallback here, per product decision). Lives for the process lifetime
 * (owned by StorywickApplication), so background playback survives navigating away
 * from any screen — same "keeps playing when you leave" behaviour as iOS.
 */
class Narrator(private val appContext: Context) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val prefs = appContext.getSharedPreferences("narrator", Context.MODE_PRIVATE)
    private val dao by lazy { AppDatabase.get(appContext).storyDao() }

    val player = KokoroPlayer(appContext)
    val music = MoodMusicEngine(appContext)

    // MARK: Observable state

    private val _sentences = MutableStateFlow<List<Sentence>>(emptyList())
    val sentences: StateFlow<List<Sentence>> = _sentences.asStateFlow()

    private val _currentIndex = MutableStateFlow(0)
    val currentIndex: StateFlow<Int> = _currentIndex.asStateFlow()

    private val _isSpeaking = MutableStateFlow(false)
    val isSpeaking: StateFlow<Boolean> = _isSpeaking.asStateFlow()

    private val _isPaused = MutableStateFlow(false)
    val isPaused: StateFlow<Boolean> = _isPaused.asStateFlow()

    private val _isPreparing = MutableStateFlow(false)
    val isPreparing: StateFlow<Boolean> = _isPreparing.asStateFlow()

    private val _loadedStoryId = MutableStateFlow<Long?>(null)
    val loadedStoryId: StateFlow<Long?> = _loadedStoryId.asStateFlow()

    private val _mood = MutableStateFlow(Mood.MYSTERY)
    val mood: StateFlow<Mood> = _mood.asStateFlow()

    val nowPlayingTitle = MutableStateFlow("Storywick")

    // MARK: Settings (persisted to SharedPreferences, same shape as iOS's UserDefaults use).
    // Backed by Compose State objects (not plain `var`s) so a Slider bound directly
    // to e.g. `narrator.musicLevel` actually recomposes when it changes — a plain
    // var is invisible to Compose's snapshot system and the UI just never updates.

    private val _kokoroVoice = mutableIntStateOf(prefs.getInt(KEY_VOICE, DEFAULT_VOICE_ID))
    var kokoroVoice: Int
        get() = _kokoroVoice.intValue
        set(value) { _kokoroVoice.intValue = value; prefs.edit().putInt(KEY_VOICE, value).apply() }

    private val _speed = mutableFloatStateOf(prefs.getFloat(KEY_SPEED, 1.0f))
    var speed: Float
        get() = _speed.floatValue
        set(value) { _speed.floatValue = value; prefs.edit().putFloat(KEY_SPEED, value).apply() }

    private val _volume = mutableFloatStateOf(prefs.getFloat(KEY_VOLUME, 1.0f))
    var volume: Float
        get() = _volume.floatValue
        set(value) { _volume.floatValue = value; prefs.edit().putFloat(KEY_VOLUME, value).apply() }

    private val _musicLevel = mutableFloatStateOf(prefs.getFloat(KEY_MUSIC, 1.0f))
    var musicLevel: Float
        get() = _musicLevel.floatValue
        set(value) {
            _musicLevel.floatValue = value
            prefs.edit().putFloat(KEY_MUSIC, value).apply()
            music.level = value
        }

    val isActive: Boolean get() = _sentences.value.isNotEmpty() && (_isSpeaking.value || _isPaused.value)
    val currentSentenceText: String? get() = _sentences.value.getOrNull(_currentIndex.value)?.text
    val isFinished: Boolean
        get() = _sentences.value.isNotEmpty() && _currentIndex.value >= _sentences.value.size - 1
    val progress: Double
        get() = _sentences.value.size.let { n -> if (n > 1) _currentIndex.value.toDouble() / (n - 1) else 0.0 }

    init {
        music.level = musicLevel
        music.preloadAll()
        player.onAdvance = { index ->
            _currentIndex.value = index
            persistNow()
        }
        player.onFinish = {
            _isSpeaking.value = false
            _isPaused.value = false
            persistNow()
        }
        player.onPreparingChange = { _isPreparing.value = it }
    }

    // MARK: Loading

    /** Load a chapter. If it's already the loaded one, playback keeps going
     *  untouched — music-player style, same as iOS. */
    fun load(story: Story) {
        nowPlayingTitle.value = story.title
        if (_loadedStoryId.value == story.id && _sentences.value.isNotEmpty()) return
        stop()
        _loadedStoryId.value = story.id
        _sentences.value = TextStats.sentences(story.text).mapIndexed { i, s -> Sentence(i, s) }
        _currentIndex.value = story.progressIndex.coerceIn(0, (_sentences.value.size - 1).coerceAtLeast(0))
        _mood.value = story.mood
        music.setMood(story.mood, play = false)
    }

    // MARK: Transport

    fun play(fromIndex: Int = _currentIndex.value) {
        if (_sentences.value.isEmpty()) return
        _currentIndex.value = fromIndex.coerceIn(0, _sentences.value.lastIndex)
        _isSpeaking.value = true
        _isPaused.value = false
        music.start()
        player.configure(_sentences.value.map { it.text }, kokoroVoice, speed, volume)
        player.play(_currentIndex.value)
        startPlaybackService()
    }

    fun pause() {
        _isPaused.value = true
        music.duck()
        player.pause()
    }

    fun resume() {
        if (_sentences.value.isEmpty()) return
        _isPaused.value = false
        _isSpeaking.value = true
        music.start()
        player.resume()
        startPlaybackService()
    }

    /** The lock-screen / background-audio surface — a foreground service, same
     *  job the "audio" UIBackgroundMode + NowPlaying did on iOS. */
    private fun startPlaybackService() {
        runCatching {
            ContextCompat.startForegroundService(appContext, Intent(appContext, PlaybackService::class.java))
        }
    }

    fun togglePlayPause() {
        when {
            _isSpeaking.value && !_isPaused.value -> pause()
            _isPaused.value -> resume()
            else -> play(_currentIndex.value)
        }
    }

    fun stop() {
        _isSpeaking.value = false
        _isPaused.value = false
        player.stop()
        music.stop()
    }

    fun seek(to: Int) {
        if (_sentences.value.isEmpty()) return
        val target = to.coerceIn(0, _sentences.value.lastIndex)
        _currentIndex.value = target
        persistNow()
        if (_isSpeaking.value || _isPaused.value) play(target)
    }

    fun skip(delta: Int) = seek(_currentIndex.value + delta)

    /** Speed / pitch / volume changed while playing — re-speak the current
     *  sentence with the new settings, same as iOS's applyLiveChange(). */
    fun applyLiveChange() {
        player.configure(_sentences.value.map { it.text }, kokoroVoice, speed, volume)
        player.volume = volume
        if (_isSpeaking.value && !_isPaused.value) play(_currentIndex.value)
    }

    fun resetEqualizer() {
        speed = 1.0f; volume = 1.0f
        applyLiveChange()
    }

    fun resetMusicLevel() { musicLevel = 1.0f }

    fun setMood(newMood: Mood) {
        _mood.value = newMood
        music.setMood(newMood, play = _isSpeaking.value && !_isPaused.value)
        scope.launch {
            dao.get(_loadedStoryId.value ?: return@launch)?.let { dao.update(it.copy(moodRaw = newMood.name)) }
        }
    }

    /** Flush the reading position to disk now — called on scenePhase-equivalent
     *  (ProcessLifecycleOwner ON_STOP) so a background kill resumes correctly. */
    fun persistNow() {
        val id = _loadedStoryId.value ?: return
        val index = _currentIndex.value
        scope.launch {
            dao.get(id)?.let { dao.update(it.copy(progressIndex = index, lastOpenedAt = System.currentTimeMillis())) }
        }
    }

    companion object {
        private const val KEY_VOICE = "kokoroVoice"
        private const val KEY_SPEED = "speed"
        private const val KEY_VOLUME = "volume"
        private const val KEY_MUSIC = "musicLevel"
    }
}
