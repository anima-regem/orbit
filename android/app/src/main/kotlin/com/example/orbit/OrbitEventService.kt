package com.example.orbit

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

class OrbitEventService : Service() {
    companion object {
        private const val TAG = "OrbitEventService"
        private const val CHANNEL_ID = "orbit_listener_channel"
        private const val NOTIFICATION_ID = 4107
        private const val RESTART_REQUEST_CODE = 9107
        private const val MAX_PENDING_NOTIFICATIONS = 3
        private const val MAX_PENDING_DEBUG_REQUESTS = 8

        private val lock = Any()

        @Volatile
        private var runningInstance: OrbitEventService? = null

        @Volatile
        private var appInForeground: Boolean = false

        @Volatile
        private var overlayDimensions: OrbitOverlayDimensions = OrbitOverlayDimensions()

        @Volatile
        private var overlayBehavior: OrbitOverlayBehavior = OrbitOverlayBehavior()

        private val pendingNotificationEvents = ArrayDeque<PendingNotificationEvent>()
        private val pendingDebugRequests = ArrayDeque<OrbitDebugTriggerRequestV2>()

        fun start(context: Context) {
            val intent = Intent(context, OrbitEventService::class.java)
            runCatching {
                ContextCompat.startForegroundService(context, intent)
            }.onFailure { firstError ->
                Log.w(TAG, "Foreground service start failed, attempting normal start", firstError)
                runCatching {
                    context.startService(intent)
                }.onFailure { secondError ->
                    Log.e(TAG, "Unable to start OrbitEventService", secondError)
                }
            }
        }

        fun postNotificationEvent(
            context: Context,
            packageName: String,
            appName: String?,
            title: String,
            preview: String?,
            visibleMs: Int = 4000,
        ) {
            if (!OrbitNotificationConfig.isAllowed(packageName)) {
                return
            }

            val event = PendingNotificationEvent(
                packageName = packageName,
                appName = appName,
                title = title,
                preview = preview,
                visibleMs = visibleMs,
            )

            start(context)

            val liveInstance = runningInstance
            if (liveInstance != null) {
                liveInstance.handlePendingNotificationEvent(event)
                return
            }

            synchronized(lock) {
                pendingNotificationEvents.addLast(event)
                while (pendingNotificationEvents.size > MAX_PENDING_NOTIFICATIONS) {
                    pendingNotificationEvents.removeFirst()
                }
            }
        }

        fun setAppInForeground(value: Boolean) {
            appInForeground = value
            runningInstance?.onAppForegroundChanged(value)
        }

        fun setOverlayDimensions(dimensions: OrbitOverlayDimensions) {
            overlayDimensions = dimensions
            runningInstance?.applyOverlayDimensions(dimensions)
        }

        fun setOverlayBehavior(behavior: OrbitOverlayBehavior) {
            overlayBehavior = behavior
            runningInstance?.applyOverlayBehavior(behavior)
        }

        fun triggerDebugOverlayEvent(
            context: Context,
            request: OrbitDebugTriggerRequestV2,
        ): Boolean {
            start(context)

            val liveInstance = runningInstance
            if (liveInstance != null) {
                liveInstance.handleDebugTriggerRequest(request)
                return true
            }

            synchronized(lock) {
                pendingDebugRequests.addLast(request)
                while (pendingDebugRequests.size > MAX_PENDING_DEBUG_REQUESTS) {
                    pendingDebugRequests.removeFirst()
                }
            }
            return true
        }
    }

    private var mediaObserver: OrbitMediaSessionObserver? = null
    private var mediaObserverStarted = false
    private var nativeOverlayManager: OrbitNativeOverlayManager? = null
    private var latestMusicEvent: OrbitMediaSessionObserver.OverlayMusicEvent? = null
    private var isMusicPlaying: Boolean = false
    private var debugTrackIndex: Int = 0
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        runningInstance = this
        createNotificationChannel()
        if (!startAsForegroundServiceSafely()) {
            stopSelf()
            return
        }

        mediaObserver = OrbitMediaSessionObserver(
            context = this,
            onMusicEvent = { musicEvent ->
                handleMusicOverlayEvent(musicEvent)
            },
            onMusicPause = {
                handleMusicPaused()
            },
        )

