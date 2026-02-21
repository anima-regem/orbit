package com.example.orbit

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object OrbitEventBridge {
    private const val CHANNEL_NAME = "orbit/events"
    private const val METHOD_EVENT_V2 = "orbitEventV2"

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        mainHandler.post {
            channel = MethodChannel(messenger, CHANNEL_NAME)
        }
    }

    fun detach() {
        mainHandler.post {
            channel = null
        }
    }

    fun sendMusicEvent(
        sourcePackage: String,
        sourceName: String?,
        title: String,
        subtitle: String? = null,
        body: String? = null,
        trackChange: Boolean = false,
        displayMs: Int = 4000,
        albumArtBase64: String? = null,
    ) {
        send(
            OrbitBridgeContracts.buildMusicEventPayload(
                sourcePackage = sourcePackage,
                sourceName = sourceName,
                title = title,
                subtitle = subtitle,
                body = body,
                trackChange = trackChange,
                displayMs = displayMs,
                albumArtBase64 = albumArtBase64,
            ),
        )
    }

    fun sendNotificationEvent(
        sourcePackage: String,
        sourceName: String?,
        title: String,
        body: String? = null,
        displayMs: Int = 4000,
    ) {
        send(
            OrbitBridgeContracts.buildNotificationEventPayload(
                sourcePackage = sourcePackage,
                sourceName = sourceName,
                title = title,
                body = body,
                displayMs = displayMs,
            ),
        )
    }

    fun sendMusicPaused() {
        send(OrbitBridgeContracts.buildMusicPausedPayload())
    }

    private fun send(payload: Map<String, Any?>) {
        mainHandler.post {
            channel?.invokeMethod(METHOD_EVENT_V2, payload)
        }
    }
}
