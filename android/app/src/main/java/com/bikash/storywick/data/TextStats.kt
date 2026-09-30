package com.bikash.storywick.data

import java.text.BreakIterator
import java.util.Locale

/** Locale-aware word count and sentence splitting — same approach as iOS's
 *  `enumerateSubstrings(.byWords/.bySentences)`, via java.text.BreakIterator. */
object TextStats {

    fun wordCount(text: String): Int {
        if (text.isEmpty()) return 0
        val it = BreakIterator.getWordInstance(Locale.getDefault())
        it.setText(text)
        var count = 0
        var start = it.first()
        var end = it.next()
        while (end != BreakIterator.DONE) {
            val word = text.substring(start, end)
            if (word.any { it.isLetterOrDigit() }) count++
            start = end
            end = it.next()
        }
        return count
    }

    fun sentences(text: String): List<String> {
        if (text.isEmpty()) return emptyList()
        val it = BreakIterator.getSentenceInstance(Locale.getDefault())
        it.setText(text)
        val result = mutableListOf<String>()
        var start = it.first()
        var end = it.next()
        while (end != BreakIterator.DONE) {
            val trimmed = text.substring(start, end).trim()
            if (trimmed.isNotEmpty()) result.add(trimmed)
            start = end
            end = it.next()
        }
        if (result.isEmpty() && text.isNotBlank()) result.add(text.trim())
        return result
    }
}