        tryStartMediaObserver()
        drainPendingNotificationEvents()
        drainPendingDebugRequests()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForegroundServiceSafely()
        tryStartMediaObserver()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        scheduleSelfRestart()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        mediaObserver?.stop()
        mediaObserver = null
        mediaObserverStarted = false
        nativeOverlayManager?.destroy()
        nativeOverlayManager = null
        latestMusicEvent = null
        isMusicPlaying = false
        if (runningInstance === this) {
            runningInstance = null
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startAsForegroundService() {
        val notification = buildServiceNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
            return
        }

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun startAsForegroundServiceSafely(): Boolean {
        return runCatching {
            startAsForegroundService()
            true
        }.getOrElse { firstError ->
            Log.e(TAG, "startForeground with type failed, trying ServiceCompat", firstError)
            // Defensive fallback for strict platform variants.
            runCatching {
                ServiceCompat.startForeground(
                    this,
                    NOTIFICATION_ID,
                    buildServiceNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
                true
            }.getOrElse { fallbackError ->
                Log.e(TAG, "ServiceCompat foreground start also failed", fallbackError)
                false
            }
        }
    }

    private fun tryStartMediaObserver() {
        if (mediaObserverStarted) {
            return
        }

        val started = mediaObserver?.start() == true
        mediaObserverStarted = started
        if (!started) {
            // Notification listener access is missing or restricted;
            // keep service alive and retry on next service start signal.
            Log.w(TAG, "Media observer is inactive until notification access is granted")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Orbit background listener",
            NotificationManager.IMPORTANCE_MIN,
        )
        channel.description = "Listens for music and notification events"
        manager.createNotificationChannel(channel)
    }

    private fun scheduleSelfRestart() {
        val restartIntent = Intent(applicationContext, OrbitEventService::class.java)
        val pendingIntent = PendingIntent.getService(
            applicationContext,
            RESTART_REQUEST_CODE,
            restartIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE,
        )

        val alarmManager = getSystemService(AlarmManager::class.java) ?: return
        val triggerAt = SystemClock.elapsedRealtime() + 1500L
        runCatching {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAt,
                pendingIntent,
            )
        }.onFailure { error ->
            Log.w(TAG, "Unable to schedule Orbit service restart", error)
        }
    }

    private fun buildServiceNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val contentIntent = PendingIntent.getActivity(
            this,
            100,
            launchIntent,
            flags,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setContentTitle("Orbit listeners active")
            .setContentText("Monitoring music and selected notifications")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .build()
    }

    private fun drainPendingNotificationEvents() {
        val pending = mutableListOf<PendingNotificationEvent>()
        synchronized(lock) {
            while (pendingNotificationEvents.isNotEmpty()) {
                pending.add(pendingNotificationEvents.removeFirst())
            }
        }

        pending.forEach(::handlePendingNotificationEvent)
    }

    private fun drainPendingDebugRequests() {
        val pending = mutableListOf<OrbitDebugTriggerRequestV2>()
        synchronized(lock) {
            while (pendingDebugRequests.isNotEmpty()) {
                pending.add(pendingDebugRequests.removeFirst())
            }
        }

        pending.forEach(::handleDebugTriggerRequest)
    }

    private fun handlePendingNotificationEvent(event: PendingNotificationEvent) {
        ensureNativeOverlayManager().showNotification(
            packageName = event.packageName,
            appName = event.appName,
            title = event.title,
            preview = event.preview,
            visibleMs = event.visibleMs,
        )
    }

    private fun handleMusicOverlayEvent(event: OrbitMediaSessionObserver.OverlayMusicEvent) {
        isMusicPlaying = true
        latestMusicEvent = event
        ensureNativeOverlayManager().showMusic(
            appId = event.sourcePackage,
            title = event.title,
            artist = event.artist,
            album = event.album,
            albumArtBase64 = event.albumArtBase64,
            visibleMs = event.visibleMs,
        )
    }

    private fun handleMusicPaused() {
        isMusicPlaying = false
        latestMusicEvent = null
        nativeOverlayManager?.onMusicPause()
    }

    private fun handleDebugTriggerRequest(request: OrbitDebugTriggerRequestV2) {
        when (request.action) {
            OrbitDebugAction.MUSIC_START -> {
                emitDebugMusicEvent(trackChange = false)
            }

            OrbitDebugAction.TRACK_CHANGE -> {
                emitDebugMusicEvent(trackChange = true)
            }

            OrbitDebugAction.NOTIFICATION -> {
                emitDebugNotification(
                    sourcePackage = request.sourcePackage,
                    sourceName = request.sourceName,
                    title = request.title,
                    body = request.body,
                )
            }

            OrbitDebugAction.BURST -> {
                emitDebugBurst()
            }

            OrbitDebugAction.MUSIC_PAUSE -> {
                OrbitEventBridge.sendMusicPaused()
                handleMusicPaused()
            }

            OrbitDebugAction.MUSIC_AND_NOTIFICATION -> {
                emitDebugMusicEvent(trackChange = false)
                mainHandler.postDelayed(
                    {
                        emitDebugNotification(
                            sourcePackage = request.sourcePackage,
                            sourceName = request.sourceName,
                            title = request.title,
                            body = request.body,
                        )
                    },
                    120L,
                )
            }
        }
    }

    private fun emitDebugMusicEvent(trackChange: Boolean) {
        val track = debugTrackTitle(trackChange)
        val sourcePackage = "com.spotify.music"
        val sourceName = "Spotify"
        val subtitle = "Orbit Session"
        val body = if (trackChange) "Track changed" else "Now playing"

        OrbitEventBridge.sendMusicEvent(
            sourcePackage = sourcePackage,
            sourceName = sourceName,
            title = track,
            subtitle = subtitle,
            body = body,
            trackChange = trackChange,
            displayMs = 4000,
            albumArtBase64 = null,
        )

        handleMusicOverlayEvent(
            OrbitMediaSessionObserver.OverlayMusicEvent(
                sourcePackage = sourcePackage,
                sourceName = sourceName,
                title = track,
                artist = subtitle,
                album = "Debug Session",
                albumArtBase64 = null,
                trackChange = trackChange,
                visibleMs = 4000,
            ),
        )
    }

    private fun emitDebugNotification(
        sourcePackage: String?,
        sourceName: String?,
        title: String?,
        body: String?,
    ) {
        val resolvedPackage = sourcePackage?.trim()?.lowercase().takeUnless { it.isNullOrBlank() }
            ?: "com.instagram.android"
        val resolvedSourceName = sourceName?.trim().takeUnless { it.isNullOrBlank() }
            ?: appLabelForPackageOrFallback(resolvedPackage)
        val resolvedTitle = title?.trim().takeUnless { it.isNullOrBlank() }
            ?: "Instagram DM"
        val resolvedBody = body?.trim().takeUnless { it.isNullOrBlank() }
            ?: "New message from Alex"
        if (!OrbitNotificationConfig.isAllowed(resolvedPackage)) {
            return
        }

        OrbitEventBridge.sendNotificationEvent(
            sourcePackage = resolvedPackage,
            sourceName = resolvedSourceName,
            title = resolvedTitle,
            body = resolvedBody,
            displayMs = 4000,
        )

        postNotificationEvent(
            context = this,
            packageName = resolvedPackage,
            appName = resolvedSourceName,
            title = resolvedTitle,
            preview = resolvedBody,
            visibleMs = 4000,
        )
    }

    private fun emitDebugBurst() {
        val events = listOf(
            PendingNotificationEvent(
                packageName = "com.instagram.android",
                appName = "Instagram",
                title = "Instagram DM",
                preview = "New message from Alex",
                visibleMs = 4000,
            ),
            PendingNotificationEvent(
                packageName = "com.whatsapp",
                appName = "WhatsApp",
                title = "WhatsApp",
                preview = "2 new messages",
                visibleMs = 4000,
            ),
            PendingNotificationEvent(
                packageName = "com.google.android.gm",
                appName = "Gmail",
                title = "Inbox",
                preview = "Build is green",
                visibleMs = 4000,
            ),
            PendingNotificationEvent(
                packageName = "com.slack.android",
                appName = "Slack",
                title = "Slack Mention",
                preview = "Can you check staging?",
                visibleMs = 4000,
            ),
            PendingNotificationEvent(
                packageName = "com.instagram.android",
                appName = "Instagram",
                title = "Instagram Story Reply",
                preview = "Nice shot!",
                visibleMs = 4000,
            ),
        )

        events.forEachIndexed { index, event ->
            mainHandler.postDelayed(
                {
                    emitDebugNotification(
                        sourcePackage = event.packageName,
                        sourceName = event.appName,
                        title = event.title,
                        body = event.preview,
                    )
                },
                index * 120L,
            )
        }
    }

    private fun debugTrackTitle(trackChange: Boolean): String {
        val tracks = listOf(
            "Midnight Atlas",
            "Velvet Circuit",
            "Neon Weekdays",
            "Gravity Garden",
            "Ocean in Static",
        )
        if (trackChange) {
            debugTrackIndex = (debugTrackIndex + 1) % tracks.size
        }
        return tracks[debugTrackIndex]
    }

    private fun appLabelForPackageOrFallback(targetPackage: String): String {
        return runCatching {
            val info = packageManager.getApplicationInfo(targetPackage, 0)
            packageManager.getApplicationLabel(info).toString()
        }.getOrElse {
            when (targetPackage) {
                "com.instagram.android" -> "Instagram"
                "com.whatsapp" -> "WhatsApp"
                "com.google.android.gm" -> "Gmail"
                "com.slack.android" -> "Slack"
                else -> "Notification"
            }
        }
    }

    private fun onAppForegroundChanged(@Suppress("UNUSED_PARAMETER") isForeground: Boolean) {
        // Foreground state is preserved for diagnostics but does not gate overlay rendering.
    }

    private fun ensureNativeOverlayManager(): OrbitNativeOverlayManager {
        val current = nativeOverlayManager
        if (current != null) {
            return current
        }

        val created = OrbitNativeOverlayManager(this)
        created.updateDimensions(overlayDimensions)
        created.updateBehavior(overlayBehavior)
        nativeOverlayManager = created
        return created
    }

    private fun applyOverlayDimensions(dimensions: OrbitOverlayDimensions) {
        nativeOverlayManager?.updateDimensions(dimensions)
    }

    private fun applyOverlayBehavior(behavior: OrbitOverlayBehavior) {
        nativeOverlayManager?.updateBehavior(behavior)
    }

    private data class PendingNotificationEvent(
        val packageName: String,
        val appName: String?,
        val title: String,
        val preview: String?,
        val visibleMs: Int,
    )
}
