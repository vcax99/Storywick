package com.bikash.storywick

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.lifecycleScope
import com.bikash.storywick.audio.Narrator
import com.bikash.storywick.data.AppConfig
import com.bikash.storywick.data.AppDatabase
import com.bikash.storywick.data.Story
import com.bikash.storywick.ui.HomeScreen
import com.bikash.storywick.ui.MoodSheet
import com.bikash.storywick.ui.ReaderScreen
import com.bikash.storywick.ui.StorywickMark
import com.bikash.storywick.ui.VoiceSheet
import com.bikash.storywick.ui.theme.StorywickTheme
import kotlinx.coroutines.launch

private sealed class Screen {
    data object Home : Screen()
    data class Reader(val storyId: Long) : Screen()
}

class MainActivity : ComponentActivity() {
    private val narrator: Narrator get() = (application as StorywickApplication).narrator
    private val dao by lazy { AppDatabase.get(this).storyDao() }
    private val prefs by lazy { getSharedPreferences("app", Context.MODE_PRIVATE) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            var showSplash by remember { mutableStateOf(true) }
            var darkTheme by remember { mutableStateOf(prefs.getBoolean(KEY_DARK, true)) }
            var screen by remember { mutableStateOf<Screen>(Screen.Home) }
            var showVoice by remember { mutableStateOf(false) }
            var showMood by remember { mutableStateOf(false) }
            val stories by produceState(initialValue = emptyList<Story>()) {
                dao.observeAll().collect { value = it }
            }

            LaunchedEffect(Unit) {
                kotlinx.coroutines.delay(4000)
                showSplash = false
            }

            StorywickTheme(darkTheme = if (showSplash) true else darkTheme) {
                Surface(color = androidx.compose.ui.graphics.Color.Unspecified) {
                    Box(Modifier.fillMaxSize()) {
                        when (val s = screen) {
                            is Screen.Home -> HomeScreen(
                                narrator = narrator,
                                stories = stories,
                                darkTheme = darkTheme,
                                onToggleTheme = {
                                    darkTheme = !darkTheme
                                    prefs.edit().putBoolean(KEY_DARK, darkTheme).apply()
                                },
                                onOpenStory = { id -> screen = Screen.Reader(id) },
                                onInsertStory = { story ->
                                    lifecycleScope.launch {
                                        val newId = dao.insert(story)
                                        val all = dao.all()
                                        if (all.size > AppConfig.HISTORY_LIMIT) {
                                            all.drop(AppConfig.HISTORY_LIMIT).forEach { dao.delete(it) }
                                        }
                                        screen = Screen.Reader(newId)
                                    }
                                },
                                onDeleteStory = { story ->
                                    lifecycleScope.launch { dao.delete(story) }
                                },
                            )

                            is Screen.Reader -> {
                                val story = stories.firstOrNull { it.id == s.storyId }
                                if (story != null) {
                                    ReaderScreen(
                                        narrator = narrator,
                                        story = story,
                                        darkTheme = darkTheme,
                                        onBack = { screen = Screen.Home },
                                        onOpenVoice = { showVoice = true },
                                        onOpenMood = { showMood = true },
                                    )
                                }
                            }
                        }

                        AnimatedVisibility(
                            visible = showSplash,
                            exit = fadeOut(tween(450)),
                            modifier = Modifier.fillMaxSize(),
                        ) {
                            SplashContent()
                        }
                    }

                    if (showVoice) VoiceSheet(narrator, onDismiss = { showVoice = false })
                    if (showMood) {
                        val story = (screen as? Screen.Reader)?.storyId?.let { id -> stories.firstOrNull { it.id == id } }
                        if (story != null) MoodSheet(narrator, onDismiss = { showMood = false })
                    }
                }
            }
        }
    }

    companion object {
        private const val KEY_DARK = "darkTheme"
    }
}

@Composable
private fun SplashContent() {
    val ground = Color(0xFF0A0C0B)
    val groundLow = Color(0xFF0E1512)
    val ink = Color(0xFFF8FAFC)
    val inkSoft = Color(0xFF94A3B8)
    val inkFaint = Color(0xFF6E7985)
    var shown by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { shown = true }

    Box(
        Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(ground, groundLow))),
        contentAlignment = Alignment.Center,
    ) {
        AnimatedVisibility(visible = shown, enter = fadeIn(tween(600)) + scaleIn(tween(600), initialScale = 0.82f)) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                StorywickMark(Modifier.size(128.dp), animated = true)
                Spacer(Modifier.height(24.dp))
                Text("Storywick", fontSize = 42.sp, fontWeight = FontWeight.SemiBold, color = ink)
                Spacer(Modifier.height(8.dp))
                Text("Where stories find a voice", color = inkSoft, fontSize = 16.sp)
            }
        }
        Column(
            Modifier.fillMaxSize().padding(bottom = 44.dp),
            verticalArrangement = Arrangement.Bottom,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            AnimatedVisibility(visible = shown, enter = fadeIn(tween(600))) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Powered By", color = inkFaint, fontSize = 14.sp)
                    Text("Pankaj Katoch", color = inkSoft, fontSize = 22.sp, fontWeight = FontWeight.Medium)
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "Version ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
                        color = inkFaint, fontSize = 11.sp,
                    )
                }
            }
        }
    }
}
