package com.bikash.storywick.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bikash.storywick.audio.Narrator
import com.bikash.storywick.data.Story
import com.bikash.storywick.ui.theme.ReaderPalette
import com.bikash.storywick.ui.theme.Theme
import kotlinx.coroutines.delay
import kotlin.math.roundToInt

/** Now-Playing-style player — the Compose sibling of iOS Views/ReaderView.swift.
 *  Always the emerald wash, chapter card with the current sentence spotlit, a
 *  scrubber whose thumb is the Storywick mark, and Mood/Voice underneath. */
@Composable
fun ReaderScreen(
    narrator: Narrator,
    story: Story,
    darkTheme: Boolean,
    onBack: () -> Unit,
    onOpenVoice: () -> Unit,
    onOpenMood: () -> Unit,
) {
    val sentences by narrator.sentences.collectAsState()
    val currentIndex by narrator.currentIndex.collectAsState()
    val isSpeaking by narrator.isSpeaking.collectAsState()
    val isPaused by narrator.isPaused.collectAsState()
    val isPreparing by narrator.isPreparing.collectAsState()
    val reading = isSpeaking || isPaused
    val playing = isSpeaking && !isPaused

    val ground = if (darkTheme) Brush.verticalGradient(listOf(ReaderPalette.darkGroundTop, ReaderPalette.darkGround))
    else Brush.verticalGradient(listOf(ReaderPalette.lightGroundTop, ReaderPalette.lightGround))
    val card = if (darkTheme) Brush.linearGradient(listOf(ReaderPalette.darkCard1, ReaderPalette.darkCard2))
    else Brush.linearGradient(listOf(ReaderPalette.lightCard1, ReaderPalette.lightCard2))
    val ink = Theme.colors.textPrimary
    val inkSoft = Theme.colors.textSecondary
    val inkFaint = Theme.colors.textFaint
    val accent = Theme.colors.accent
    val spark = Theme.colors.spark
    val dimAlpha = if (darkTheme) 0.26f else 0.40f
    val restAlpha = if (darkTheme) 0.82f else 0.88f

    DisposableEffect(story.id) {
        narrator.load(story)
        onDispose { narrator.persistNow() }
    }

    val currentSentence = sentences.getOrNull(currentIndex)?.text
    val activeParagraph = remember(story, currentSentence, reading) {
        if (!reading || currentSentence == null) -1
        else story.paragraphs.indexOfFirst { it.contains(currentSentence) }
    }
    val listState = rememberLazyListState()
    LaunchedEffect(activeParagraph) {
        if (activeParagraph >= 0) listState.animateScrollToItem(activeParagraph)
    }

    Box(Modifier.fillMaxSize().background(ground)) {
        Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp, vertical = 10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, contentDescription = "Back", tint = accent) }
                Spacer(Modifier.weight(1f))
                StorywickMark(Modifier.size(19.dp), animated = true)
                Spacer(Modifier.width(7.dp))
                Text("Storywick", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = ink)
                Spacer(Modifier.weight(1f))
                Spacer(Modifier.size(40.dp))
            }
            Spacer(Modifier.height(6.dp))
            Text(story.title, fontSize = 19.sp, fontWeight = FontWeight.Medium, color = ink, maxLines = 1, modifier = Modifier.fillMaxWidth(), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            Spacer(Modifier.height(14.dp))

            Box(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(26.dp))
                    .background(card)
                    .border(1.dp, accent.copy(alpha = if (playing) 0.5f else 0.2f), RoundedCornerShape(26.dp)),
            ) {
                LazyColumn(Modifier.fillMaxSize(), state = listState, contentPadding = PaddingValues(20.dp)) {
                    itemsIndexed(story.paragraphs) { i, paragraph ->
                        val active = i == activeParagraph
                        Row(Modifier.padding(vertical = 7.dp)) {
                            Box(
                                Modifier
                                    .width(3.dp)
                                    .fillMaxHeight()
                                    .background(if (active) spark else Color.Transparent, RoundedCornerShape(2.dp)),
                            )
                            Spacer(Modifier.width(12.dp))
                            Text(
                                text = styledParagraph(paragraph, if (reading) currentSentence else null, ink, dimAlpha, restAlpha),
                                fontSize = 15.sp,
                                lineHeight = 22.sp,
                            )
                        }
                    }
                }
            }
            Spacer(Modifier.height(14.dp))

            Text(
                text = when {
                    isPreparing -> "Generating the voice…"
                    reading && currentSentence != null -> currentSentence
                    else -> "Tap play to begin"
                },
                color = inkSoft,
                fontSize = 14.sp,
                maxLines = 2,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                modifier = Modifier.fillMaxWidth().height(40.dp),
            )

            PlaybackScrubber(narrator, sentences.size, accent, inkFaint)
            Spacer(Modifier.height(4.dp))

            Row(
                Modifier.fillMaxWidth().padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Spacer(Modifier.width(46.dp))
                IconButton(onClick = { narrator.skip(-1) }) {
                    Icon(Icons.Filled.FastRewind, contentDescription = "Back", tint = ink, modifier = Modifier.size(26.dp))
                }
                Box(
                    Modifier
                        .size(78.dp)
                        .clip(CircleShape)
                        .background(accent),
                    contentAlignment = Alignment.Center,
                ) {
                    IconButton(onClick = { narrator.togglePlayPause() }, enabled = !isPreparing) {
                        if (isPreparing) {
                            CircularProgressIndicator(color = ReaderPalette.darkGround, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
                        } else {
                            Icon(
                                if (playing) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                                contentDescription = "Play/Pause",
                                tint = if (darkTheme) ReaderPalette.darkGround else Color.White,
                                modifier = Modifier.size(34.dp),
                            )
                        }
                    }
                }
                IconButton(onClick = { narrator.skip(1) }) {
                    Icon(Icons.Filled.FastForward, contentDescription = "Forward", tint = ink, modifier = Modifier.size(26.dp))
                }
                Spacer(Modifier.width(46.dp))
            }

            val mood by narrator.mood.collectAsState()
            Row(Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 8.dp), horizontalArrangement = Arrangement.Center) {
                SecondaryButton("Mood", if (mood.track == null) Icons.Filled.MusicOff else Icons.Filled.QueueMusic, if (mood.track == null) inkSoft else spark, onOpenMood)
                Spacer(Modifier.width(56.dp))
                SecondaryButton("Voice", Icons.Filled.Tune, inkSoft, onOpenVoice)
            }
        }
    }
}

