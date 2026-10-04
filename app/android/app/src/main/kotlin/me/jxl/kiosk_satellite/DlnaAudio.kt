package me.jxl.kiosk_satellite

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The DLNA renderer's player for audio. Video goes through the video_player
 * plugin, whose ExoPlayer the app cannot reach inside, so music would be
 * the one sound the kiosk plays that the software echo canceller never
 * hears. Here it plays through Media3 with a [SinkTap], one item at a time,
 * and reports its state to Dart twice a second and on every change.
 */
class DlnaAudio(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        private const val TAG = "DlnaAudio"
        private const val CHANNEL = "kiosk_satellite/dlna_audio"
        private const val REPORT_MS = 500L
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())
    private var player: ExoPlayer? = null
    private var tap: SinkTap? = null
    private var error: String? = null

    private val report = object : Runnable {
        override fun run() {
            send()
            if (player != null) main.postDelayed(this, REPORT_MS)
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> {
                    open(call.argument<String>("uri") ?: "", call.argument<Boolean>("hls") ?: false)
                    result.success(null)
                }
                "play" -> {
                    player?.play()
                    result.success(null)
                }
                "pause" -> {
                    player?.pause()
                    result.success(null)
                }
                "seek" -> {
                    player?.seekTo((call.argument<Number>("ms") ?: 0).toLong())
                    result.success(null)
                }
                "volume" -> {
                    val v = (call.argument<Number>("volume") ?: 1.0).toFloat().coerceIn(0f, 1f)
                    player?.volume = v
                    tap?.gain = v
                    result.success(null)
                }
                "close" -> {
                    close()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun open(uri: String, hls: Boolean) {
        close()
        error = null
        val echoTap = SinkTap()
        val exo = try {
            ExoPlayer.Builder(context, tappedRenderers(context, echoTap))
                // A controller's access log should name the kiosk.
                .setMediaSourceFactory(
                    DefaultMediaSourceFactory(
                        DefaultDataSource.Factory(
                            context,
                            DefaultHttpDataSource.Factory().setUserAgent(AppIdentity.userAgent),
                        ),
                    ),
                )
                .setReleaseTimeoutMs(100)
                .build()
        } catch (e: Exception) {
            echoTap.close()
            error = "${e.message}"
            send()
            return
        }
        exo.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                .build(),
            /* handleAudioFocus = */ false,
        )
        exo.addListener(object : Player.Listener {
            override fun onEvents(player: Player, events: Player.Events) {
                if (this@DlnaAudio.player === exo) send()
            }

            override fun onPlayerError(e: PlaybackException) {
                if (player !== exo) return
                Log.w(TAG, "playback failed: ${e.errorCodeName} ${e.message}")
                error = "${e.errorCodeName}: ${e.cause?.message ?: e.message}"
                send()
            }
        })
        val item = MediaItem.Builder().setUri(uri)
        // HLS must be declared: sniffing by extension misses signed URLs.
        if (hls) item.setMimeType(MimeTypes.APPLICATION_M3U8)
        exo.setMediaItem(item.build())
        player = exo
        tap = echoTap
        exo.prepare()
        main.postDelayed(report, REPORT_MS)
    }

    private fun send() {
        val exo = player
        val duration = exo?.duration?.takeIf { it != C.TIME_UNSET && it > 0 } ?: 0L
        val ended = exo?.playbackState == Player.STATE_ENDED
        channel.invokeMethod(
            "state",
            mapOf(
                "ready" to (exo?.playbackState == Player.STATE_READY || ended),
                "playing" to (exo?.isPlaying == true),
                "positionMs" to if (ended) duration else (exo?.currentPosition ?: 0L),
                "durationMs" to duration,
                "error" to error,
            ),
        )
    }

    private fun close() {
        main.removeCallbacks(report)
        player?.release()
        player = null
        tap?.close()
        tap = null
    }
}
