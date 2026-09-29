package me.jxl.kiosk_satellite

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The native half of the kiosk's own alarms. Dart owns the list, works
 * out the next ring and decides what shows; this side only does what Dart
 * cannot do on its own:
 *
 * - wake the device at the ring time through [AlarmManager.setAlarmClock],
 *   which is exact, fires in Doze and makes the ring the system's next
 *   alarm clock (so the existing Next alarm sensor reports it), plus an
 *   exact wake at the start of a sunrise window;
 * - bring the process back when it was gone: the receiver starts the
 *   keep-alive service, the Application builds the Flutter engine, and the
 *   alarm manager in Dart finds the due alarm on its first check;
 * - ring on the alarm stream, looping, at the alarm volume, apart from the
 *   media volume and a muted media stream.
 */
class AlarmBridge(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        private const val TAG = "AlarmBridge"
        private const val CHANNEL = "kiosk_satellite/alarms"
        private const val REQUEST_RING = 7401
        private const val REQUEST_WAKE = 7402
        private const val REQUEST_SHOW = 7403
        const val ACTION_FIRE = "me.jxl.kiosk_satellite.ALARM_FIRE"
        const val EXTRA_KIND = "kind"

        /** Set while an engine is attached, so a fire reaches Dart at once
         *  instead of waiting for its next check. */
        @Volatile var onFire: ((String) -> Unit)? = null

        private fun operation(context: Context, request: Int, kind: String, flags: Int): PendingIntent? =
            PendingIntent.getBroadcast(
                context,
                request,
                Intent(context, AlarmReceiver::class.java)
                    .setAction(ACTION_FIRE)
                    .putExtra(EXTRA_KIND, kind),
                flags or PendingIntent.FLAG_IMMUTABLE,
            )
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var savedAlarmVolume: Int? = null

    init {
        onFire = { kind -> main.post { channel.invokeMethod("alarmFired", mapOf("kind" to kind)) } }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    schedule(
                        (call.argument<Number>("ringAt"))?.toLong(),
                        (call.argument<Number>("wakeAt"))?.toLong(),
                    )
                    result.success(null)
                }
                "ring" -> result.success(
                    ring(
                        call.argument<String>("path") ?: "",
                        (call.argument<Number>("volume") ?: 0.7).toDouble(),
                        call.argument<Boolean>("loop") ?: true,
                    ),
                )
                "stop" -> {
                    stopRing()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private val alarmManager: AlarmManager
        get() = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    /** One ring alarm and one wake alarm at most; null cancels either. */
    private fun schedule(ringAt: Long?, wakeAt: Long?) {
        val ring = operation(context, REQUEST_RING, "ring", PendingIntent.FLAG_UPDATE_CURRENT) ?: return
        val wake = operation(context, REQUEST_WAKE, "wake", PendingIntent.FLAG_UPDATE_CURRENT) ?: return
        alarmManager.cancel(ring)
        alarmManager.cancel(wake)
        if (ringAt != null) {
            val show = HomeRole.launchIntent(context)?.let {
                PendingIntent.getActivity(
                    context, REQUEST_SHOW, it,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
            try {
                alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(ringAt, show), ring)
            } catch (e: SecurityException) {
                // No exact alarm grant (an Android 14 install that refused
                // it): still wake near the time rather than not at all.
                Log.w(TAG, "setAlarmClock refused, ringing inexactly: $e")
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, ringAt, ring)
            }
        }
        if (wakeAt != null && (ringAt == null || wakeAt < ringAt)) {
            try {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, wakeAt, wake)
            } catch (e: SecurityException) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, wakeAt, wake)
            }
        }
    }

    /** Loop [path] on the alarm stream with that stream set to [volume]
     *  of its range, restored when the ring stops. */
    private fun ring(path: String, volume: Double, loop: Boolean): Boolean {
        stopRing()
        if (path.isEmpty()) return false
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return try {
            val max = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            savedAlarmVolume = audio.getStreamVolume(AudioManager.STREAM_ALARM)
            val level = Math.round(volume.coerceIn(0.0, 1.0) * max).toInt().coerceIn(if (volume > 0) 1 else 0, max)
            try {
                audio.setStreamVolume(AudioManager.STREAM_ALARM, level, 0)
            } catch (e: SecurityException) {
                // Do Not Disturb policy access on some ROMs: ring at the
                // stream's own level rather than not at all.
                Log.w(TAG, "alarm volume not set: $e")
            }
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            mp.setDataSource(path)
            mp.isLooping = loop
            mp.setOnCompletionListener {
                // A preview plays once: let go of the player and put the
                // alarm volume back as soon as it ends.
                if (!loop) main.post {
                    if (player === mp) stopRing()
                    channel.invokeMethod("ringEnded", null)
                }
            }
            mp.setOnErrorListener { _, what, extra ->
                Log.w(TAG, "ring failed: $what/$extra")
                main.post { channel.invokeMethod("ringEnded", mapOf("error" to "$what/$extra")) }
                true
            }
            mp.prepare()
            mp.start()
            player = mp
            true
        } catch (e: Exception) {
            Log.w(TAG, "ring($path) failed: $e")
            restoreVolume()
            false
        }
    }

    private fun stopRing() {
        player?.let {
            try { it.stop() } catch (_: IllegalStateException) {}
            it.release()
        }
        player = null
        restoreVolume()
    }

    private fun restoreVolume() {
        val saved = savedAlarmVolume ?: return
        savedAlarmVolume = null
        try {
            val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audio.setStreamVolume(AudioManager.STREAM_ALARM, saved, 0)
        } catch (_: Exception) {}
    }
}

/**
 * The alarm clock and the sunrise wake land here. The service start keeps
 * or brings the process up; a short wake lock covers the hand-off to Dart,
 * which rings or starts the sunrise from its own state.
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmBridge.ACTION_FIRE) return
        val kind = intent.getStringExtra(AlarmBridge.EXTRA_KIND) ?: "ring"
        Log.i("AlarmReceiver", "alarm $kind")
        try {
            val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "KioskSatellite:alarm")
                .acquire(30_000L)
        } catch (_: Exception) {}
        KioskSatelliteService.ensureRunning(context)
        AlarmBridge.onFire?.invoke(kind)
    }
}
