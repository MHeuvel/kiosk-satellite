package me.jxl.kiosk_satellite

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Broadcasts that start and end a native Voice Satellite turn, for ADB, a
 * remote's button mapper or an automation app on the device:
 *
 *   adb shell am broadcast -a me.jxl.kiosk_satellite.action.VOICE_WAKE --ei slot 1
 *   adb shell am broadcast -a me.jxl.kiosk_satellite.action.VOICE_CANCEL
 *
 * Registered in code rather than the manifest: the turn lives in Dart, so
 * there is nothing to do while the engine is down, and a receiver
 * registered in code still gets implicit broadcasts on Android 8+. EXPORTED
 * because other apps are the whole point. Only these two actions exist, so
 * nothing else the app can do is reachable without the remote admin's token.
 */
class VoiceIntentBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    companion object {
        private const val CHANNEL = "kiosk_satellite/voice_intents"
        const val ACTION_WAKE = "me.jxl.kiosk_satellite.action.VOICE_WAKE"
        const val ACTION_CANCEL = "me.jxl.kiosk_satellite.action.VOICE_CANCEL"
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_WAKE -> channel.invokeMethod(
                    "wake",
                    mapOf("slot" to intent.getIntExtra("slot", 1)),
                )
                ACTION_CANCEL -> channel.invokeMethod("cancel", null)
            }
        }
    }

    init {
        try {
            ContextCompat.registerReceiver(
                context,
                receiver,
                IntentFilter().apply {
                    addAction(ACTION_WAKE)
                    addAction(ACTION_CANCEL)
                },
                ContextCompat.RECEIVER_EXPORTED,
            )
        } catch (e: Exception) {
            Log.w("kiosk_satellite", "voice intent receiver failed", e)
        }
    }
}
