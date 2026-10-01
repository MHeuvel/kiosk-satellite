package me.jxl.kiosk_satellite

import android.util.Log

/**
 * Echo cancellation in software: WebRTC's AEC3 (echo_jni.cpp) over the
 * microphone, with everything the kiosk plays ([EchoReference]) as the
 * reference. MicRecorder turns it on with the capture when the setting
 * asks for it, and hands every chunk to [process] on its thread before any
 * consumer sees it, so the wake word, Assist, realtime conversations, the
 * intercom and the RTSP stream all hear the cleaned microphone.
 *
 * It only works while something plays and for a short tail after: with
 * nothing in the reference there is no echo to take out, and the idle
 * microphone goes through untouched. The canceller itself stays loaded, so
 * what it learned about the room carries over to the next sound.
 */
object SoftwareEcho {
    private const val TAG = "SoftwareEcho"
    private const val RATE = EchoReference.RATE

    /** A frame, 10 ms of 16 kHz PCM16. */
    private const val FRAME = RATE / 100
    private const val FRAME_BYTES = FRAME * 2

    /** How long after the last sound the room can still echo it. */
    private const val TAIL_MS = 1500L

    /** Each source's recent history, longer than any capture chunk. */
    private const val HISTORY = RATE * 400 / 1000

    private val loaded: Boolean = try {
        System.loadLibrary("kiosk_echo")
        true
    } catch (e: Throwable) {
        Log.w(TAG, "native library unavailable: ${e.message}")
        false
    }

    private val lock = Object()
    private var handle = 0L
    private var working = false
    private var workingSinceNs = 0L

    /**
     * WebRTC's noise suppressor over every capture chunk, after the
     * canceller: a microphone's hiss is there whether or not anything
     * plays, and it carried straight into intercom calls on an Echo Show
     * 8. Its own module, so it runs while the canceller's rests.
     */
    private var nsHandle = 0L

    /** Whether the suppressor runs. */
    @Volatile var noiseSuppression = false
        private set

    fun setNoiseSuppression(on: Boolean) {
        synchronized(lock) {
            if (on == noiseSuppression) return
            if (on) {
                if (!loaded) return
                val created = nativeNsCreate(RATE)
                if (created == 0L) return
                nsHandle = created
                noiseSuppression = true
            } else {
                noiseSuppression = false
                nativeDestroy(nsHandle)
                nsHandle = 0L
            }
        }
    }

    /**
     * How far a chunk's place by the clock may stray from where the last
     * chunk ended and still follow on from it. A track's position comes in
     * mixer-sized steps a few milliseconds apart: jumping on each of them
     * would cut the reference into pieces the canceller cannot follow.
     */
    private const val SLACK = RATE * 10 / 1000

    /**
     * A source's recent samples, placed in time: [end] is one past the last
     * one the speaker had presented at [endNs]. A capture chunk reads the
     * samples the speaker was playing while it was being captured, by the
     * capture's own clock (MicRecorder's CaptureClock). Placing each chunk
     * by the clock rather than by when this code happens to run keeps the
     * reference the same distance from the microphone every time a sound
     * starts, so the canceller keeps what it learned instead of relearning
     * the delay for a second and a half at the start of every answer.
     */
    private class Stream {
        val samples = ShortArray(HISTORY)
        var length = 0
        var end = 0L
        var endNs = 0L
        var cursor = Long.MIN_VALUE
    }

    private val streams = HashMap<EchoReference.Source, Stream>()

    /**
     * The residual echo gate. AEC3 leaves a faint copy of the voice it
     * cancels, so a listener can still pick out speech under it, and a
     * realtime model takes that for the user talking over it. A frame where
     * something played, the microphone heard it and the canceller took most
     * of it away holds only echo, and goes as silence, as a phone's canceller
     * does. A frame the canceller left most of is someone talking over the
     * sound, and it and the [GATE_HANGOVER] frames after it go as they are.
     */
    private const val GATE_RATIO = 0.3

    /** Loudness (mean |sample|) under which there is no echo worth gating. */
    private const val GATE_FLOOR = 300

    /**
     * Loudness the gate never takes: speech at the kiosk reads in the
     * hundreds and up, what the canceller leaves of an echo well under
     * this. Against loud music the ratio alone asked for a voice at a third
     * of the music's own echo, and the wake word had to be shouted.
     */
    private const val GATE_CEILING = 200

    /** Frames that go ungated after one that held someone talking: 200 ms. */
    private const val GATE_HANGOVER = 20

    private var hangover = 0

    /**
     * Whether the gate runs: only while a realtime conversation plays
     * ([RealtimeAudio]), the one listener a faint echo misleads. The wake
     * word hears speech with the quiet parts of every word zeroed as a
     * word with holes in it, and over music it had to be shouted.
     */
    @Volatile var gated = false

    private val mix = ShortArray(FRAME)
    private val mixBytes = ByteArray(FRAME_BYTES)

    /** Whether the capture runs through the canceller. */
    @Volatile var enabled = false
        private set

    /** On or off with the capture's settings. */
    fun setEnabled(on: Boolean) {
        synchronized(lock) {
            if (on == enabled) return
            if (on) {
                if (!loaded) return
                val created = nativeCreate(RATE, RATE, false)
                if (created == 0L) return
                handle = created
                enabled = true
                Log.i(TAG, "on")
            } else {
                enabled = false
                stopWorking()
                nativeDestroy(handle)
                handle = 0L
                streams.clear()
                Log.i(TAG, "off")
            }
        }
    }

