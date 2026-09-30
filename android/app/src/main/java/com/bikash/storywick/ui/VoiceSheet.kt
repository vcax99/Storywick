package com.bikash.storywick.ui

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bikash.storywick.audio.KokoroTts
import com.bikash.storywick.audio.Narrator
import com.bikash.storywick.audio.kokoroVoices
import com.bikash.storywick.ui.theme.Theme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VoiceSheet(narrator: Narrator, onDismiss: () -> Unit) {
    val colors = Theme.colors
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var previewing by remember { mutableStateOf(false) }
    var voice by remember { mutableIntStateOf(narrator.kokoroVoice) }
    var speed by remember { mutableFloatStateOf(narrator.speed) }
    var volume by remember { mutableFloatStateOf(narrator.volume) }

    fun applyLive() {
        narrator.kokoroVoice = voice
        narrator.speed = speed
        narrator.volume = volume
        narrator.applyLiveChange()
    }

    fun preview() {
        scope.launch {
            previewing = true
            withContext(Dispatchers.Default) {
                val tts = KokoroTts.getOrCreate(context.applicationContext) ?: return@withContext
                val audio = runCatching { tts.synthesize("This is how I sound, telling your story.", voice, speed) }.getOrNull()
                    ?: return@withContext
                playOnce(audio.samples, tts.sampleRate, volume)
            }
            previewing = false
        }
    }

    ModalBottomSheet(onDismissRequest = { applyLive(); onDismiss() }, containerColor = colors.background) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 24.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Voice", fontWeight = FontWeight.Medium, color = colors.textPrimary, fontSize = 21.sp)
                FilledTonalButton(onClick = { if (previewing) Unit else preview() }, enabled = !previewing) {
                    if (previewing) {
                        CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp, color = colors.accent)
                    } else {
                        Icon(Icons.Filled.PlayArrow, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Preview")
                    }
                }
            }
            Spacer(Modifier.height(12.dp))

            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.heightIn(max = 340.dp),
            ) {
                items(kokoroVoices) { v ->
                    val selected = v.id == voice
                    Column(
                        Modifier
                            .clip(RoundedCornerShape(14.dp))
                            .background(colors.surface)
                            .border(if (selected) 2.dp else 1.dp, if (selected) colors.accent else colors.stroke, RoundedCornerShape(14.dp))
                            .clickable { voice = v.id; applyLive() }
                            .padding(12.dp),
                    ) {
                        Icon(Icons.Filled.RecordVoiceOver, contentDescription = null, tint = colors.accent, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.height(6.dp))
                        Text(v.voiceName, color = colors.textPrimary, fontWeight = FontWeight.SemiBold)
                        Text("${v.gender} · ${v.accent}", color = colors.textSecondary, fontSize = 12.sp)
                    }
                }
            }

            Spacer(Modifier.height(20.dp))
            EqualizerRow("Speed", speed, 0.5f..2f, "${"%.2f".format(speed)}×") { speed = it; applyLive() }
            EqualizerRow("Volume", volume, 0f..1f, "${(volume * 100).toInt()}%") { volume = it; applyLive() }

            TextButton(onClick = { voice = 1; speed = 1f; volume = 1f; applyLive() }, modifier = Modifier.align(Alignment.End)) {
                Icon(Icons.Filled.Restore, contentDescription = null, tint = colors.accent, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(4.dp))
                Text("Reset", color = colors.accent)
            }
        }
    }
}

@Composable
private fun EqualizerRow(label: String, value: Float, range: ClosedFloatingPointRange<Float>, valueLabel: String, onChange: (Float) -> Unit) {
    val colors = Theme.colors
    Column(Modifier.padding(top = 8.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(label, color = colors.textPrimary, fontWeight = FontWeight.Medium)
            Text(valueLabel, color = colors.textSecondary, fontSize = 13.sp)
        }
        Slider(
            value = value, onValueChange = onChange, valueRange = range,
            colors = SliderDefaults.colors(thumbColor = colors.accent, activeTrackColor = colors.accent, inactiveTrackColor = colors.stroke),
        )
    }
}

private fun playOnce(samples: FloatArray, sampleRate: Int, volume: Float) {
    val format = AudioFormat.Builder()
        .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
        .setSampleRate(sampleRate)
        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
        .build()
    val attrs = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()
    val track = runCatching {
        AudioTrack.Builder()
            .setAudioAttributes(attrs)
            .setAudioFormat(format)
            .setBufferSizeInBytes(samples.size * 4)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
    }.getOrNull() ?: return
    track.setVolume(volume)
    track.write(samples, 0, samples.size, AudioTrack.WRITE_BLOCKING)
    track.play()
    val durationMs = (samples.size.toFloat() / sampleRate * 1000).toLong() + 200
    Thread.sleep(durationMs.coerceAtMost(15_000))
    track.stop()
    track.release()
}
