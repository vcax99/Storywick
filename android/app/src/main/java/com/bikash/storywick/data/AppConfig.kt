package com.bikash.storywick.data

object AppConfig {
    /** Maximum words in a single pasted chapter. */
    const val WORD_LIMIT = 5_000

    /** How many past chapters to keep; the oldest drops off past this. */
    const val HISTORY_LIMIT = 10
}
