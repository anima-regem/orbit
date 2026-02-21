package com.example.orbit

import android.app.Notification
import android.content.ComponentName
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class OrbitNotificationListenerService : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        OrbitEventService.start(this)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return

        if (sbn.packageName == packageName) {
            return
        }

        if (!OrbitNotificationConfig.isAllowed(sbn.packageName)) {
            return
        }

        val appName = appLabelForPackage(sbn.packageName)
        val extras = sbn.notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim()

        if (title.isNullOrBlank() && text.isNullOrBlank()) {
            return
        }

        val safeTitle = (title?.take(80) ?: appName).ifBlank {
            "New notification"
        }
        val safePreview = text?.take(120)

        OrbitEventBridge.sendNotificationEvent(
            sourcePackage = sbn.packageName,
            sourceName = appName,
            title = safeTitle,
            body = safePreview,
            displayMs = 4000,
        )

        OrbitEventService.postNotificationEvent(
            context = this,
            packageName = sbn.packageName,
            appName = appName,
            title = safeTitle,
            preview = safePreview,
            visibleMs = 4000,
        )
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        OrbitEventService.start(this)
        requestRebind(ComponentName(this, OrbitNotificationListenerService::class.java))
    }

    private fun appLabelForPackage(targetPackage: String): String {
        val manager = packageManager
        return runCatching {
            val info = manager.getApplicationInfo(targetPackage, 0)
            manager.getApplicationLabel(info).toString()
        }.getOrDefault("Notification")
    }
}
