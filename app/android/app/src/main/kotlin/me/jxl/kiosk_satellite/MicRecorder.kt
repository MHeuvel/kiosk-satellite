package me.jxl.kiosk_satellite

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import kotlin.concurrent.thread
import kotlin.math.max

/**
 * Streams 16 kHz mono PCM16 microphone audio to Dart over an EventChannel.
 *
 * Implemented natively (AudioRecord) rather than via a pub package because the
 * available streaming-mic packages don't build against AGP 9. onListen starts
 * capture; onCancel (Dart cancelling the subscription) stops it and releases
 * the mic — which is what frees it for the WebView's getUserMedia during STT.
 *
 * Capture DSP: echo cancellation on by default, with optional noise suppression and AGC.
 * We share capture settings across wake word inference, the stop word, STT
 * and RTSP audio:
 *
 *  - Echo cancellation earns its keep because the stop word listens *while*
 *    TTS plays out of this same device. Without it the mic hears our own
 *    speech and scores it.
 *  - Noise suppression and AGC default to off. Users can
 *    adjust both for their microphone. Both change the signal recognition receives.
 *
 * VOICE_COMMUNICATION rather than MIC is deliberate: it is the capture path
 * that carries the playback reference AEC needs. On a MIC session the effect
 * usually attaches and then silently does nothing. The tradeoff is that this
 * source also applies the platform's own NS/AGC by default, which is exactly
 * what [applyDsp] configures from the user's settings.
 * SoundPlayer must also use communication playback and a communication
 * session. Enabling the capture effect alone does not cancel media playback
 * on devices such as the Samsung Galaxy Tab S8.
 *
 * Capture tuning is configurable because on custom
 * ROMs they are exactly what goes wrong: VOICE_COMMUNICATION is the phone-call
 * capture path, and a ROM that never had its call audio calibrated can deliver
 * it 20 dB down while a recorder app on plain MIC sounds fine. The defaults are
 * the behaviour described above; the overrides arrive as stream arguments,
 * which is why a change of any of them reopens capture.
 *
 * Channel selection: multichannel USB arrays put differently-processed
 * signals on each channel (the reSpeaker XVF3800 sends its comms output on
 * channel 1 and its raw ASR output on channel 2), and Android's stereo-to-
 * mono contraction averages them, polluting the clean channel with the
 * processed one. A `channel` argument of 1..N opens capture with a channel
 * index mask wide enough to include it and forwards only that channel; 0 (the
 * default) is the platform's mono downmix, the app's historical behavior.
 *
 * Capture format: the engines want 16 kHz mono and that is what capture
 * asks for, leaving the platform to convert from whatever the microphone
 * does. Some sound cards record at 48 kHz stereo and nothing else, and an
 * audio HAL that hands the app's format straight to ALSA then refuses the
 * open, reads nothing but errors or delivers the card's frames misread as
 * 16 kHz mono. Capture therefore walks a ladder of shapes ([captureLadder])
 * and steps down it when an open is refused, when reads return only errors
 * or zeros, or when the delivered frame rate does not match the rate opened
 * (the format under the label is not the one asked for). Silence is weak
 * evidence, so [CaptureWalk] decides how much of it a rung gets, where
 * capture lands when the whole ladder has been tried and when it may walk
 * again. Anything but 16 kHz mono is converted here ([CaptureConvert]). A
 * `format` argument of "hardware" starts the ladder at the card's 48 kHz
 * stereo.
 */
