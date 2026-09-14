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
                "ring" -> {
                    ring(
                        (call.argument<Double>("volume") ?: 1.0).toFloat().coerceIn(0f, 1f),
                        call.argument<Boolean>("short") ?: false,
                    )
                    result.success(null)
                }
                "stopRing" -> { stopRing(); result.success(null) }
                "chime" -> {
                    chime((call.argument<Double>("volume") ?: 1.0).toFloat().coerceIn(0f, 1f))
                    result.success(null)
                }
                "decode" -> {
                    val bytes = call.arguments as? ByteArray
                    if (bytes == null) { result.success(null) }
                    else workerHandler.post {
                        val out = try { decodeTo16k(bytes) } catch (e: Exception) {
                            Log.w(TAG, "decode failed: ${e.message}"); null
                        }
                        mainHandler.post { result.success(out) }
                    }
                }
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

    // ── Decoding an announcement ─────────────────────────────────────

    /**
     * Decodes a whole audio file (whatever the platform's codecs read:
     * MP3, AAC, OGG, WAV) to 16 kHz mono PCM16, the intercom's own
     * format, so a clip from Home Assistant's text to speech rides the
     * same frames a microphone would. Runs on the worker.
     */
    private fun decodeTo16k(bytes: ByteArray): ByteArray? {
        val file = java.io.File.createTempFile("ks-announce", ".bin", appContext.cacheDir)
        try {
            file.writeBytes(bytes)
            val extractor = android.media.MediaExtractor()
            extractor.setDataSource(file.path)
            var trackIndex = -1
            var format: android.media.MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                val mime = f.getString(android.media.MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) { trackIndex = i; format = f; break }
            }
            if (trackIndex < 0 || format == null) { extractor.release(); return null }
            extractor.selectTrack(trackIndex)
            val mime = format.getString(android.media.MediaFormat.KEY_MIME)!!
            var rate = format.getInteger(android.media.MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(android.media.MediaFormat.KEY_CHANNEL_COUNT)
            val codec = android.media.MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()
            val samples = java.io.ByteArrayOutputStream()
            val info = android.media.MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            var floatPcm = false
            while (!outputDone) {
                if (!inputDone) {
                    val inIndex = codec.dequeueInputBuffer(10_000)
                    if (inIndex >= 0) {
                        val buf = codec.getInputBuffer(inIndex)!!
                        val n = extractor.readSampleData(buf, 0)
                        if (n < 0) {
                            codec.queueInputBuffer(inIndex, 0, 0, 0, android.media.MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(inIndex, 0, n, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val outIndex = codec.dequeueOutputBuffer(info, 10_000)
                when {
                    outIndex == android.media.MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val f = codec.outputFormat
                        rate = f.getInteger(android.media.MediaFormat.KEY_SAMPLE_RATE)
                        channels = f.getInteger(android.media.MediaFormat.KEY_CHANNEL_COUNT)
                        floatPcm = Build.VERSION.SDK_INT >= 24 &&
                            f.containsKey(android.media.MediaFormat.KEY_PCM_ENCODING) &&
                            f.getInteger(android.media.MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
                    }
                    outIndex >= 0 -> {
                        val buf = codec.getOutputBuffer(outIndex)!!
                        buf.position(info.offset)
                        buf.limit(info.offset + info.size)
                        val chunk = ByteArray(info.size)
                        buf.get(chunk)
                        samples.write(chunk)
                        codec.releaseOutputBuffer(outIndex, false)
                        if (info.flags and android.media.MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                }
            }
            codec.stop(); codec.release(); extractor.release()
            val raw = samples.toByteArray()
            // To mono 16-bit at the decoder's rate.
            val bb = java.nio.ByteBuffer.wrap(raw).order(java.nio.ByteOrder.LITTLE_ENDIAN)
            val frames = if (floatPcm) raw.size / 4 / channels else raw.size / 2 / channels
            val mono = FloatArray(frames)
            for (i in 0 until frames) {
                var acc = 0f
                for (c in 0 until channels) {
                    acc += if (floatPcm) bb.float else bb.short / 32768f
                }
                mono[i] = acc / channels
            }
            // Linear resample to 16 kHz.
            val outFrames = (frames.toLong() * SAMPLE_RATE / rate).toInt()
            val out = java.nio.ByteBuffer.allocate(outFrames * 2).order(java.nio.ByteOrder.LITTLE_ENDIAN)
            val step = rate.toDouble() / SAMPLE_RATE
            for (i in 0 until outFrames) {
                val pos = i * step
                val j = pos.toInt().coerceAtMost(frames - 1)
                val k = (j + 1).coerceAtMost(frames - 1)
                val frac = (pos - j).toFloat()
                val v = mono[j] + (mono[k] - mono[j]) * frac
                out.putShort((v * 32767f).toInt().coerceIn(-32768, 32767).toShort())
            }
            Log.i(TAG, "decoded ${raw.size} bytes ($mime, $rate Hz, $channels ch) to ${outFrames * 1000L / SAMPLE_RATE} ms")
            return out.array()
        } finally {
            runCatching { file.delete() }
        }
    }

    // ── The ring ────────────────────────────────────────────────────

    @Volatile private var ringTrack: AudioTrack? = null

    /**
     * The built-in ring, made here rather than shipped: the classic
     * telephone ring, 440 and 480 Hz together, as two bursts of 0.4 s with
     * a 0.2 s gap, or one burst of 0.35 s for the short form. Played on the
     * media route at the notification volume, like the chime.
     */
    private fun ring(volume: Float, short: Boolean) {
        stopRing()
        val sr = 16000
        val burst = if (short) (sr * 0.35).toInt() else (sr * 0.4).toInt()
        val gap = (sr * 0.2).toInt()
        val total = if (short) burst else burst * 2 + gap
        val pcm = ShortArray(total)
        val fade = sr / 100
        fun fill(start: Int, length: Int) {
            for (i in 0 until length) {
                val t = i.toDouble() / sr
                var a = 0.5 * Math.sin(2 * Math.PI * 440 * t) + 0.5 * Math.sin(2 * Math.PI * 480 * t)
                val env = when {
                    i < fade -> i.toDouble() / fade
                    i > length - fade -> (length - i).toDouble() / fade
                    else -> 1.0
                }
                a *= env * 0.6
                pcm[start + i] = (a * Short.MAX_VALUE).toInt().coerceIn(-32768, 32767).toShort()
            }
        }
        fill(0, burst)
        if (!short) fill(burst + gap, burst)
        val track = try {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(sr)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setTransferMode(AudioTrack.MODE_STATIC)
                .setBufferSizeInBytes(pcm.size * 2)
                .build()
        } catch (e: Exception) {
            Log.w(TAG, "ring track failed: ${e.message}")
            return
        }
        // A static track reads STATE_NO_STATIC_DATA until its buffer is
        // written, and STATE_INITIALIZED only after; only uninitialized
        // means it failed.
        if (track.state == AudioTrack.STATE_UNINITIALIZED) {
            Log.w(TAG, "ring track init failed")
            runCatching { track.release() }
            return
        }
        val out = AudioRouting.currentOutput()
        if (Build.VERSION.SDK_INT >= 28 && out != null) runCatching { track.preferredDevice = out }
        val written = track.write(pcm, 0, pcm.size)
        if (written != pcm.size || track.state != AudioTrack.STATE_INITIALIZED) {
            Log.w(TAG, "ring track took $written of ${pcm.size} samples (state=${track.state})")
            runCatching { track.release() }
            return
        }
        Log.i(TAG, "ring ${if (short) "short" else "double"} at ${"%.2f".format(volume)}")
        runCatching { track.setVolume(volume * VolumeController.assistGain.coerceAtLeast(0f).let { if (VolumeController.isFixed) it else 1f }) }
        ringTrack = track
        track.play()
        // Release once it has played out, unless stopped first.
        val ms = total * 1000L / sr + 200
        workerHandler.postDelayed({ if (ringTrack === track) stopRing() }, ms)
    }

    /**
     * The built-in announcement chime: two soft bell notes, E6 then C6,
     * each a sine with a quick attack and an exponential decay, the
     * second starting under the first's tail. About a second.
     */
    private fun chime(volume: Float) {
        stopRing()
        val sr = 16000
        val total = (sr * 1.1).toInt()
        val pcm = ShortArray(total)
        fun note(freq: Double, start: Int, length: Int, gain: Double) {
            for (i in 0 until length) {
                val idx = start + i
                if (idx >= total) break
                val t = i.toDouble() / sr
                val attack = (i / (sr * 0.008)).coerceAtMost(1.0)
                val env = attack * Math.exp(-t * 4.5)
                val a = (Math.sin(2 * Math.PI * freq * t) + 0.25 * Math.sin(2 * Math.PI * freq * 2 * t)) * env * gain
                val v = pcm[idx] + (a * Short.MAX_VALUE * 0.45).toInt()
                pcm[idx] = v.coerceIn(-32768, 32767).toShort()
            }
        }
        note(1318.5, 0, (sr * 0.9).toInt(), 1.0)
        note(1046.5, (sr * 0.22).toInt(), (sr * 0.88).toInt(), 0.9)
        playStatic(pcm, sr, volume, "chime")
    }

    /** Plays a synthesized clip on the media route at [volume], releasing it when done. */
    private fun playStatic(pcm: ShortArray, sr: Int, volume: Float, what: String) {
        val track = try {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(sr)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setTransferMode(AudioTrack.MODE_STATIC)
                .setBufferSizeInBytes(pcm.size * 2)
                .build()
        } catch (e: Exception) {
            Log.w(TAG, "$what track failed: ${e.message}")
            return
        }
        if (track.state == AudioTrack.STATE_UNINITIALIZED) {
            Log.w(TAG, "$what track init failed")
            runCatching { track.release() }
            return
        }
        val out = AudioRouting.currentOutput()
        if (Build.VERSION.SDK_INT >= 28 && out != null) runCatching { track.preferredDevice = out }
        val written = track.write(pcm, 0, pcm.size)
        if (written != pcm.size || track.state != AudioTrack.STATE_INITIALIZED) {
            Log.w(TAG, "$what track took $written of ${pcm.size} samples (state=${track.state})")
            runCatching { track.release() }
            return
        }
        Log.i(TAG, "$what at ${"%.2f".format(volume)}")
        runCatching { track.setVolume(volume) }
        ringTrack = track
        track.play()
        val ms = pcm.size * 1000L / sr + 200
        workerHandler.postDelayed({ if (ringTrack === track) stopRing() }, ms)
    }

    private fun stopRing() {
        val t = ringTrack ?: return
        ringTrack = null
        runCatching { t.stop() }
        runCatching { t.release() }
    }

    /**
     * The intercom fader over the device's master and nothing else: not
     * the assistant fader, which is Voice Satellite's, and not the media
     * one. On the communication route the master is the call stream's
     * compensation; on the media route the hardware applies it, except
     * on fixed-volume devices where it is software.
     */
    private fun applyVolume() {
        val t = track ?: return
        val master = if (lease != null) {
            VolumeController.communicationGain(output?.type ?: AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
        } else {
            VolumeController.masterGain
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
