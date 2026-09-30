package com.bikash.storywick

import android.app.Application
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.bikash.storywick.audio.Narrator

/** Owns the app-level Narrator for the whole process lifetime — the Kotlin
 *  equivalent of iOS StorywickApp holding `@State private var narrator` and
 *  handing it down via `.environment(narrator)`. Both Compose screens and
 *  PlaybackService read this same instance. */
class StorywickApplication : Application() {
    val narrator: Narrator by lazy { Narrator(this) }

    override fun onCreate() {
        super.onCreate()
        // Flush the reading position the moment the whole app (not just one
        // screen) leaves the foreground — same job scenePhase != .active did
        // on iOS, so a background kill resumes correctly instead of restarting.
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStop(owner: LifecycleOwner) {
                narrator.persistNow()
            }
        })
    }
}