@Composable
private fun SecondaryButton(label: String, icon: androidx.compose.ui.graphics.vector.ImageVector, tint: Color, onClick: () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.clickableNoRipple(onClick)) {
        Icon(icon, contentDescription = label, tint = tint, modifier = Modifier.size(20.dp))
        Spacer(Modifier.height(3.dp))
        Text(label, fontSize = 11.sp, color = tint)
    }
}

private fun styledParagraph(paragraph: String, activeSentence: String?, ink: Color, dimAlpha: Float, restAlpha: Float) =
    buildAnnotatedString {
        val range = activeSentence?.let { s -> if (paragraph.contains(s)) paragraph.indexOf(s) to s.length else null }
        if (range == null) {
            withStyle(SpanStyle(color = ink.copy(alpha = if (activeSentence != null) dimAlpha else restAlpha))) { append(paragraph) }
        } else {
            val (start, len) = range
            withStyle(SpanStyle(color = ink.copy(alpha = dimAlpha))) { append(paragraph.substring(0, start)) }
            withStyle(SpanStyle(color = ink)) { append(paragraph.substring(start, start + len)) }
            withStyle(SpanStyle(color = ink.copy(alpha = dimAlpha))) { append(paragraph.substring(start + len)) }
        }
    }

/** Progress bar + elapsed/total clock, thumb is the spinning Storywick mark.
 *  Estimated timeline (word count / speaking rate), same approach as iOS's
 *  PlaybackScrubber — neither engine exposes a real playback clock. */
