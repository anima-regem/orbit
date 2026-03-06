package com.example.orbit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OrbitBridgeContractsTest {
    @Test
    fun `build notification payload includes required v2 fields`() {
        val payload = OrbitBridgeContracts.buildNotificationEventPayload(
            sourcePackage = "com.instagram.android",
            sourceName = "Instagram",
            title = "DM",
            body = "New message",
            displayMs = 4500,
        )

        assertEquals(2, payload["schemaVersion"])
        assertEquals("notification", payload["kind"])
        assertEquals("com.instagram.android", payload["sourcePackage"])
        assertEquals("DM", payload["title"])
        assertEquals("high", payload["priority"])
        assertTrue(payload.containsKey("eventId"))
        assertTrue(payload.containsKey("timestampMs"))
    }

    @Test
    fun `parse overlay config v2 maps behavior and filters`() {
        val raw = mapOf(
            "schemaVersion" to 2,
            "layout" to mapOf(
                "horizontalOffsetPx" to 14,
                "verticalOffsetPx" to -5,
                "zAxisPx" to 22,
                "anchorMode" to "top_safe_lane",
                "lanePreset" to "relaxed",
                "compactWidthFactor" to 0.5,
                "compactHeightDp" to 60,
            ),
            "behavior" to mapOf(
                "musicPersistent" to false,
                "reducedMotion" to true,
                "profileId" to "focus",
            ),
            "theme" to mapOf("dynamicThemeEnabled" to false),
            "filters" to mapOf(
                "allowedPackages" to listOf("com.whatsapp", "com.google.android.gm"),
            ),
        )

        val config = OrbitBridgeContracts.parseOverlayConfigV2(raw)

        assertEquals(14, config.dimensions.horizontalOffsetPx)
        assertEquals(-5, config.dimensions.verticalOffsetPx)
        assertEquals(22, config.dimensions.zAxisPx)
        assertEquals("top_safe_lane", config.dimensions.anchorMode)
        assertEquals("relaxed", config.dimensions.lanePreset)
        assertEquals(0.5f, config.dimensions.compactWidthFactor)
        assertEquals(60, config.dimensions.compactHeightDp)
        assertFalse(config.behavior.musicPersistent)
        assertTrue(config.behavior.reducedMotion)
        assertFalse(config.behavior.dynamicThemeEnabled)
        assertEquals("focus", config.behavior.profileId)
        assertEquals(setOf("com.whatsapp", "com.google.android.gm"), config.allowedPackages)
    }

    @Test
    fun `parse debug trigger request v2 with custom notification fields`() {
        val request = OrbitBridgeContracts.parseDebugTriggerRequestV2(
            mapOf(
                "schemaVersion" to 2,
                "action" to "notification",
                "sourcePackage" to "com.whatsapp",
                "sourceName" to "WhatsApp",
                "title" to "Ping",
                "body" to "Hello",
            ),
        )

        requireNotNull(request)
        assertEquals(OrbitDebugAction.NOTIFICATION, request.action)
        assertEquals("com.whatsapp", request.sourcePackage)
        assertEquals("WhatsApp", request.sourceName)
        assertEquals("Ping", request.title)
        assertEquals("Hello", request.body)
    }

    @Test
    fun `reject debug trigger request when schema is invalid`() {
        val request = OrbitBridgeContracts.parseDebugTriggerRequestV2(
            mapOf(
                "schemaVersion" to 1,
                "action" to "music_start",
            ),
        )

        assertNull(request)
    }

    @Test
    fun `reject debug trigger request when action is unknown`() {
        val request = OrbitBridgeContracts.parseDebugTriggerRequestV2(
            mapOf(
                "schemaVersion" to 2,
                "action" to "invalid_action",
            ),
        )

        assertNull(request)
    }

    @Test
    fun `overlay config parser falls back when optional lane fields missing`() {
        val config = OrbitBridgeContracts.parseOverlayConfigV2(
            mapOf(
                "schemaVersion" to 2,
                "layout" to mapOf("compactHeightDp" to 52),
                "behavior" to mapOf("musicPersistent" to true),
            ),
        )

        assertEquals("top_safe_lane", config.dimensions.anchorMode)
        assertEquals("balanced", config.dimensions.lanePreset)
        assertEquals("commute", config.behavior.profileId)
    }
}