class MicRecorder(context: Context, messenger: BinaryMessenger) : EventChannel.StreamHandler {
    companion object {
        const val CHANNEL = "kiosk_satellite/mic"
        private const val TAG = "MicRecorder"
        @Volatile var rtspAudioTap: ((ByteArray, Long) -> Unit)? = null
        @Volatile var inputSelector: String? = null
            private set
        private const val SAMPLE_RATE = 16000
        private const val CHUNK_BYTES = 1280 * 2 // 80 ms of 16-bit mono

        /**
         * The sound card's own format on the devices that cannot do 16 kHz
         * mono: 48 kHz, two channels. Also the deafness guard's second try:
         * a capture stuck on all-zero frames or read errors (a wedged
         * AudioRecord after an audioserver death, a ROM whose direct 16 kHz
         * record path is broken, a HAL that could not open the card at
         * 16 kHz mono) cannot be fixed in place, so it is reopened at this
         * format - the mismatch against a 16 kHz device forces
         * AudioFlinger's record converter path and a fresh server-side
         * track, and a 48 kHz card gets the format it wanted - and
         * converted back to 16 kHz mono here. Echo cancellation can
         * produce exact silence, so communication playback and its
         * settling time are excluded from the silence watchdog.
         */
        private const val HARDWARE_RATE = 48000
        private const val HARDWARE_CHANNELS = 2

        /**
         * Delivered-rate check: a blocking read paces at the real rate, so
         * frames per wall second should match the rate the capture was
         * opened at. An old HAL asked for 48 kHz stereo can hand over mono
         * under the stereo label (half the frames, pitch doubled), and a
         * card's 48 kHz stereo misread as 16 kHz mono arrives six times
         * too fast. Two seconds from the first read is long enough for
         * read granularity not to matter, and the bounds are wide enough
         * that no healthy device trips them.
         */
        private const val RATE_CHECK_NS = 2_000_000_000L
        private const val RATE_RATIO_MIN = 0.6
        private const val RATE_RATIO_MAX = 1.6
        private const val RATE_BLOCKED_READ_NS = 20_000_000L
        private const val RATE_WINDOW_AFTER_READS = 8

    }

    private val appContext = context.applicationContext
    private val eventChannel = EventChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var recording = false
    private var record: AudioRecord? = null
    private var worker: Thread? = null
    private var delivery: PcmDelivery? = null
    private var aec: AcousticEchoCanceler? = null
    private var ns: NoiseSuppressor? = null
    private var agc: AutomaticGainControl? = null

    // Bluetooth capture routing we brought up and therefore owe a teardown:
    // the communication device on Android 12+, the SCO link below it.
    private var commDeviceSet = false
    private var scoStarted = false