@Composable
private fun PlaybackScrubber(narrator: Narrator, sentenceCount: Int, accent: Color, faint: Color) {
    val sentences by narrator.sentences.collectAsState()
    val currentIndex by narrator.currentIndex.collectAsState()
    val isSpeaking by narrator.isSpeaking.collectAsState()
    val isPaused by narrator.isPaused.collectAsState()
    val speed = narrator.speed
    val playing = isSpeaking && !isPaused

    val (starts, durations, total) = remember(sentences, speed) {
        val wps = 2.55f * speed
        var acc = 0f
        val st = mutableListOf<Float>(); val du = mutableListOf<Float>()
        for (s in sentences) {
            val words = s.text.split(" ", "\n").count { it.isNotBlank() }.coerceAtLeast(1)
            val d = (words / wps + 0.3f).coerceAtLeast(0.9f)
            st.add(acc); du.add(d); acc += d
        }
        Triple(st, du, acc)
    }

    var elapsed by remember { mutableFloatStateOf(0f) }
    var dragFraction by remember { mutableStateOf<Float?>(null) }
    LaunchedEffect(currentIndex, sentences) {
        if (dragFraction == null) elapsed = starts.getOrElse(currentIndex) { 0f }
    }
    LaunchedEffect(playing) {
        while (playing && dragFraction == null) {
            delay(250)
            val cap = (starts.getOrElse(currentIndex) { 0f }) + (durations.getOrElse(currentIndex) { 0f })
            elapsed = (elapsed + 0.25f).coerceAtMost(cap)
        }
    }

    val span = total.coerceAtLeast(1f)
    val fraction = dragFraction ?: (elapsed / span).coerceIn(0f, 1f)
    val shown = dragFraction?.let { it * span } ?: elapsed

    // `pointerInput(Unit)` launches its gesture-detection coroutine exactly once
    // and then keeps running for as long as this composable stays alive — so
    // anything the drag math reads has to be a live reference (rememberUpdatedState
    // / PointerInputScope.size), never a plain `val` snapshotted from the
    // composition that happened to be current when the coroutine first launched.
    // That was the actual bug: keying on `sentences` still only launches once per
    // chapter, so every position it used was frozen from that first moment.
    val latestFraction = rememberUpdatedState(fraction)
    val latestSpan = rememberUpdatedState(span)
    val latestStarts = rememberUpdatedState(starts)

    Column {
        BoxWithConstraints(Modifier.fillMaxWidth().height(26.dp)) {
            val widthPx = constraints.maxWidth.toFloat()
            val thumbPx = with(androidx.compose.ui.platform.LocalDensity.current) { 26.dp.toPx() }
            val usable = (widthPx - thumbPx).coerceAtLeast(1f)
            val x = thumbPx / 2f + usable * fraction

            Box(
                Modifier
                    .fillMaxSize()
                    .pointerInput(Unit) {
                        detectHorizontalDragGestures(
                            onDragStart = { dragFraction = latestFraction.value },
                            onDragEnd = {
                                val f = dragFraction ?: return@detectHorizontalDragGestures
                                val time = f * latestSpan.value
                                val startsNow = latestStarts.value
                                val target = startsNow.indexOfLast { it <= time }.coerceAtLeast(0)
                                elapsed = startsNow.getOrElse(target) { 0f }
                                dragFraction = null
                                narrator.seek(target)
                            },
                        ) { change, dragAmount ->
                            change.consume()
                            val liveWidthPx = size.width.toFloat()
                            val liveUsable = (liveWidthPx - thumbPx).coerceAtLeast(1f)
                            val currentFraction = dragFraction ?: latestFraction.value
                            val currentX = thumbPx / 2f + liveUsable * currentFraction
                            val newX = (currentX + dragAmount).coerceIn(thumbPx / 2f, liveWidthPx - thumbPx / 2f)
                            dragFraction = ((newX - thumbPx / 2f) / liveUsable).coerceIn(0f, 1f)
                        }
                    },
            ) {
                Canvas(Modifier.fillMaxSize()) {
                    val trackY = size.height / 2f
                    drawLine(faint.copy(alpha = 0.3f), Offset(0f, trackY), Offset(size.width, trackY), strokeWidth = 4.dp.toPx())
                    drawLine(accent, Offset(0f, trackY), Offset(x, trackY), strokeWidth = 4.dp.toPx())
                }
                Box(Modifier.offset { IntOffset((x - thumbPx / 2f).roundToInt(), 0) }.size(26.dp)) {
                    SpinningMark(active = playing && dragFraction == null)
                }
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(clock(shown), color = faint, fontSize = 12.sp)
            Text(clock(total), color = faint, fontSize = 12.sp)
        }
    }
}

@Composable
private fun SpinningMark(active: Boolean) {
    var angle by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(active) {
        while (active) {
            delay(1000L / 30)
            angle = (angle + 3f) % 360f
        }
    }
    Box(Modifier.fillMaxSize().rotate(angle)) {
        StorywickMark(Modifier.fillMaxSize())
    }
}

private fun clock(seconds: Float): String {
    val s = seconds.roundToInt().coerceAtLeast(0)
    return "${s / 60}:${(s % 60).toString().padStart(2, '0')}"
}

@Composable
private fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier = this.then(
    Modifier.clickable(
        interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
        indication = null,
        onClick = onClick,
    ),
)
