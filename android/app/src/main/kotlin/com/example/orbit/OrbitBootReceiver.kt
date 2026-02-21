package com.example.orbit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class OrbitBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> OrbitEventService.start(context)
        }
    }
}
