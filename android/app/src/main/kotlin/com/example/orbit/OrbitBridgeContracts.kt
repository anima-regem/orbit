package com.example.orbit

import java.util.UUID

private const val DEFAULT_DISPLAY_MS = 4000

data class OrbitOverlayBehavior(
    val musicPersistent: Boolean = true,
    val reducedMotion: Boolean = false,
    val dynamicThemeEnabled: Boolean = true,
)

data class OrbitOverlayConfigV2(
    val dimensions: OrbitOverlayDimensions = OrbitOverlayDimensions(),
    val behavior: OrbitOverlayBehavior = OrbitOverlayBehavior(),
    val allowedPackages: Set<String> = setOf("com.instagram.android", "com.whatsapp"),
)

enum class OrbitDebugAction(val wireValue: String) {
    MUSIC_START("music_start"),
    TRACK_CHANGE("track_change"),
    NOTIFICATION("notification"),
    BURST("burst"),
    MUSIC_PAUSE("music_pause"),
    MUSIC_AND_NOTIFICATION("music_and_notification");

    companion object {
        fun fromWire(value: String?): OrbitDebugAction? {
            return values().firstOrNull { it.wireValue == value }
        }
    }
}

data class OrbitDebugTriggerRequestV2(
    val action: OrbitDebugAction,
    val sourcePackage: String?,
    val sourceName: String?,
    val title: String?,
    val body: String?,
)

object OrbitBridgeContracts {
    const val SCHEMA_VERSION = 2

    fun buildMusicEventPayload(
        sourcePackage: String,
        sourceName: String?,
        title: String,
        subtitle: String?,
        body: String?,
        trackChange: Boolean,
        displayMs: Int,
        albumArtBase64: String?,
    ): Map<String, Any?> {
        return mapOf(
            "schemaVersion" to SCHEMA_VERSION,
            "eventId" to UUID.randomUUID().toString(),
            "kind" to "music",
            "sourcePackage" to sourcePackage,
            "sourceName" to sourceName,
            "title" to title,
            "subtitle" to subtitle,
            "body" to body,
            "trackChange" to trackChange,
            "albumArtBase64" to albumArtBase64,
            "displayMs" to displayMs.coerceIn(2000, 6000),
            "priority" to "normal",
            "timestampMs" to System.currentTimeMillis(),
        )
    }

    fun buildNotificationEventPayload(
        sourcePackage: String,
        sourceName: String?,
        title: String,
        body: String?,
        displayMs: Int,
    ): Map<String, Any?> {
        return mapOf(
            "schemaVersion" to SCHEMA_VERSION,
            "eventId" to UUID.randomUUID().toString(),
            "kind" to "notification",
            "sourcePackage" to sourcePackage,
            "sourceName" to sourceName,
            "title" to title,
            "body" to body,
            "displayMs" to displayMs.coerceIn(2000, 6000),
            "priority" to "high",
            "timestampMs" to System.currentTimeMillis(),
        )
    }

    fun buildMusicPausedPayload(): Map<String, Any?> {
        return mapOf(
            "schemaVersion" to SCHEMA_VERSION,
            "eventId" to UUID.randomUUID().toString(),
            "kind" to "musicPaused",
            "priority" to "normal",
            "timestampMs" to System.currentTimeMillis(),
        )
    }

    fun parseOverlayConfigV2(rawArguments: Any?): OrbitOverlayConfigV2 {
        val args = rawArguments as? Map<*, *> ?: return OrbitOverlayConfigV2()
        val schemaVersion = number(args["schemaVersion"], SCHEMA_VERSION.toFloat()).toInt()
        if (schemaVersion != SCHEMA_VERSION) {
            return OrbitOverlayConfigV2()
        }

        val layout = args["layout"] as? Map<*, *> ?: emptyMap<String, Any?>()
        val behaviorMap = args["behavior"] as? Map<*, *> ?: emptyMap<String, Any?>()
        val theme = args["theme"] as? Map<*, *> ?: emptyMap<String, Any?>()
        val filters = args["filters"] as? Map<*, *> ?: emptyMap<String, Any?>()

        val compactWidthFactor = number(layout["compactWidthFactor"], 0.42f).coerceIn(0.35f, 0.85f)
        val expandedWidthFactor = number(layout["expandedWidthFactor"], 0.74f).coerceIn(0.55f, 0.92f)
        val compactHeightDp = number(layout["compactHeightDp"], 52f).toInt().coerceIn(44, 96)
        val musicExpandedHeightDp =
            number(layout["musicExpandedHeightDp"], 196f).toInt().coerceIn(140, 320)
        val notificationExpandedHeightDp =
            number(layout["notificationExpandedHeightDp"], 140f).toInt().coerceIn(110, 260)

        val dimensions = OrbitOverlayDimensions(
            horizontalOffsetPx = number(layout["horizontalOffsetPx"], 0f).toInt(),
            verticalOffsetPx = number(layout["verticalOffsetPx"], 0f).toInt(),
            zAxisPx = number(layout["zAxisPx"], 0f).toInt().coerceIn(0, 160),
            compactWidthFactor = compactWidthFactor,
            compactHeightDp = compactHeightDp,
            expandedWidthFactor = expandedWidthFactor,
            musicExpandedHeightDp = musicExpandedHeightDp,
            notificationExpandedHeightDp = notificationExpandedHeightDp,
        )

        val behavior = OrbitOverlayBehavior(
            musicPersistent = behaviorMap["musicPersistent"] != false,
            reducedMotion = behaviorMap["reducedMotion"] == true,
            dynamicThemeEnabled = theme["dynamicThemeEnabled"] != false,
        )

        val allowedPackages = (filters["allowedPackages"] as? List<*>)
            ?.mapNotNull { it?.toString()?.trim()?.lowercase() }
            ?.filter { it.isNotBlank() }
            ?.toSet()
            ?.ifEmpty { setOf("com.instagram.android", "com.whatsapp") }
            ?: setOf("com.instagram.android", "com.whatsapp")

        return OrbitOverlayConfigV2(
            dimensions = dimensions,
            behavior = behavior,
            allowedPackages = allowedPackages,
        )
    }

    fun parseDebugTriggerRequestV2(rawArguments: Any?): OrbitDebugTriggerRequestV2? {
        val args = rawArguments as? Map<*, *> ?: return null
        val schemaVersion = number(args["schemaVersion"], (-1).toFloat()).toInt()
        if (schemaVersion != SCHEMA_VERSION) {
            return null
        }

        val action = OrbitDebugAction.fromWire(args["action"]?.toString()) ?: return null
        return OrbitDebugTriggerRequestV2(
            action = action,
            sourcePackage = text(args["sourcePackage"]),
            sourceName = text(args["sourceName"]),
            title = text(args["title"]),
            body = text(args["body"]),
        )
    }

    private fun number(raw: Any?, fallback: Float): Float {
        return when (raw) {
            is Number -> raw.toFloat()
            is String -> raw.toFloatOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun text(raw: Any?): String? {
        val value = raw?.toString()?.trim().orEmpty()
        if (value.isBlank()) {
            return null
        }
        return value
    }

    fun normalizeDisplayMs(rawDisplayMs: Int?): Int {
        return (rawDisplayMs ?: DEFAULT_DISPLAY_MS).coerceIn(2000, 6000)
    }
}
