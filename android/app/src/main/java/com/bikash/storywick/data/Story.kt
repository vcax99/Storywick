package com.bikash.storywick.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import kotlin.math.min

/** One pasted chapter. Room-backed, mirrors iOS Model/Story.swift field for
 *  field. Room entities are immutable data classes, so updates go through
 *  `story.copy(...)` + `StoryDao.update(...)` rather than in-place mutation. */
@Entity(tableName = "stories")
data class Story(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val text: String,
    val createdAt: Long,
    val lastOpenedAt: Long,
    val progressIndex: Int = 0,
    val sentenceCount: Int = 0,
    val moodRaw: String = Mood.MYSTERY.name,
) {
    val mood: Mood get() = Mood.from(moodRaw)

    val wordCount: Int get() = TextStats.wordCount(text)

    val paragraphs: List<String>
        get() = text.replace("\r\n", "\n")
            .split("\n\n")
            .map { it.trim() }
            .filter { it.isNotEmpty() }

    val previewLine: String
        get() = text.trim().replace("\n", " ").take(160)

    val progressFraction: Double
        get() = if (sentenceCount > 1) min(progressIndex.toDouble() / (sentenceCount - 1), 1.0) else 0.0

    val isFinished: Boolean
        get() = sentenceCount > 0 && progressIndex >= sentenceCount - 1

    val progressLabel: String
        get() = when {
            progressIndex == 0 -> "Not started"
            isFinished -> "Finished"
            else -> "${(progressFraction * 100).toInt()}% in"
        }

    companion object {
        fun new(title: String, text: String, now: Long = System.currentTimeMillis()): Story =
            Story(
                title = title,
                text = text,
                createdAt = now,
                lastOpenedAt = now,
                sentenceCount = TextStats.sentences(text).size,
                moodRaw = Mood.MYSTERY.name,
            )
    }
}