    init {
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        if (sink == null || recording) return
        val args = arguments as? Map<*, *>
        val source = audioSource(args?.get("source") as? String)
        val wantAec = args?.get("aec") != false
        val wantAgc = args?.get("agc") == true
        val wantNs = args?.get("noiseSuppression") == true
        // A gain of 0 dB is the overwhelmingly common case, and a factor of
        // exactly 1 lets the read loop skip the sample walk entirely.
        val gain = gainFactor((args?.get("gainDb") as? Number)?.toDouble() ?: 0.0)
        val selector = args?.get("device") as? String
        inputSelector = selector
        val wantChannel = (args?.get("channel") as? Number)?.toInt() ?: 0
        val hardwareFormat = args?.get("format") == "hardware"
        // The mask must reach the chosen channel even when the device cannot
        // be resolved right now (it may still appear by open time), and must
        // cover the whole device when it can, so a 4-channel array does not
        // get opened 2-wide and remapped underneath the selection.
        val chans = if (wantChannel >= 1) {
            val reported = AudioRouting.resolve(selector, source = true)
                ?.channelCounts?.maxOrNull() ?: 0
            maxOf(2, wantChannel, reported)
        } else {
            1
        }
        // A channel pick is an index mask over the array's wire order; the
        // plain stereo open is positional, the shape every input profile
        // lists, so a HAL that matches by mask finds it.
        val indexed = wantChannel >= 1
        val ladder = captureLadder(hardwareFormat, chans, indexed)
        var step = 0
        var rec: AudioRecord? = null
        try {
            while (step < ladder.size) {
                rec = openRecord(source, ladder[step], indexed)
                if (rec != null) break
                Log.w(TAG, "${ladder[step]} capture refused" +
                    (if (step + 1 < ladder.size) "; trying ${ladder[step + 1]}" else ""))
                step++
            }
        } catch (e: SecurityException) {
            mainHandler.post { sink.error("permission", "RECORD_AUDIO not granted", null) }
            return
        }
        val opened = rec ?: run {
            mainHandler.post { sink.error("init", "AudioRecord init failed", null) }
            return
        }
        record = opened
        Log.i(
            TAG,
            "capture opening (device=${selector ?: "automatic"} " +
                "source=${sourceName(source)} gain=${"%.1f".format(gainDbOf(gain))}dB " +
                "aec=$wantAec agc=$wantAgc ns=$wantNs" +
                (if (wantChannel >= 1) " channel=$wantChannel/${ladder[step].channels}" else "") +
                " format=${ladder[step]}" +
                (if (hardwareFormat) " hardware-format" else "") + ")",
        )
        applyPreferredDevice(opened, selector)
        applyDsp(opened.audioSessionId, wantAec, wantAgc, wantNs)
        // Four 80 ms chunks cover ordinary scheduling jitter. A stalled
        // platform thread must not retain an unlimited history of audio.
        val frames = PcmDelivery(
            CHUNK_BYTES * 4, mainHandler::post, mainHandler::removeCallbacks,
        ) { sink.success(it) }
        delivery = frames
        recording = true
        opened.startRecording()
        CommunicationPlayback.get(appContext).captureStarted()
        val channelIdx = wantChannel - 1
        worker = thread(name = "vsww-mic") {
            var cur = opened
            val walk = CaptureWalk(ladder.size, step)
            var shape = ladder[walk.step]
            var decimator = if (shape.rateHz == HARDWARE_RATE) CaptureConvert.Decimator3() else null
            var announcedAudio = false
            // Rolling, not since-open: a capture can emit a startup
            // transient before going silent, so any single nonzero frame
            // must not disarm the watchdog for good. Both runs count 16 kHz
            // mono bytes whatever the shape.
            var zeroRun = 0L
            var errorRun = 0L
            // Delivered-rate check, once per open: frames read against the
            // wall clock. The window opens at the first read that blocked
            // (the backlog since startRecording has drained) or after a
            // few reads regardless (a stream arriving several times too
            // fast never blocks), so neither the open latency nor the
            // backlog counts.
            var windowNs = 0L
            var framesRead = 0L
            var reads = 0
            var rateChecked = false
            var buf = ByteArray(shape.chunkBytes)

            fun tryOpen(rung: Int): AudioRecord? = try {
                openRecord(source, ladder[rung], indexed)
            } catch (_: SecurityException) {
                null
            }

            fun swapTo(next: AudioRecord, rung: Int) {
                aec?.release()
                ns?.release()
                agc?.release()
                aec = null
                ns = null
                agc = null
                try { cur.stop() } catch (_: IllegalStateException) {}
                cur.release()
                applyPreferredDevice(next, selector)
                applyDsp(next.audioSessionId, wantAec, wantAgc, wantNs)
                next.startRecording()
                cur = next
                record = next
                walk.opened(rung)
                shape = ladder[rung]
                decimator = if (shape.rateHz == HARDWARE_RATE) CaptureConvert.Decimator3() else null
                zeroRun = 0
                errorRun = 0
                windowNs = 0
                framesRead = 0
                reads = 0
                rateChecked = false
                announcedAudio = false
                buf = ByteArray(shape.chunkBytes)
            }

            // The next rung of the ladder that opens. When the ladder is
            // exhausted, back to the rung that delivered audio (the first
            // rung when none did), with the next walk held off by the
            // backoff. False when no walk is allowed yet: the capture in
            // hand stays, whatever it is.
            fun advance(why: String): Boolean {
                if (!frames.isOpen) return false
                val now = System.nanoTime()
                if (!walk.mayWalk(now)) return false
                var next: AudioRecord? = null
                var rung = walk.step
                while (frames.isOpen && next == null && rung + 1 < ladder.size) {
                    rung++
                    next = tryOpen(rung)
                    if (next == null) Log.w(TAG, "$why; ${ladder[rung]} refused")
                }
                if (!frames.isOpen) {
                    next?.release()
                    return false
                }
                if (next == null) {
                    rung = walk.exhausted(now)
                    val wait = "next check in ${walk.waitSeconds}s"
                    next = tryOpen(rung)
                    if (next == null) {
                        Log.w(TAG, "$why and no other capture format is left; keeping $shape, $wait")
                        return true
                    }
                    Log.w(
                        TAG,
                        "$why and no other capture format is left; back to ${ladder[rung]}" +
                            (if (walk.audibleStep == rung) ", which delivered audio earlier" else "") +
                            ", $wait",
                    )
                } else {
                    Log.w(TAG, "$why - reopening at ${ladder[rung]}")
                }
                if (!frames.isOpen) {
                    next.release()
                    return false
                }
                swapTo(next, rung)
                return true
            }

            while (frames.isOpen) {
                val readStartNs = System.nanoTime()
                val read = cur.read(buf, 0, buf.size)
                if (!frames.isOpen) break
                if (read == 0) continue
                if (read < 0) {
                    // ERROR_DEAD_OBJECT and friends come back on every call:
                    // a track the server side gave up on. Pace the loop and
                    // let the watchdog treat the wait as silence.
                    if (!frames.isOpen) break
                    Thread.sleep(20)
                    errorRun += SAMPLE_RATE * 2 / 50
                    if (errorRun >= CaptureWalk.FRESH_ZERO_BYTES) {
                        errorRun = 0
                        advance("capture read only errors for 2s ($read)")
                    }
                    continue
                }
                errorRun = 0
                if (windowNs == 0L) {
                    reads++
                    val blocked = System.nanoTime() - readStartNs >= RATE_BLOCKED_READ_NS
                    if (blocked || reads >= RATE_WINDOW_AFTER_READS) windowNs = System.nanoTime()
                } else {
                    framesRead += read / (2 * shape.channels)
                }
                if (!rateChecked && windowNs != 0L) {
                    val elapsedNs = System.nanoTime() - windowNs
                    if (elapsedNs >= RATE_CHECK_NS) {
                        rateChecked = true
                        val ratio = framesRead * 1e9 / elapsedNs / shape.rateHz
                        Log.i(TAG, "capture delivers ${(ratio * 100).toInt()}% of ${shape.rateHz} Hz")
                        if (ratio < RATE_RATIO_MIN || ratio > RATE_RATIO_MAX) {
                            val why = "capture delivers ${(ratio * 100).toInt()}% of the " +
                                "${shape.rateHz} Hz it was opened at (wrong format under the label)"
                            if (!advance(why)) Log.w(TAG, "$why; keeping $shape until the next check")
                            continue
                        }
                    }
                }
                // Everything downstream - the watchdog included - listens to
                // the selected channel: the array's other channels carrying
                // audio is no consolation when the chosen one is dead.
                val mono = when {
                    shape.channels == 1 -> null
                    channelIdx >= 0 -> extractChannel(buf, read, shape.channels, channelIdx)
                    else -> CaptureConvert.downmix(buf, read, shape.channels)
                }
                val monoLen = mono?.size ?: read
                val silent = allZero(mono ?: buf, monoLen)
                if (silent && !CommunicationPlayback.maySuppressCapture()) {
                    zeroRun += monoLen * SAMPLE_RATE / shape.rateHz
                    val limit = walk.zeroLimitBytes
                    if (zeroRun >= limit) {
                        zeroRun = 0
                        // Held off (a trusted rung in a quiet room inside
                        // the backoff): nothing to say, silence is not news.
                        advance("capture read only zeros for ${limit / (SAMPLE_RATE * 2)}s")
                        continue
                    }
                } else {
                    zeroRun = 0
                    if (!silent) {
                        walk.audible()
                        if (walk.step > 0 && !announcedAudio) {
                            announcedAudio = true
                            Log.i(TAG, "$shape capture is delivering audio")
                        }
                    }
                }
                val chunk = when {
                    decimator != null -> decimator!!.process(mono ?: buf, monoLen)
                    mono != null -> mono
                    else -> buf.copyOf(read)
                }
                if (chunk.isEmpty()) continue
                if (gain != 1.0) amplify(chunk, chunk.size, gain)
                rtspAudioTap?.invoke(chunk, System.nanoTime() / 1000 - chunk.size * 1_000_000L / 32000)
                frames.offer(chunk)
            }
        }
    }

