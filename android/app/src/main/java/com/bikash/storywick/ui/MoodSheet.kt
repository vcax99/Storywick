package com.bikash.storywick.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Restore
import androidx.compose.material.icons.filled.VolumeDown
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bikash.storywick.audio.Narrator
import com.bikash.storywick.data.Mood
import com.bikash.storywick.ui.theme.Theme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MoodSheet(narrator: Narrator, onDismiss: () -> Unit) {
    val colors = Theme.colors
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = colors.background) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 24.dp)) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(colors.surface)
                    .border(1.dp, colors.stroke, RoundedCornerShape(16.dp))
                    .padding(16.dp),
            ) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text("Background level", fontWeight = FontWeight.SemiBold, color = colors.textPrimary, fontSize = 17.sp)
                    TextButton(onClick = { narrator.resetMusicLevel() }) {
                        Icon(Icons.Filled.Restore, contentDescription = null, tint = colors.accent, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Reset", color = colors.accent)
                    }
                }
                Text(
                    "The bed always sits well under the narration — this trims it within that range.",
                    color = colors.textSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 4.dp, bottom = 8.dp),
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.VolumeDown, contentDescription = null, tint = colors.textFaint)
                    Slider(
                        value = narrator.musicLevel,
                        onValueChange = { narrator.musicLevel = it },
                        modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                        colors = SliderDefaults.colors(thumbColor = colors.accent, activeTrackColor = colors.accent, inactiveTrackColor = colors.stroke),
                    )
                    Icon(Icons.Filled.VolumeUp, contentDescription = null, tint = colors.textFaint)
                }
            }

            Spacer(Modifier.height(20.dp))
            Text("Mood", fontWeight = FontWeight.Medium, color = colors.textPrimary, fontSize = 19.sp)
            Spacer(Modifier.height(10.dp))

            val currentMood by narrator.mood.collectAsState()
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.heightIn(max = 420.dp),
            ) {
                items(Mood.entries) { mood ->
                    val selected = mood == currentMood
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                        modifier = Modifier
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(14.dp))
                            .background(colors.surface)
                            .border(if (selected) 2.dp else 1.dp, if (selected) colors.accent else colors.stroke, RoundedCornerShape(14.dp))
                            .clickable { narrator.setMood(mood) }
                            .padding(8.dp),
                    ) {
                        Icon(mood.icon, contentDescription = null, tint = if (selected) colors.accent else colors.textSecondary, modifier = Modifier.size(22.dp))
                        Spacer(Modifier.height(6.dp))
                        Text(mood.label, fontSize = 11.sp, color = if (selected) colors.textPrimary else colors.textSecondary, textAlign = androidx.compose.ui.text.style.TextAlign.Center, maxLines = 2)
                    }
                }
            }
        }
    }
}
