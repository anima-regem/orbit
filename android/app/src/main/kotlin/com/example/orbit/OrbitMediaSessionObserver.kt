package com.example.orbit

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.util.Base64
import android.util.Log
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.roundToInt

class OrbitMediaSessionObserver(
    private val context: Context,
    private val onMusicEvent: ((OverlayMusicEvent) -> Unit)? = null,
    private val onMusicPause: (() -> Unit)? = null,
) {
    companion object {
        private const val TAG = "OrbitMediaObserver"
        private const val MAX_ART_SIZE_PX = 180
        private const val ART_QUALITY = 72
    }

    private val mediaSessionManager =
        context.getSystemService(MediaSessionManager::class.java)

    private val listenerComponent =
        ComponentName(context, OrbitNotificationListenerService::class.java)

    private val bindings = mutableMapOf<String, ControllerBinding>()

    private val activeSessionsListener =
        MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
            bindControllers(controllers.orEmpty())
        }

    fun start(): Boolean {
        return runCatching {
            mediaSessionManager?.addOnActiveSessionsChangedListener(
                activeSessionsListener,
                listenerComponent,
            )
            refreshActiveSessions()
            true
        }.getOrElse { error ->
            Log.w(TAG, "Media session observer not started", error)
            false
        }
    }

    fun stop() {
        runCatching {
            mediaSessionManager?.removeOnActiveSessionsChangedListener(activeSessionsListener)
        }
        val oldBindings = bindings.values.toList()
        bindings.clear()
        oldBindings.forEach { binding ->
            runCatching {
                binding.controller.unregisterCallback(binding.callback)
            }
        }
    }

    private fun refreshActiveSessions() {
        val controllers = try {
            mediaSessionManager?.getActiveSessions(listenerComponent).orEmpty()
        } catch (_: SecurityException) {
            emptyList()
        }
        bindControllers(controllers)
    }

    private fun bindControllers(controllers: List<MediaController>) {
        val currentIds = controllers.map { it.sessionToken.toString() }.toSet()

        val staleIds = bindings.keys.filterNot { it in currentIds }
        staleIds.forEach { id ->
            val binding = bindings.remove(id)
            binding?.controller?.unregisterCallback(binding.callback)
        }

        controllers.forEach { controller ->
            val id = controller.sessionToken.toString()
            if (bindings.containsKey(id)) {
                return@forEach
            }

            val callback = object : MediaController.Callback() {
                override fun onPlaybackStateChanged(state: PlaybackState?) {
                    handlePlaybackState(id, state)
                }

                override fun onMetadataChanged(metadata: MediaMetadata?) {
                    handleMetadataChanged(id)
                }
            }

            val binding = ControllerBinding(controller = controller, callback = callback)
            bindings[id] = binding
            controller.registerCallback(callback)

            handlePlaybackState(id, controller.playbackState)
        }
    }

    private fun handlePlaybackState(id: String, state: PlaybackState?) {
        val binding = bindings[id] ?: return
        val previousState = binding.lastPlaybackState
        val currentState = state?.state ?: PlaybackState.STATE_NONE

        val wasPlaying = previousState == PlaybackState.STATE_PLAYING
        val isPlaying = currentState == PlaybackState.STATE_PLAYING

        if (isPlaying && !wasPlaying) {
            emitMusicEvent(binding = binding, trackChange = false)
        }

        if (!isPlaying && wasPlaying) {
            OrbitEventBridge.sendMusicPaused()
            onMusicPause?.invoke()
        }

        binding.lastPlaybackState = currentState
    }

    private fun handleMetadataChanged(id: String) {
        val binding = bindings[id] ?: return
        if (binding.lastPlaybackState == PlaybackState.STATE_PLAYING) {
            emitMusicEvent(binding = binding, trackChange = true)
        }
    }

    private fun emitMusicEvent(binding: ControllerBinding, trackChange: Boolean) {
        val metadata = binding.controller.metadata
        val sourcePackage = binding.controller.packageName?.takeIf { it.isNotBlank() } ?: "music"
        val sourceName = appLabelForPackage(sourcePackage)
        val title =
            extractTitle(metadata)
                ?: fallbackTitle(sourcePackage)
        val artist = extractArtist(metadata)
        val album = extractAlbum(metadata)

        val freshAlbumArt = extractAlbumArtBase64(metadata)
        if (!freshAlbumArt.isNullOrBlank()) {
            binding.lastAlbumArtBase64 = freshAlbumArt
        }
        val albumArtBase64 = freshAlbumArt ?: binding.lastAlbumArtBase64
        val artSignature = albumArtBase64?.let { "${it.length}:${it.take(18)}" }

        val sameTrackData =
            title == binding.lastSentTitle &&
                artist == binding.lastSentArtist &&
                album == binding.lastSentAlbum &&
                artSignature == binding.lastSentArtSignature
        if (trackChange && sameTrackData) {
            return
        }

        OrbitEventBridge.sendMusicEvent(
            sourcePackage = sourcePackage,
            sourceName = sourceName,
            title = title,
            subtitle = artist,
            body = if (trackChange) "Track changed" else "Now playing",
            trackChange = trackChange,
            displayMs = 4000,
            albumArtBase64 = albumArtBase64,
        )

        onMusicEvent?.invoke(
            OverlayMusicEvent(
                sourcePackage = sourcePackage,
                sourceName = sourceName,
                title = title,
                artist = artist,
                album = album,
                albumArtBase64 = albumArtBase64,
                trackChange = trackChange,
                visibleMs = 4000,
            ),
        )

        binding.lastSentTitle = title
        binding.lastSentArtist = artist
        binding.lastSentAlbum = album
        binding.lastSentArtSignature = artSignature
    }

    private fun extractTitle(metadata: MediaMetadata?): String? {
        val explicitTitle = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)?.trim()
        if (!explicitTitle.isNullOrBlank()) {
            return explicitTitle.take(80)
        }

        val displayTitle = metadata?.description?.title?.toString()?.trim()
        if (!displayTitle.isNullOrBlank()) {
            return displayTitle.take(80)
        }

        return null
    }

    private fun fallbackTitle(packageName: String): String {
        if (packageName.isBlank()) {
            return "Now playing"
        }
        return runCatching {
            val info = context.packageManager.getApplicationInfo(packageName, 0)
            context.packageManager.getApplicationLabel(info).toString()
        }.getOrDefault("Now playing")
    }

    private fun appLabelForPackage(packageName: String): String {
        if (packageName.isBlank() || packageName == "music") {
            return "Music"
        }
        return runCatching {
            val info = context.packageManager.getApplicationInfo(packageName, 0)
            context.packageManager.getApplicationLabel(info).toString()
        }.getOrDefault("Music")
    }

    private fun extractAlbumArtBase64(metadata: MediaMetadata?): String? {
        val bitmap =
            metadata?.description?.iconBitmap
                ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
                ?: return null

        return compressBitmapToBase64(bitmap)
    }

    private fun extractArtist(metadata: MediaMetadata?): String? {
        val explicitArtist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)?.trim()
        if (!explicitArtist.isNullOrBlank()) {
            return explicitArtist.take(80)
        }

        val displaySubtitle = metadata?.description?.subtitle?.toString()?.trim()
        if (!displaySubtitle.isNullOrBlank()) {
            return displaySubtitle.take(80)
        }

        return null
    }

    private fun extractAlbum(metadata: MediaMetadata?): String? {
        val explicitAlbum = metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM)?.trim()
        if (!explicitAlbum.isNullOrBlank()) {
            return explicitAlbum.take(80)
        }

        val displayDescription = metadata?.description?.description?.toString()?.trim()
        if (!displayDescription.isNullOrBlank()) {
            return displayDescription.take(80)
        }

        return null
    }

    private fun compressBitmapToBase64(bitmap: Bitmap): String? {
        return runCatching {
            val prepared = prepareBitmap(bitmap)
            val stream = ByteArrayOutputStream()
            try {
                prepared.compress(Bitmap.CompressFormat.WEBP_LOSSY, ART_QUALITY, stream)
                Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
            } finally {
                if (prepared != bitmap) {
                    prepared.recycle()
                }
            }
        }.getOrNull()
    }

    private fun prepareBitmap(bitmap: Bitmap): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val maxSide = max(width, height)
        if (maxSide <= MAX_ART_SIZE_PX) {
            return bitmap
        }

        val scale = MAX_ART_SIZE_PX.toFloat() / maxSide.toFloat()
        val targetWidth = (width * scale).roundToInt().coerceAtLeast(1)
        val targetHeight = (height * scale).roundToInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true)
    }

    private data class ControllerBinding(
        val controller: MediaController,
        val callback: MediaController.Callback,
        var lastPlaybackState: Int = PlaybackState.STATE_NONE,
        var lastSentTitle: String? = null,
        var lastSentArtist: String? = null,
        var lastSentAlbum: String? = null,
        var lastSentArtSignature: String? = null,
        var lastAlbumArtBase64: String? = null,
    )

    data class OverlayMusicEvent(
        val sourcePackage: String,
        val sourceName: String,
        val title: String,
        val artist: String?,
        val album: String?,
        val albumArtBase64: String?,
        val trackChange: Boolean,
        val visibleMs: Int,
    )
}