    /** A capture shape: rate and channel count, as a log-friendly string. */
    data class Shape(val rateHz: Int, val channels: Int) {
        /** 80 ms of interleaved PCM16 at this shape. */
        val chunkBytes: Int get() = CHUNK_BYTES * (rateHz / SAMPLE_RATE) * channels
        override fun toString() = "${rateHz}Hz x$channels"
    }

    /**
     * The shapes to try, in order. The engines' 16 kHz mono first, then
     * the sound card's 48 kHz stereo, then 48 kHz mono for a HAL that gets
     * stereo wrong; the hardware format starts at the card and keeps 16 kHz
     * mono as its last resort. A channel pick fixes the channel count (the
     * array's own), so only the rate varies, with the plain mono open as
     * the last rung for a device that cannot satisfy the pick (mic swapped
     * for a mono one, a ROM that refuses index masks): capture beats
     * silence.
     */
    private fun captureLadder(hardwareFormat: Boolean, chans: Int, indexed: Boolean): List<Shape> {
        val usual = Shape(SAMPLE_RATE, chans)
        val card = if (indexed) {
            listOf(Shape(HARDWARE_RATE, chans))
        } else {
            listOf(Shape(HARDWARE_RATE, HARDWARE_CHANNELS), Shape(HARDWARE_RATE, 1))
        }
        val ladder = if (hardwareFormat) card + usual else listOf(usual) + card
        return if (indexed) ladder + Shape(SAMPLE_RATE, 1) else ladder
    }

