package com.bikash.storywick.ui

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bikash.storywick.audio.Narrator
import com.bikash.storywick.data.AppConfig
import com.bikash.storywick.data.Story
import com.bikash.storywick.data.TextStats
import com.bikash.storywick.ui.theme.Theme

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun HomeScreen(
    narrator: Narrator,
    stories: List<Story>,
    darkTheme: Boolean,
    onToggleTheme: () -> Unit,
    onOpenStory: (Long) -> Unit,
    onInsertStory: (Story) -> Unit,
    onDeleteStory: (Story) -> Unit,
) {
    val colors = Theme.colors
    var draft by rememberSaveable { mutableStateOf("") }
    val wordCount = remember(draft) { TextStats.wordCount(draft) }
    val trimmed = draft.trim()
    val isOverLimit = wordCount > AppConfig.WORD_LIMIT
    val canListen = trimmed.isNotEmpty() && !isOverLimit

    val loadedId by narrator.loadedStoryId.collectAsState()
    val isActive = narrator.isActive
    val nowPlaying = stories.firstOrNull { it.id == loadedId }

    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(colors.background, colors.backgroundLow))),
    ) {
        LazyColumn(
            Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp),
            contentPadding = PaddingValues(top = 20.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            item {
                Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            StorywickMark(Modifier.size(38.dp), animated = true)
                            Spacer(Modifier.width(12.dp))
                            Text("Storywick", fontSize = 34.sp, fontWeight = FontWeight.SemiBold, color = colors.textPrimary)
                        }
                        Text("Paste a chapter. Pick a voice. Listen.", color = colors.textSecondary, modifier = Modifier.padding(top = 4.dp))
                    }
                    IconButton(onClick = onToggleTheme) {
                        Icon(
                            if (darkTheme) Icons.Filled.DarkMode else Icons.Filled.LightMode,
                            contentDescription = "Toggle theme",
                            tint = colors.accent,
                        )
                    }
                }
            }

            if (isActive && nowPlaying != null) {
                item { MiniPlayer(narrator, nowPlaying, onClick = { onOpenStory(nowPlaying.id) }) }
            }

            item {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(18.dp))
                        .background(colors.surface)
                        .border(1.dp, colors.stroke, RoundedCornerShape(18.dp)),
                ) {
                    OutlinedTextField(
                        value = draft,
                        onValueChange = { draft = it },
                        placeholder = { Text("Paste your chapter here…", color = colors.textFaint) },
                        modifier = Modifier.fillMaxWidth().heightIn(min = 220.dp),
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = colors.surface,
                            unfocusedContainerColor = colors.surface,
                            focusedIndicatorColor = androidx.compose.ui.graphics.Color.Transparent,
                            unfocusedIndicatorColor = androidx.compose.ui.graphics.Color.Transparent,
                            focusedTextColor = colors.textPrimary,
                            unfocusedTextColor = colors.textPrimary,
                        ),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default),
                    )
                    HorizontalDivider(color = colors.stroke)
                    Row(
                        Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "$wordCount / ${AppConfig.WORD_LIMIT} words",
                            fontSize = 13.sp,
                            color = if (isOverLimit) colors.warning else colors.textSecondary,
                        )
                        if (isOverLimit) {
                            Text("${wordCount - AppConfig.WORD_LIMIT} over", fontSize = 13.sp, color = colors.warning)
                        } else if (trimmed.isNotEmpty()) {
                            TextButton(onClick = { draft = "" }) { Text("Clear") }
                        }
                    }
                }
            }

            item {
                Button(
                    onClick = {
                        val story = Story.new(title = deriveTitle(trimmed), text = trimmed)
                        onInsertStory(story)
                        draft = ""
                    },
                    enabled = canListen,
                    modifier = Modifier.fillMaxWidth().height(54.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = colors.accent, disabledContainerColor = colors.accent.copy(alpha = 0.35f)),
                ) {
                    Icon(Icons.Filled.PlayArrow, contentDescription = null, tint = androidx.compose.ui.graphics.Color.White)
                    Spacer(Modifier.width(8.dp))
                    Text("Listen", color = androidx.compose.ui.graphics.Color.White, fontWeight = FontWeight.SemiBold)
                }
            }

            if (stories.isNotEmpty()) {
                item { Text("Recent", fontSize = 21.sp, fontWeight = FontWeight.Medium, color = colors.textPrimary) }
                items(stories, key = { it.id }) { story ->
                    RecentCard(story, onClick = { onOpenStory(story.id) }, onDelete = { onDeleteStory(story) })
                }
                item {
                    Text(
                        "The last ${AppConfig.HISTORY_LIMIT} chapters are kept — the oldest drops off.",
                        fontSize = 12.sp,
                        color = colors.textFaint,
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MiniPlayer(narrator: Narrator, story: Story, onClick: () -> Unit) {
    val colors = Theme.colors
    val isSpeaking by narrator.isSpeaking.collectAsState()
    val isPaused by narrator.isPaused.collectAsState()
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(colors.surface)
            .border(1.dp, colors.stroke, RoundedCornerShape(14.dp))
            .combinedClickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(story.title, color = colors.textPrimary, fontWeight = FontWeight.SemiBold, maxLines = 1)
            Text(if (isPaused) "Paused" else "Now narrating", color = colors.textSecondary, fontSize = 12.sp)
        }
        IconButton(onClick = { narrator.togglePlayPause() }) {
            Icon(
                if (isSpeaking && !isPaused) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                contentDescription = null,
                tint = colors.accent,
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun RecentCard(story: Story, onClick: () -> Unit, onDelete: () -> Unit) {
    val colors = Theme.colors
    var showMenu by remember { mutableStateOf(false) }
    Box {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(top = 4.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(colors.surface)
                .border(1.dp, colors.stroke, RoundedCornerShape(16.dp))
                .combinedClickable(onClick = onClick, onLongClick = { showMenu = true })
                .padding(16.dp),
        ) {
            Text(story.title, color = colors.textPrimary, fontWeight = FontWeight.Medium, maxLines = 1, fontSize = 17.sp)
            Spacer(Modifier.height(6.dp))
            Text(story.previewLine, color = colors.textSecondary, maxLines = 2, fontSize = 14.sp)
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                LinearProgressIndicator(
                    progress = { story.progressFraction.toFloat() },
                    modifier = Modifier.width(110.dp).height(4.dp).clip(RoundedCornerShape(2.dp)),
                    color = colors.spark,
                    trackColor = colors.stroke,
                )
                Text(story.progressLabel, color = colors.textFaint, fontSize = 12.sp)
                Text("${story.wordCount} words", color = colors.textFaint, fontSize = 12.sp)
            }
        }
        DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
            DropdownMenuItem(text = { Text("Delete") }, onClick = { showMenu = false; onDelete() })
        }
    }
}

private fun deriveTitle(text: String): String {
    val firstLine = text.lineSequence().firstOrNull { it.isNotBlank() } ?: "Untitled Chapter"
    return firstLine.trim().take(60)
}
