package com.bikash.storywick.audio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import com.bikash.storywick.MainActivity
import com.bikash.storywick.R
import com.bikash.storywick.StorywickApplication
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Foreground service that owns the MediaSession — the Android equivalent of
 * NowPlaying.swift + the "audio" UIBackgroundMode on iOS. Narrator starts this
 * the moment playback begins and it stays alive (with the required lock-screen
 * notification) for as long as narration is active, independent of whether any
 * screen is visible.
 */
class PlaybackService : Service() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private lateinit var session: MediaSessionCompat
    private lateinit var narrator: Narrator

    override fun onCreate() {
        super.onCreate()
        narrator = (application as StorywickApplication).narrator
        ensureChannel()

        session = MediaSessionCompat(this, "Storywick").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() = narrator.resume()
                override fun onPause() = narrator.pause()
                override fun onSkipToNext() = narrator.skip(1)
                override fun onSkipToPrevious() = narrator.skip(-1)
                override fun onStop() = narrator.stop()
            })
            isActive = true
        }

        scope.launch { narrator.isSpeaking.collect { refresh() } }
        scope.launch { narrator.isPaused.collect { refresh() } }
        scope.launch { narrator.currentIndex.collect { refresh() } }
        scope.launch { narrator.nowPlayingTitle.collect { refresh() } }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY_PAUSE -> narrator.togglePlayPause()
            ACTION_NEXT -> narrator.skip(1)
            ACTION_PREVIOUS -> narrator.skip(-1)
        }
        refresh()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        session.release()
        super.onDestroy()
    }

    private fun refresh() {
        val playing = narrator.isSpeaking.value && !narrator.isPaused.value
        val active = narrator.isActive

        session.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, narrator.currentSentenceText ?: "Ready")
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, narrator.nowPlayingTitle.value)
                .build()
        )
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
                )
                .setState(
                    if (playing) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED,
                    PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN,
                    1f,
                )
                .build()
        )

        if (!active) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }

        val notification = buildNotification(playing)
        startForeground(NOTIF_ID, notification)
    }

    private fun buildNotification(playing: Boolean): Notification {
        val contentIntent = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val playPauseIcon = if (playing) R.drawable.ic_pause else R.drawable.ic_play
        val playPauseAction = NotificationCompat.Action(
            playPauseIcon, if (playing) "Pause" else "Play", actionIntent(ACTION_PLAY_PAUSE),
        )
        val prevAction = NotificationCompat.Action(R.drawable.ic_previous, "Previous", actionIntent(ACTION_PREVIOUS))
        val nextAction = NotificationCompat.Action(R.drawable.ic_next, "Next", actionIntent(ACTION_NEXT))

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(narrator.currentSentenceText ?: "Ready")
            .setContentText(narrator.nowPlayingTitle.value)
            .setContentIntent(contentIntent)
            .addAction(prevAction)
            .addAction(playPauseAction)
            .addAction(nextAction)
            .setStyle(
                MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2),
            )
            .setOngoing(playing)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun actionIntent(action: String): PendingIntent {
        val intent = Intent(this, PlaybackService::class.java).setAction(action)
        return PendingIntent.getService(
            this, action.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Narration", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    companion object {
        private const val CHANNEL_ID = "storywick.narration"
        private const val NOTIF_ID = 1
        private const val ACTION_PLAY_PAUSE = "com.bikash.storywick.PLAY_PAUSE"
        private const val ACTION_NEXT = "com.bikash.storywick.NEXT"
        private const val ACTION_PREVIOUS = "com.bikash.storywick.PREVIOUS"
    }
}
