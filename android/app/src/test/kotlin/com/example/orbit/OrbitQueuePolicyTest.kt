package com.example.orbit

import org.junit.Assert.assertEquals
import org.junit.Test

class OrbitQueuePolicyTest {
    @Test
    fun `notification entries are prioritized and queue is capped at 3 total`() {
        val queue = ArrayDeque<TestEvent>()

        OrbitQueuePolicy.insert(
            queue = queue,
            activeCount = 1,
            event = TestEvent("music-2", isNotification = false),
            isNotification = { it.isNotification },
            maxTotal = 3,
        )
        OrbitQueuePolicy.insert(
            queue = queue,
            activeCount = 1,
            event = TestEvent("notif-1", isNotification = true),
            isNotification = { it.isNotification },
            maxTotal = 3,
        )
        OrbitQueuePolicy.insert(
            queue = queue,
            activeCount = 1,
            event = TestEvent("notif-2", isNotification = true),
            isNotification = { it.isNotification },
            maxTotal = 3,
        )

        assertEquals(2, queue.size)
        assertEquals("notif-2", queue.first().id)
        assertEquals("notif-1", queue.last().id)
    }

    private data class TestEvent(val id: String, val isNotification: Boolean)
}
