package com.example.orbit

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.os.UserManager
import android.provider.Settings
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private var permissionChannel: MethodChannel? = null
    private var pendingPostNotificationsResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        OrbitEventBridge.attach(flutterEngine.dartExecutor.binaryMessenger)
        configurePermissionChannel(flutterEngine)
        OrbitEventService.setAppInForeground(true)
        OrbitEventService.start(this)
    }

    override fun onResume() {
        super.onResume()
        OrbitEventService.setAppInForeground(true)
    }

    override fun onPause() {
        OrbitEventService.setAppInForeground(false)
        super.onPause()
    }

    override fun onDestroy() {
        permissionChannel?.setMethodCallHandler(null)
        permissionChannel = null
        pendingPostNotificationsResult = null

        if (isFinishing) {
            OrbitEventService.setAppInForeground(false)
        }

        super.onDestroy()
        if (isFinishing) {
            OrbitEventBridge.detach()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != REQUEST_POST_NOTIFICATIONS) {
            return
        }

        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingPostNotificationsResult?.success(granted)
        pendingPostNotificationsResult = null
    }

    private fun configurePermissionChannel(flutterEngine: FlutterEngine) {
        permissionChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PERMISSION_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_GET_PERMISSION_STATUS -> {
                        result.success(getPermissionStatus())
                    }

                    METHOD_REQUEST_POST_NOTIFICATIONS -> {
                        requestPostNotifications(result)
                    }

                    METHOD_OPEN_NOTIFICATION_ACCESS_SETTINGS -> {
                        result.success(openNotificationAccessSettings())
                    }

                    METHOD_OPEN_OVERLAY_SETTINGS -> {
                        result.success(openOverlaySettings())
                    }

                    METHOD_OPEN_APP_NOTIFICATION_SETTINGS -> {
                        val targetPackage = (call.arguments as? Map<*, *>)?.get("packageName")?.toString()
                        result.success(openAppNotificationSettings(targetPackage))
                    }

                    METHOD_GET_INSTALLED_APPS -> {
                        thread(name = "orbit-installed-apps") {
                            val outcome = runCatching { getInstalledApps() }
                            runOnUiThread {
                                outcome
                                    .onSuccess { apps -> result.success(apps) }
                                    .onFailure { error ->
                                        result.error(
                                            "installed_apps_failed",
                                            error.message,
                                            null,
                                        )
                                    }
                            }
                        }
                    }

                    METHOD_SEND_MEDIA_ACTION -> {
                        val action = (call.arguments as? Map<*, *>)?.get("action")?.toString()
                        result.success(sendMediaAction(action))
                    }

                    METHOD_SET_OVERLAY_CONFIG_V2 -> {
                        val config = OrbitBridgeContracts.parseOverlayConfigV2(call.arguments)
                        OrbitNotificationConfig.setAllowedPackages(config.allowedPackages)
                        OrbitEventService.setOverlayDimensions(config.dimensions)
                        OrbitEventService.setOverlayBehavior(config.behavior)
                        result.success(true)
                    }

                    METHOD_TRIGGER_DEBUG_OVERLAY_EVENT_V2 -> {
                        val request = OrbitBridgeContracts.parseDebugTriggerRequestV2(call.arguments)
                        if (request == null) {
                            result.error(
                                "invalid_debug_request",
                                "triggerDebugOverlayEventV2 expects schemaVersion=2 and a valid action",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        val ok = OrbitEventService.triggerDebugOverlayEvent(this, request)
                        result.success(ok)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun getPermissionStatus(): Map<String, Boolean> {
        return mapOf(
            KEY_POST_NOTIFICATIONS_GRANTED to isPostNotificationsGranted(),
            KEY_NOTIFICATION_ACCESS_GRANTED to hasNotificationListenerAccess(),
            KEY_OVERLAY_GRANTED to canDrawOverlays(),
        )
    }

    private fun requestPostNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        if (isPostNotificationsGranted()) {
            result.success(true)
            return
        }

        if (pendingPostNotificationsResult != null) {
            result.error(
                "permission_request_in_progress",
                "Notification permission request already in progress",
                null,
            )
            return
        }

        pendingPostNotificationsResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_POST_NOTIFICATIONS,
        )
    }

    private fun openNotificationAccessSettings(): Boolean {
        return launchSettingsIntent(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    private fun openOverlaySettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        return launchSettingsIntent(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private fun openAppNotificationSettings(targetPackage: String?): Boolean {
        val packageToOpen = targetPackage?.takeIf { it.isNotBlank() } ?: packageName
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageToOpen)
        }
        return launchSettingsIntent(intent)
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val appsByPackage = mutableMapOf<String, InstalledAppEntry>()
        val packageManager = packageManager

        val installedApplications = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getInstalledApplications(0)
        }

        for (applicationInfo in installedApplications) {
            val pkg = applicationInfo.packageName ?: continue
            if (pkg == packageName) {
                continue
            }
            if (packageManager.getLaunchIntentForPackage(pkg) == null) {
                continue
            }
            val label = packageManager.getApplicationLabel(applicationInfo).toString()
            appsByPackage[pkg.lowercase()] = InstalledAppEntry(
                packageName = pkg,
                label = label,
                isWorkProfile = false,
            )
        }

        val launcherApps = getSystemService(LauncherApps::class.java)
        val userManager = getSystemService(UserManager::class.java)
        val personalHandle = Process.myUserHandle()
        val profiles = userManager?.userProfiles.orEmpty()

        for (profile in profiles) {
            val isWorkProfile = profile != personalHandle
            val activities = runCatching {
                launcherApps?.getActivityList(null, profile).orEmpty()
            }.getOrDefault(emptyList())

            for (activity in activities) {
                val pkg = activity.applicationInfo.packageName ?: continue
                if (pkg == packageName) {
                    continue
                }

                val normalized = pkg.lowercase()
                val existing = appsByPackage[normalized]
                val label = activity.label?.toString()
                    ?: existing?.label
                    ?: pkg

                appsByPackage[normalized] = InstalledAppEntry(
                    packageName = pkg,
                    label = label,
                    isWorkProfile = existing?.isWorkProfile == true || isWorkProfile,
                )
            }
        }

        return appsByPackage.values
            .sortedWith(
                compareBy<InstalledAppEntry> { it.label.lowercase() }
                    .thenBy { it.packageName.lowercase() },
            )
            .map { app ->
                mapOf(
                    "packageName" to app.packageName,
                    "label" to app.label,
                    "isWorkProfile" to app.isWorkProfile,
                )
            }
    }

    private fun sendMediaAction(action: String?): Boolean {
        val keyCode = when (action) {
            "playPause" -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
            "previous" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            else -> return false
        }

        val audioManager = getSystemService(AudioManager::class.java) ?: return false
        return runCatching {
            val down = KeyEvent(KeyEvent.ACTION_DOWN, keyCode)
            val up = KeyEvent(KeyEvent.ACTION_UP, keyCode)
            audioManager.dispatchMediaKeyEvent(down)
            audioManager.dispatchMediaKeyEvent(up)
            true
        }.getOrDefault(false)
    }

    private fun launchSettingsIntent(intent: Intent): Boolean {
        return runCatching {
            startActivity(intent)
            true
        }.getOrDefault(false)
    }

    private fun isPostNotificationsGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }

        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasNotificationListenerAccess(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ) ?: return false

        val expected = ComponentName(this, OrbitNotificationListenerService::class.java)
        return enabled
            .split(":")
            .mapNotNull { flattened -> ComponentName.unflattenFromString(flattened) }
            .any { component -> component == expected }
    }

    private fun canDrawOverlays(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        return Settings.canDrawOverlays(this)
    }

    companion object {
        private const val PERMISSION_CHANNEL = "orbit/permissions"

        private const val METHOD_GET_PERMISSION_STATUS = "getPermissionStatus"
        private const val METHOD_REQUEST_POST_NOTIFICATIONS = "requestPostNotifications"
        private const val METHOD_OPEN_NOTIFICATION_ACCESS_SETTINGS =
            "openNotificationAccessSettings"
        private const val METHOD_OPEN_OVERLAY_SETTINGS = "openOverlaySettings"
        private const val METHOD_OPEN_APP_NOTIFICATION_SETTINGS =
            "openAppNotificationSettings"
        private const val METHOD_GET_INSTALLED_APPS = "getInstalledApps"
        private const val METHOD_SEND_MEDIA_ACTION = "sendMediaAction"
        private const val METHOD_SET_OVERLAY_CONFIG_V2 = "setOverlayConfigV2"
        private const val METHOD_TRIGGER_DEBUG_OVERLAY_EVENT_V2 = "triggerDebugOverlayEventV2"

        private const val KEY_POST_NOTIFICATIONS_GRANTED = "postNotificationsGranted"
        private const val KEY_NOTIFICATION_ACCESS_GRANTED = "notificationAccessGranted"
        private const val KEY_OVERLAY_GRANTED = "overlayGranted"

        private const val REQUEST_POST_NOTIFICATIONS = 8042
    }

    private data class InstalledAppEntry(
        val packageName: String,
        val label: String,
        val isWorkProfile: Boolean,
    )
}
