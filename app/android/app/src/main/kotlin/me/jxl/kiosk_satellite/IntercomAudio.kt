package me.jxl.kiosk_satellite

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.audiofx.AcousticEchoCanceler
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicInteger

/**
 * The intercom's playback sink: one streaming AudioTrack on the
 * communication route, fed the far kiosk's voice as raw 16 kHz mono PCM16.
 *
 * On the communication route on purpose: the microphone capture runs on
 * VOICE_COMMUNICATION with the platform echo canceller, and the canceller
 * only cancels what plays through that route. [CommunicationPlayback]
 * holds the route and the mode for the whole call through one lease, the
 * way a chime or TTS does for its own length.
 *
 * Methods (channel `kiosk_satellite/intercom_audio`):
 *  - start {volume}: opens the track, `volume` the linear base gain 0..1
 *    (the intercom fader, tapered on the Dart side). True when playing.
 *  - write <bytes>: one chunk. Queued to a worker; the track's own buffer
 *    is the jitter buffer, and a backlog past a few chunks is dropped so
 *    the voice never drifts seconds behind.
 *  - setVolume {volume}: moves the fader live.
 *  - stop: releases the track and the route.
 *  - aecAvailable: whether the platform has an echo canceller, which is
 *    what makes a hands free call possible.
 *
 * The master volume rides in through [VolumeController.communicationGain]
 * like every communication sound, re-read on every fader change.
 */
class IntercomAudio(context: Context, messenger: BinaryMessenger) {
    companion object {
        private const val TAG = "IntercomAudio"
        private const val SAMPLE_RATE = 16000
        private const val BUFFER_MS = 400
        private const val MAX_QUEUED = 6
    }

    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, "kiosk_satellite/intercom_audio")
    private val communication = CommunicationPlayback.get(appContext)
    private val worker = HandlerThread("ks-intercom").apply { start() }
    private val workerHandler = Handler(worker.looper)
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var track: AudioTrack? = null
    @Volatile private var lease: AutoCloseable? = null
    @Volatile private var output: AudioDeviceInfo? = null
    @Volatile private var baseVolume = 1f
    private val queued = AtomicInteger(0)

    private val volumeListener: () -> Unit = { applyVolume() }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    baseVolume = (call.argument<Double>("volume") ?: 1.0).toFloat().coerceIn(0f, 1f)
                    result.success(start())
                }
                "write" -> {
                    val bytes = call.arguments as? ByteArray
                    if (bytes != null) enqueue(bytes)
                    result.success(null)
                }
                "setVolume" -> {
                    baseVolume = (call.argument<Double>("volume") ?: 1.0).toFloat().coerceIn(0f, 1f)
                    applyVolume()
                    result.success(null)
                }
                "stop" -> { stop(); result.success(null) }
                "aecAvailable" -> result.success(AcousticEchoCanceler.isAvailable())
                else -> result.notImplemented()
            }
        }
        VolumeController.addListener(volumeListener)
    }

    private fun start(): Boolean {
        stop()
        val selected = AudioRouting.currentOutput()
        val acquired = communication.acquire(selected)
        val target = if (acquired != null) communication.output else selected
        val comm = acquired != null
        val minBuf = AudioTrack.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuf <= 0) {
            Log.e(TAG, "unsupported format")
            acquired?.close()
            return false
        }
        val bufferBytes = maxOf(minBuf * 2, SAMPLE_RATE * 2 * BUFFER_MS / 1000)
        val newTrack = try {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(
                            if (comm) AudioAttributes.USAGE_VOICE_COMMUNICATION
                            else AudioAttributes.USAGE_MEDIA,
                        )
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(SAMPLE_RATE)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setTransferMode(AudioTrack.MODE_STREAM)
                .setBufferSizeInBytes(bufferBytes)
                .build()
        } catch (e: Exception) {
            Log.e(TAG, "AudioTrack create failed", e)
            acquired?.close()
            return false
        }
        if (newTrack.state != AudioTrack.STATE_INITIALIZED) {
            Log.e(TAG, "AudioTrack init failed (state=${newTrack.state})")
            runCatching { newTrack.release() }
            acquired?.close()
            return false
        }
        if (Build.VERSION.SDK_INT >= 28 && target != null) {
            runCatching { newTrack.preferredDevice = target }
        }
        track = newTrack
        lease = acquired
        output = target
        applyVolume()
        // Prime a short silence so the first chunk lands on a running
        // track without an underrun at the very start.
        val silence = ByteArray(SAMPLE_RATE * 2 / 10)
        newTrack.write(silence, 0, silence.size)
        newTrack.play()
        Log.i(TAG, "playback started (${if (comm) "communication" else "media"} route, buffer=${bufferBytes}b)")
        return true
    }

    private fun enqueue(bytes: ByteArray) {
        val t = track ?: return
        if (queued.get() >= MAX_QUEUED) {
            // Behind by half a second: the network hiccuped, and playing
            // the backlog would keep the voice late for the whole call.
            return
        }
        queued.incrementAndGet()
        workerHandler.post {
            try {
                if (track === t && t.playState == AudioTrack.PLAYSTATE_PLAYING) {
                    var offset = 0
                    while (offset < bytes.size) {
                        val n = t.write(bytes, offset, bytes.size - offset, AudioTrack.WRITE_BLOCKING)
                        if (n <= 0) break
                        offset += n
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "write failed: ${e.message}")
            } finally {
                queued.decrementAndGet()
            }
        }
    }

    private fun applyVolume() {
        val t = track ?: return
        val master = if (lease != null) {
            VolumeController.communicationGain(output?.type ?: AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
        } else {
            VolumeController.assistGain
        }
        val level = PlaybackVolume.level(baseVolume, 1f, master)
        runCatching { t.setVolume(level) }
    }

    private fun stop() {
        val t = track ?: return
        track = null
        val l = lease
        lease = null
        output = null
        workerHandler.post {
            runCatching { t.pause() }
            runCatching { t.flush() }
            runCatching { t.release() }
            mainHandler.post { runCatching { l?.close() } }
            Log.i(TAG, "playback stopped")
        }
    }
}