    /** One capture chunk of 16 kHz mono PCM16 whose last frame was heard at [heardNs], cleaned in place. */
    fun process(chunk: ByteArray, heardNs: Long) {
        if (!enabled && !noiseSuppression) return
        synchronized(lock) {
            cancel(chunk, heardNs)
            val ns = nsHandle
            if (ns != 0L) {
                var at = 0
                while (at + FRAME_BYTES <= chunk.size) {
                    nativeNsProcess(ns, chunk, at)
                    at += FRAME_BYTES
                }
            }
        }
    }

    /** The canceller's share of [process], under [lock]. */
    private fun cancel(chunk: ByteArray, heardNs: Long) {
        if (!enabled) return
        run {
            val h = handle
            if (h == 0L) return
            val sources = EchoReference.sources()
            var fresh = false
            for (source in sources) {
                val takenNs = System.nanoTime()
                source.take()?.let {
                    val stream = streams.getOrPut(source) { Stream() }
                    append(stream, it)
                    stream.endNs = takenNs
                    fresh = true
                }
            }
            if (streams.size > sources.size) streams.keys.retainAll(sources.toSet())
            if (!EchoReference.playedWithin(TAIL_MS) && !fresh) {
                stopWorking()
                return
            }
            if (!working) {
                working = true
                workingSinceNs = System.nanoTime()
            }
            val frames = chunk.size / FRAME_BYTES
            val need = frames * FRAME
            for (stream in streams.values) {
                // The sample the speaker was presenting as the chunk's last
                // frame was heard, and the chunk's worth before it.
                val heard = stream.end - (stream.endNs - heardNs) * RATE / 1_000_000_000L
                val start = heard - need
                if (stream.cursor == Long.MIN_VALUE || kotlin.math.abs(start - stream.cursor) > SLACK) {
                    stream.cursor = start
                }
            }
            var at = 0
            for (f in 0 until frames) {
                mixFrame(f)
                for (i in 0 until FRAME) {
                    val v = mix[i].toInt()
                    mixBytes[i * 2] = v.toByte()
                    mixBytes[i * 2 + 1] = (v shr 8).toByte()
                }
                val heard = meanAbs(chunk, at)
                val played = meanAbs(mixBytes, 0)
                nativeRender(h, mixBytes, 0)
                nativeCapture(h, chunk, at)
                gate(chunk, at, heard, played)
                at += FRAME_BYTES
            }
            for (stream in streams.values) stream.cursor += need
        }
    }

    /** Mean |sample| of the frame at [at]. */
    private fun meanAbs(pcm: ByteArray, at: Int): Int {
        var sum = 0
        for (i in 0 until FRAME) {
            val v = (pcm[at + i * 2].toInt() and 0xFF) or (pcm[at + i * 2 + 1].toInt() shl 8)
            sum += kotlin.math.abs(v.toShort().toInt())
        }
        return sum / FRAME
    }

    private fun gate(chunk: ByteArray, at: Int, heard: Int, played: Int) {
        if (hangover > 0) hangover--
        if (!gated || played < GATE_FLOOR / 3 || heard < GATE_FLOOR) return
        val left = meanAbs(chunk, at)
        if (left >= minOf(heard * GATE_RATIO, GATE_CEILING.toDouble())) {
            hangover = GATE_HANGOVER
            return
        }
        if (hangover == 0) java.util.Arrays.fill(chunk, at, at + FRAME_BYTES, 0)
    }

    /** Frame [f] of this chunk from every source, read at its cursor and summed into [mix]. */
    private fun mixFrame(f: Int) {
        java.util.Arrays.fill(mix, 0)
        for (stream in streams.values) {
            val first = stream.end - stream.length
            val from = stream.cursor + f * FRAME
            for (i in 0 until FRAME) {
                val at = from + i - first
                if (at < 0 || at >= stream.length) continue
                mix[i] = (mix[i] + stream.samples[at.toInt()]).coerceIn(-32768, 32767).toShort()
            }
        }
    }

    private fun append(stream: Stream, samples: ShortArray) {
        val buffer = stream.samples
        if (samples.size >= buffer.size) {
            System.arraycopy(samples, samples.size - buffer.size, buffer, 0, buffer.size)
            stream.length = buffer.size
        } else {
            val drop = maxOf(0, stream.length + samples.size - buffer.size)
            if (drop > 0) {
                System.arraycopy(buffer, drop, buffer, 0, stream.length - drop)
                stream.length -= drop
            }
            System.arraycopy(samples, 0, buffer, stream.length, samples.size)
            stream.length += samples.size
        }
        stream.end += samples.size
    }

    /**
     * Back to idle, and a line for the log: how long it worked and the echo
     * delay it found (the time from a sound playing to its echo in the
     * microphone, 110 to 130 ms on a Galaxy Tab S8).
     */
    private fun stopWorking() {
        if (!working) return
        working = false
        val h = handle
        if (h == 0L) return
        val delayMs = nativeStats(h)[1]
        val seconds = (System.nanoTime() - workingSinceNs) / 1_000_000_000.0
        Log.i(TAG, "cancelled for %.1f s, echo delay %s".format(
            seconds, if (delayMs.isNaN()) "not found" else "${delayMs.toInt()} ms",
        ))
    }

    @JvmStatic private external fun nativeCreate(captureRate: Int, renderRate: Int, noiseSuppression: Boolean): Long
    @JvmStatic private external fun nativeRender(handle: Long, pcm: ByteArray, offset: Int)
    @JvmStatic private external fun nativeCapture(handle: Long, pcm: ByteArray, offset: Int)
    @JvmStatic private external fun nativeStats(handle: Long): DoubleArray
    @JvmStatic private external fun nativeDestroy(handle: Long)
    @JvmStatic private external fun nativeNsCreate(rate: Int): Long
    @JvmStatic private external fun nativeNsProcess(handle: Long, pcm: ByteArray, offset: Int)
}
