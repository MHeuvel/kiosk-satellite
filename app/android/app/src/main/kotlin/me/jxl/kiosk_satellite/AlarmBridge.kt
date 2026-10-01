package me.jxl.kiosk_satellite

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.common.BinaryMessenger
import java.io.File
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
 *   media volume and a muted media stream. The ring plays through Media3
 *   with a [SinkTap], so the software echo canceller hears it too and the
 *   wake word and stop word still work while it rings.
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
        private const val TONE = "tone"
        private const val PHRASE = "phrase"

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
    private var player: ExoPlayer? = null
    private var tap: SinkTap? = null
    private var savedAlarmVolume: Int? = null

    /** The tone, and the spoken phrase that plays after every second pass
     *  of it once Dart has made it: the player's list is then tone, tone,
     *  phrase, repeated. */
    private var tonePath: String? = null
    private var speechPath: String? = null

    /** Ease in: the ring starts silent and its gain climbs to full over
     *  [rampMs], on a square curve so the first seconds stay soft. */
    private var rampStart = 0L
    private var rampMs = 0L
    private val ramp = object : Runnable {
        override fun run() {
            applyGain()
            if (gain() < 1f) main.postDelayed(this, 100)
        }
    }

    private fun gain(): Float {
        if (rampMs <= 0) return 1f
        val t = ((SystemClock.elapsedRealtime() - rampStart).toFloat() / rampMs).coerceIn(0f, 1f)
        return t * t
    }

    private fun applyGain() {
        val g = gain()
        player?.volume = g
        tap?.gain = g
    }

    /** A player on the alarm stream whose output also goes to [echoTap]. */
    private fun alarmPlayer(echoTap: SinkTap): ExoPlayer {
        return ExoPlayer.Builder(context, tappedRenderers(context, echoTap))
            // Let a slow codec teardown finish off the main thread.
            .setReleaseTimeoutMs(100)
            .build()
            .apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(C.USAGE_ALARM)
                        .setContentType(C.AUDIO_CONTENT_TYPE_SONIFICATION)
                        .build(),
                    /* handleAudioFocus = */ false,
                )
            }
    }

    private fun item(path: String, id: String): MediaItem =
        MediaItem.Builder().setUri(path).setMediaId(id).build()

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
                        (call.argument<Number>("easeMs") ?: 0).toLong(),
                    ),
                )
                "speech" -> {
                    speak(call.argument<String>("path"))
                    result.success(null)
                }
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
    private fun ring(path: String, volume: Double, loop: Boolean, easeMs: Long = 0): Boolean {
        stopRing()
        if (path.isEmpty()) return false
        // Media3 reports a bad file only once it tries it: a missing one
        // fails here, as it always has, so Dart knows nothing rang.
        if (!path.contains("://") && !File(path).canRead()) return false
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
            val echoTap = SinkTap()
            val exo = try {
                alarmPlayer(echoTap)
            } catch (e: Exception) {
                echoTap.close()
                throw e
            }
            exo.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(state: Int) {
                    if (state != Player.STATE_ENDED || player !== exo) return
                    // A preview plays once: let go of the player and put the
                    // alarm volume back as soon as it ends.
                    stopRing()
                    channel.invokeMethod("ringEnded", null)
                }

                override fun onPlayerError(error: PlaybackException) {
                    if (player !== exo) return
                    Log.w(TAG, "ring failed: ${error.errorCodeName}")
                    if (speechPath != null && exo.currentMediaItem?.mediaId == PHRASE) {
                        // The phrase would not play: ring the tone alone.
                        speechPath = null
                        playlist(exo)
                        exo.prepare()
                        exo.play()
                        return
                    }
                    channel.invokeMethod("ringEnded", mapOf("error" to error.errorCodeName))
                }
            })
            tonePath = path
            player = exo
            tap = echoTap
            playlist(exo, loop)
            rampMs = if (loop) easeMs.coerceAtLeast(0) else 0
            rampStart = SystemClock.elapsedRealtime()
            applyGain()
            exo.prepare()
            exo.play()
            if (rampMs > 0) main.postDelayed(ramp, 100)
            true
        } catch (e: Exception) {
            Log.w(TAG, "ring($path) failed: $e")
            restoreVolume()
            false
        }
    }

    /** The phrase to say between the rings, or null to ring the tone
     *  alone again. Takes effect after the pass playing now. */
    private fun speak(path: String?) {
        speechPath = path?.takeIf { it.isNotEmpty() }
        player?.let { playlist(it) }
    }

    /** The tone alone, looping or once, or with the phrase after every
     *  second pass. The item playing now keeps playing and the list after
     *  it changes, so the change lands when it ends, except that dropping
     *  the phrase while it plays goes straight back to the tone. */
    private fun playlist(exo: ExoPlayer, loop: Boolean = true) {
        val tone = tonePath ?: return
        val phrase = speechPath
        if (exo.mediaItemCount == 0 || (phrase == null && exo.currentMediaItem?.mediaId == PHRASE)) {
            exo.setMediaItem(item(tone, TONE))
        } else {
            val current = exo.currentMediaItemIndex
            if (current < exo.mediaItemCount - 1) exo.removeMediaItems(current + 1, exo.mediaItemCount)
            if (current > 0) exo.removeMediaItems(0, current)
        }
        exo.repeatMode = when {
            !loop -> Player.REPEAT_MODE_OFF
            phrase == null -> Player.REPEAT_MODE_ONE
            else -> {
                exo.addMediaItems(listOf(item(tone, TONE), item(phrase, PHRASE)))
                Player.REPEAT_MODE_ALL
            }
        }
    }

    private fun stopRing() {
        main.removeCallbacks(ramp)
        rampMs = 0
        speechPath = null
        tonePath = null
        player?.release()
        player = null
        tap?.close()
        tap = null
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