    /**
     * Open a capture at the given rate and channel count, or null when it
     * cannot be had. A channel pick opens with a channel index mask
     * (channels in wire order, no positional meaning) because that is what
     * USB arrays are: numbered outputs, not a left and a right. The plain
     * stereo open of the hardware format is positional, and wider opens
     * without a pick fall back to the index mask, the only mask there is
     * past two channels.
     */
    private fun openRecord(source: Int, shape: Shape, indexed: Boolean): AudioRecord? {
        val rateHz = shape.rateHz
        val channels = shape.channels
        val minBuf = AudioRecord.getMinBufferSize(
            rateHz,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        ) * channels
        val chunk = CHUNK_BYTES * (rateHz / SAMPLE_RATE) * channels
        val format = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(rateHz)
            .apply {
                if (channels == 2 && !indexed) {
                    setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
                } else if (channels > 1) {
                    setChannelIndexMask((1 shl channels) - 1)
                } else {
                    setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                }
            }
            .build()
        val rec = try {
            AudioRecord.Builder()
                .setAudioSource(source)
                .setAudioFormat(format)
                .setBufferSizeInBytes(max(minBuf, chunk * 4))
                .build()
        } catch (e: SecurityException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "AudioRecord open at $rateHz Hz x$channels failed: ${e.message}")
            return null
        }
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release()
            return null
        }
        return rec
    }

    /**
     * One channel of an interleaved PCM16 buffer as a fresh mono buffer.
     * [channelIdx] beyond the frame (stale selection, fallback-narrowed
     * capture) clamps to the last channel rather than reading past the frame.
     */
    private fun extractChannel(
        buf: ByteArray,
        length: Int,
        channels: Int,
        channelIdx: Int,
    ): ByteArray {
        val idx = channelIdx.coerceIn(0, channels - 1)
        val frames = length / 2 / channels
        val out = ByteArray(frames * 2)
        var si = idx * 2
        var oi = 0
        val stride = channels * 2
        repeat(frames) {
            out[oi] = buf[si]
            out[oi + 1] = buf[si + 1]
            si += stride
            oi += 2
        }
        return out
    }

    private fun allZero(buf: ByteArray, length: Int): Boolean {
        for (i in 0 until length) {
            if (buf[i] != 0.toByte()) return false
        }
        return true
    }

    /**
     * Multiply 16-bit little-endian samples in place, saturating at full
     * scale. Clipping rather than wrapping matters: a wrapped sample flips
     * sign and reads to a wake word model as an impulse, which is worse than
     * the flat top clipping gives.
     */
    private fun amplify(buf: ByteArray, length: Int, gain: Double) {
        var i = 0
        val end = length - 1
        while (i < end) {
            val sample = ((buf[i + 1].toInt() shl 8) or (buf[i].toInt() and 0xFF)).toShort()
            var scaled = (sample * gain).toInt()
            if (scaled > Short.MAX_VALUE.toInt()) scaled = Short.MAX_VALUE.toInt()
            if (scaled < Short.MIN_VALUE.toInt()) scaled = Short.MIN_VALUE.toInt()
            buf[i] = (scaled and 0xFF).toByte()
            buf[i + 1] = ((scaled shr 8) and 0xFF).toByte()
            i += 2
        }
    }

    /** Settings value to AudioSource, defaulting to the one we have always used. */
    private fun audioSource(name: String?): Int = when (name) {
        "mic" -> MediaRecorder.AudioSource.MIC
        "voice_recognition" -> MediaRecorder.AudioSource.VOICE_RECOGNITION
        else -> MediaRecorder.AudioSource.VOICE_COMMUNICATION
    }

    private fun sourceName(source: Int): String = when (source) {
        MediaRecorder.AudioSource.MIC -> "mic"
        MediaRecorder.AudioSource.VOICE_RECOGNITION -> "voice_recognition"
        else -> "voice_communication"
    }

    /**
     * Decibels to a linear factor, clamped to the range the settings slider
     * offers so a bad value from an import cannot blow the signal apart.
     * Negative values attenuate, for microphones that run too hot.
     */
    private fun gainFactor(db: Double): Double {
        if (db == 0.0) return 1.0
        return Math.pow(10.0, db.coerceIn(-24.0, 24.0) / 20.0)
    }

    private fun gainDbOf(factor: Double): Double =
        if (factor == 1.0) 0.0 else 20.0 * Math.log10(factor)

    /**
     * Pin capture to the user's chosen input, when one is configured and
     * currently present. A Bluetooth microphone additionally needs its call
     * audio link brought up - a plain setPreferredDevice quietly keeps
     * recording from the built-in mic without it. Absent or unmatched
     * selections fall through to Android's own routing.
     */
    private fun applyPreferredDevice(rec: AudioRecord, selector: String?) {
        if (selector.isNullOrBlank()) return
        val device = AudioRouting.resolve(selector, source = true)
        if (device == null) {
            // Absent device (BT speaker off) or a stale selector: Android
            // routes. Said out loud because silently-wrong capture routing is
            // exactly the complaint this feature answers.
            Log.w(TAG, "selected mic not matched ($selector); automatic routing")
            return
        }
        rec.preferredDevice = device
        Log.i(TAG, "capture pinned to ${device.productName} (type ${device.type}, ${device.address})")
        val bluetooth = device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
            (Build.VERSION.SDK_INT >= 31 && device.type == 26 /* TYPE_BLE_HEADSET */)
        if (!bluetooth) return
        val am = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= 31) {
            // setCommunicationDevice only accepts entries from
            // availableCommunicationDevices - the route handle, not the
            // input device we resolved. Passing the input is silently
            // refused (returns false) and capture stays on a dead SCO
            // input, which reads as a mic that hears nothing.
            val comm = am.availableCommunicationDevices.firstOrNull {
                it.type == device.type && it.address == device.address
            } ?: am.availableCommunicationDevices.firstOrNull { it.type == device.type }
            commDeviceSet = try {
                comm != null && am.setCommunicationDevice(comm)
            } catch (e: IllegalArgumentException) {
                Log.w(TAG, "setCommunicationDevice rejected: ${e.message}")
                false
            }
            if (!commDeviceSet) {
                Log.w(
                    TAG,
                    "bluetooth capture link refused (comm device " +
                        "${if (comm == null) "not offered" else "rejected"}); " +
                        "capture will likely be silent",
                )
            }
            AudioRouting.micHoldsCommDevice = commDeviceSet
        } else {
            @Suppress("DEPRECATION")
            am.startBluetoothSco()
            @Suppress("DEPRECATION")
            am.isBluetoothScoOn = true
            scoStarted = true
        }
        if (commDeviceSet || scoStarted) {
            Log.i(TAG, "bluetooth capture link up (${device.productName})")
        }
    }

    /**
     * Echo cancellation, noise suppression and AGC as configured, on this
     * capture session. The canceller is created even when off so the
     * platform's own default (on for a communication source) is overridden
     * rather than left to chance. Each effect is device-optional, so every step is best-effort:
     * a tablet without an AEC implementation still captures fine, it just does
     * not cancel. The resulting state is logged rather than assumed, since
     * "created the effect" and "the effect is actually running" are different
     * things on Android and vary by OEM.
     */
    private fun applyDsp(sessionId: Int, wantAec: Boolean, wantAgc: Boolean, wantNs: Boolean) {
        if (AcousticEchoCanceler.isAvailable()) {
            aec = try {
                AcousticEchoCanceler.create(sessionId)?.also { it.setEnabled(wantAec) }
            } catch (e: RuntimeException) {
                Log.w(TAG, "AEC unavailable on this session: ${e.message}")
                null
            }
        }
        // Explicitly set the effect state because VOICE_COMMUNICATION can
        // enable platform processing by default.
        if (NoiseSuppressor.isAvailable()) {
            ns = try {
                NoiseSuppressor.create(sessionId)?.also { it.setEnabled(wantNs) }
            } catch (e: RuntimeException) {
                Log.w(TAG, "NS control unavailable: ${e.message}")
                null
            }
        }
        // AGC is off unless the user asked for it: it pumps the level between
        // utterances, which is exactly what the wake models were not trained
        // on. It exists as a setting for devices whose capture is so quiet
        // that a shifting level beats an inaudible one.
        if (AutomaticGainControl.isAvailable()) {
            agc = try {
                AutomaticGainControl.create(sessionId)?.also { it.setEnabled(wantAgc) }
            } catch (e: RuntimeException) {
                Log.w(TAG, "AGC control unavailable: ${e.message}")
                null
            }
        }
        Log.i(
            TAG,
            "capture DSP: aec=${describe(aec?.enabled, AcousticEchoCanceler.isAvailable())} " +
                "ns=${describe(ns?.enabled, NoiseSuppressor.isAvailable())} " +
                "agc=${describe(agc?.enabled, AutomaticGainControl.isAvailable())}",
        )
    }

    private fun describe(enabled: Boolean?, available: Boolean): String = when {
        enabled == true -> "on"
        enabled == false -> "off"
        available -> "unsupported-on-session"
        else -> "unsupported-on-device"
    }

    override fun onCancel(arguments: Any?) {
        stop()
    }

    private fun stop() {
        delivery?.let {
            it.close()
            if (it.droppedChunks > 0) Log.w(TAG, "capture delivery dropped ${it.droppedChunks} stale chunks")
        }
        delivery = null
        recording = false
        worker?.let { try { it.join(500) } catch (_: InterruptedException) {} }
        worker = null
        // Effects first: they are attached to the session this AudioRecord owns.
        aec?.release()
        ns?.release()
        agc?.release()
        aec = null
        ns = null
        agc = null
        record?.let {
            try { it.stop() } catch (_: IllegalStateException) {}
            it.release()
        }
        record = null
        CommunicationPlayback.get(appContext).captureStopped()
        // Only tear down Bluetooth routing this recorder brought up; a stop
        // with automatic routing must not disturb whatever else holds it.
        if (commDeviceSet || scoStarted) {
            val am = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (commDeviceSet && Build.VERSION.SDK_INT >= 31) am.clearCommunicationDevice()
            if (scoStarted) {
                @Suppress("DEPRECATION")
                am.isBluetoothScoOn = false
                @Suppress("DEPRECATION")
                am.stopBluetoothSco()
            }
            commDeviceSet = false
            scoStarted = false
            AudioRouting.micHoldsCommDevice = false
        }
    }
}
