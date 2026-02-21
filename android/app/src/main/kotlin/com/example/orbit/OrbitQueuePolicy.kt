package com.example.orbit

internal object OrbitQueuePolicy {
    fun <T> insert(
        queue: ArrayDeque<T>,
        activeCount: Int,
        event: T,
        isNotification: (T) -> Boolean,
        maxTotal: Int = 3,
    ) {
        while (queue.size + activeCount >= maxTotal && queue.isNotEmpty()) {
            queue.removeLast()
        }

        if (isNotification(event)) {
            queue.addFirst(event)
            return
        }

        queue.addLast(event)
    }
}
