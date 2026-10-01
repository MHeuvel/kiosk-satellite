package me.jxl.kiosk_satellite

import android.media.AudioTimestamp
import android.media.AudioTrack
import android.os.SystemClock
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CopyOnWriteArrayList

/**
 * What the kiosk is playing, for [SoftwareEcho]: every player that writes
 * its own PCM taps it here, and the canceller takes the mix of what each
 * one's speaker has presented since it last asked. Everything is kept as
 * 16 kHz mono, the rate the microphone runs at.
 *
 * Players Android decodes on its own (the dashboard's web pages, the DLNA
 * video player, alarms) cannot be tapped, so their sound is not cancelled.
 */
object EchoReference {
    const val RATE = 16000

    /** A player's contribution: its presented voice since the last call. */
    interface Source {
        /** 16 kHz mono samples presented since the last call, volume applied. */
        fun take(): ShortArray?
    }

    private val sources = CopyOnWriteArrayList<Source>()

    /** When a source last had something playing, for the canceller's tail. */
    @Volatile private var lastAudibleMs = 0L

    fun add(source: Source) {
        sources.addIfAbsent(source)
    }

    fun remove(source: Source) {
        sources.remove(source)
    }

    fun sources(): List<Source> = sources

    fun audible() {
        lastAudibleMs = SystemClock.elapsedRealtime()
    }

    /** Whether anything played recently enough to still be echoing. */
    fun playedWithin(ms: Long): Boolean =
        SystemClock.elapsedRealtime() - lastAudibleMs < ms
}

/**
 * The part of a tap both kinds share: 16 kHz mono samples queued as the
 * player writes them, handed to the canceller once the speaker has
 * presented them. Positions count 16 kHz samples from the start of the
 * stream, derived from absolute frame counts so rounding never adds up.
 */
abstract class PresentedQueue(rate: Int) : EchoReference.Source {
    protected val lock = Object()

    /** The source's sample rate. Under [lock] once it plays. */
    protected var rate = rate
        private set
    private var resampler = LinearResampler(rate, EchoReference.RATE)

    /**
     * The volume the player applies after the tap. It is applied here as the
     * samples are handed out, not as they are written: Android changes a
     * track's volume for what it plays from then on, while a player writes
     * a quarter of a second ahead, so a music duck applied at write time
     * reached the reference that much before the speaker, at the start of
     * every answer.
     */
    @Volatile var gain = 1f

    private var queued = ShortArray(EchoReference.RATE)
    private var queuedLength = 0

    /** The 16 kHz position of queued[0]. */
    private var queuedFrom = 0L

    /** Source frames written since the stream (re)started. */
    protected var written = 0L

    /**
     * Source frames the speaker has presented since the stream (re)started.
     * Called outside [lock]: a player's own clock may take its own lock,
     * which the player also holds while it writes here.
     */
    protected abstract fun presented(): Long

    /** Queue [frames] frames of PCM from [view], at its position. */
    protected fun queue(view: ByteBuffer, frames: Int, channels: Int, bytesPerSample: Int) {
        if (frames <= 0) return
        if (!SoftwareEcho.enabled) {
            // Nothing listens: count the frames, keep nothing.
            synchronized(lock) {
                written += frames
                queuedLength = 0
                queuedFrom = written * EchoReference.RATE / rate
                resampler.reset()
            }
            return
        }
        val mono = FloatArray(frames)
        var at = view.position()
        for (i in 0 until frames) {
            var sum = 0f
            for (c in 0 until channels) {
                sum += if (bytesPerSample == 4) {
                    view.getInt(at) / 2147483648f
                } else {
                    view.getShort(at) / 32768f
                }
                at += bytesPerSample
            }
            mono[i] = sum / channels
        }
        val out = resampler.process(mono)
        synchronized(lock) {
            if (queuedLength == 0) queuedFrom = written * EchoReference.RATE / rate
            if (queuedLength + out.size > queued.size) {
                queued = queued.copyOf(maxOf(queued.size * 2, queuedLength + out.size))
            }
            for (i in out.indices) {
                queued[queuedLength + i] = (out[i].coerceIn(-1f, 1f) * 32767f).toInt().toShort()
            }
            queuedLength += out.size
            written += frames
        }
        if (gain > 0f) EchoReference.audible()
    }

    /** Start over: nothing queued, nothing written, at [newRate]. */
    protected fun restart(newRate: Int = rate) {
        synchronized(lock) {
            queuedLength = 0
            queuedFrom = 0
            written = 0
            if (newRate != rate) {
                rate = newRate
                resampler = LinearResampler(newRate, EchoReference.RATE)
            } else {
                resampler.reset()
            }
        }
    }

    override fun take(): ShortArray? {
        val presented = presented()
        return synchronized(lock) { taken(presented) }
    }

    private fun taken(presented: Long): ShortArray? {
        if (queuedLength == 0) return null
        val presented16 = presented * EchoReference.RATE / rate
        val upto = (presented16 - queuedFrom).coerceIn(0L, queuedLength.toLong()).toInt()
        if (upto == 0) return null
        val out = queued.copyOf(upto)
        val g = gain
        if (g != 1f) for (i in out.indices) out[i] = (out[i] * g).toInt().toShort()
        System.arraycopy(queued, upto, queued, 0, queuedLength - upto)
        queuedLength -= upto
        queuedFrom += upto
        return out
    }
}

/**
 * One AudioTrack's tap into [EchoReference]. The player hands over what it
 * writes ([wrote]) and says when it drops what is queued ([flushed]).
 *
 * What the speaker has presented comes from the track's timestamp while it
 * is fresh and agrees with the playback head, and otherwise from the head
 * minus the latency those timestamps last measured. A timestamp alone is not
 * enough: on a Galaxy Tab S8 it goes wrong the moment a second stream starts,
 * and a reference late by a quarter of a second cancels nothing. A player
 * with its own validated clock (Sendspin) passes it as [clock] instead.
 */
class TrackTap(
    private val track: AudioTrack,
    rate: Int,
    private val channels: Int,
    private val bytesPerSample: Int = 2,
    private val clock: (() -> Long)? = null,
) : PresentedQueue(rate) {
    private val timestamp = AudioTimestamp()
    private val headClock = me.jxl.kiosk_satellite.sendspin.PlaybackClock()
    private val headLock = Object()
    private var headBase = 0L

    /**
     * The latency the track's timestamps last measured, kept across flushes:
     * a talked-over answer flushes the track, and Android's own estimate
     * (109 ms against a measured 85 on a Galaxy Tab S8) put the next
     * answer's reference out of step with its echo just as it started.
     */
    private var measuredLatencyUs = measuredByRate[rate] ?: -1L

    private companion object {
        /** The last measured latency per sample rate, for the next track at that rate. */
        val measuredByRate = java.util.concurrent.ConcurrentHashMap<Int, Long>()

        /** How old a timestamp may be and still place the speaker. */
        const val FRESH_NS = 500_000_000L
    }

    private val bufferFrames = runCatching { track.bufferSizeInFrames.toLong() }.getOrDefault(0L)

    init {
        resetClock()
        EchoReference.add(this)
    }

    fun close() {
        EchoReference.remove(this)
    }

    fun wrote(bytes: ByteArray, offset: Int, length: Int) {
        wrote(ByteBuffer.wrap(bytes, offset, length), length)
    }

    /** [length] bytes of PCM from [buffer]'s position, left where it was. */
    fun wrote(buffer: ByteBuffer, length: Int) {
        val view = buffer.duplicate().order(ByteOrder.LITTLE_ENDIAN)
        queue(view, length / (channels * bytesPerSample), channels, bytesPerSample)
    }

    /** The track dropped what it had not played: start over from its head. */
    fun flushed() {
        restart()
        resetClock()
    }

    private fun resetClock() {
        synchronized(headLock) {
            headBase = head()
            headClock.reset()
        }
    }

    private fun latencyUs(): Long =
        if (measuredLatencyUs >= 0) measuredLatencyUs else estimatedLatencyUs()

    private fun head(): Long =
        runCatching { track.playbackHeadPosition.toLong() and 0xFFFFFFFFL }.getOrDefault(0L)

    /** Android's own figure for the track's latency past its buffer, when it gives one. */
    private fun estimatedLatencyUs(): Long {
        val bufferUs = bufferFrames * 1_000_000L / rate
        return runCatching {
            val total = (AudioTrack::class.java.getMethod("getLatency").invoke(track) as Int) * 1000L
            (total - bufferUs).coerceIn(0L, 1_000_000L)
        }.getOrDefault(0L)
    }

    override fun presented(): Long {
        clock?.let { return it() }
        val written = synchronized(lock) { written }
        return synchronized(headLock) {
            val now = System.nanoTime()
            val head = headClock.position(head() - headBase, now, written, rate, bufferFrames)
            // A timestamp is taken whenever it is fresh and agrees with the
            // head: a stream fed in bursts (the realtime voice) stops its
            // timestamps between them, and the head alone moves in mixer
            // steps a few milliseconds apart, which on speech costs the
            // canceller half of what it takes out.
            val ok = runCatching { track.getTimestamp(timestamp) }.getOrDefault(false)
            if (ok && now - timestamp.nanoTime in 0..FRESH_NS) {
                val at = (timestamp.framePosition and 0xFFFFFFFFL) - headBase +
                    (now - timestamp.nanoTime) * rate / 1_000_000_000L
                if (at in 0..head && head - at < rate / 4) {
                    val lagUs = (head - at) * 1_000_000L / rate
                    measuredLatencyUs = if (measuredLatencyUs < 0) lagUs else (measuredLatencyUs * 7 + lagUs) / 8
                    measuredByRate[rate] = measuredLatencyUs
                    return@synchronized at.coerceAtMost(written)
                }
            }
            (head - latencyUs() * rate / 1_000_000L).coerceIn(0L, written)
        }
    }
}

/**
 * A Media3 player's tap into [EchoReference]: the PCM its audio processors
 * see ([TeeAudioProcessor]), timed by the sink's own playback position, which
 * the player's sink reports through [position] as it plays. [started] gives
 * the first buffer's presentation time, the zero of that clock.
 */
class SinkTap : PresentedQueue(48000), androidx.media3.exoplayer.audio.TeeAudioProcessor.AudioBufferSink {
    private var channels = 2
    private var pcm16 = true
    private var startUs = Long.MIN_VALUE
    private var positionUs = Long.MIN_VALUE
    private var positionAtNs = 0L

    init {
        EchoReference.add(this)
    }

    fun close() {
        EchoReference.remove(this)
    }

    override fun flush(sampleRate: Int, channelCount: Int, encoding: Int) {
        restart(sampleRate)
        synchronized(lock) {
            channels = channelCount
            pcm16 = encoding == androidx.media3.common.C.ENCODING_PCM_16BIT
            startUs = Long.MIN_VALUE
            positionUs = Long.MIN_VALUE
        }
    }

    override fun handleBuffer(buffer: ByteBuffer) {
        if (!pcm16) return
        val view = buffer.duplicate().order(ByteOrder.LITTLE_ENDIAN)
        queue(view, buffer.remaining() / (channels * 2), channels, 2)
    }

    /** The first buffer's presentation time, in the sink's clock. */
    fun started(presentationTimeUs: Long) {
        synchronized(lock) { if (startUs == Long.MIN_VALUE) startUs = presentationTimeUs }
    }

    /** The sink's playback position as the player reads it. */
    fun position(positionUs: Long) {
        synchronized(lock) {
            this.positionUs = positionUs
            positionAtNs = System.nanoTime()
        }
    }

    override fun presented(): Long = synchronized(lock) {
        if (startUs == Long.MIN_VALUE || positionUs == Long.MIN_VALUE) return 0L
        val nowUs = positionUs + (System.nanoTime() - positionAtNs) / 1000
        ((nowUs - startUs) * rate / 1_000_000L).coerceIn(0L, written)
    }
}

/**
 * A Media3 audio sink that times [tap] by the sink's own clock: its first
 * buffer's time and its position as it plays. The tap's PCM comes from a
 * [androidx.media3.exoplayer.audio.TeeAudioProcessor] in the sink's chain.
 */
open class TappedAudioSink(
    sink: androidx.media3.exoplayer.audio.AudioSink,
    private val tap: SinkTap,
) : androidx.media3.exoplayer.audio.ForwardingAudioSink(sink) {
    override fun handleBuffer(
        buffer: ByteBuffer,
        presentationTimeUs: Long,
        encodedAccessUnitCount: Int,
    ): Boolean {
        tap.started(presentationTimeUs)
        return super.handleBuffer(buffer, presentationTimeUs, encodedAccessUnitCount)
    }

    override fun getCurrentPositionUs(sourceEnded: Boolean): Long {
        val position = super.getCurrentPositionUs(sourceEnded)
        if (position != androidx.media3.exoplayer.audio.AudioSink.CURRENT_POSITION_NOT_SET) tap.position(position)
        return position
    }
}

/** Renderers for a Media3 player whose audio also goes to [tap]. */
fun tappedRenderers(context: android.content.Context, tap: SinkTap) =
    object : androidx.media3.exoplayer.DefaultRenderersFactory(context) {
        override fun buildAudioSink(
            context: android.content.Context,
            enableFloatOutput: Boolean,
            enableAudioTrackPlaybackParams: Boolean,
        ): androidx.media3.exoplayer.audio.AudioSink = TappedAudioSink(
            androidx.media3.exoplayer.audio.DefaultAudioSink.Builder(context)
                .setAudioProcessors(arrayOf(androidx.media3.exoplayer.audio.TeeAudioProcessor(tap)))
                .build(),
            tap,
        )
    }.setEnableDecoderFallback(true)

/**
 * Linear resampling of a mono stream, carried across calls. Going down, a
 * short moving average first keeps what lies above the new rate's range
 * from folding back into it: the microphone never hears it there.
 */
class LinearResampler(private val from: Int, private val to: Int) {
    private var position = 0.0
    private var last = 0f
    private val taps = if (from > to) Math.round(from.toFloat() / to).coerceAtLeast(1) else 1
    private val history = FloatArray(taps)
    private var historyAt = 0
    private var historySum = 0f

    fun reset() {
        position = 0.0
        last = 0f
        history.fill(0f)
        historyAt = 0
        historySum = 0f
    }

    fun process(input: FloatArray): FloatArray {
        if (from == to) return input
        val x = if (taps > 1) smooth(input) else input
        val step = from.toDouble() / to
        val out = FloatArray(((x.size - position) / step).toInt() + 2)
        var n = 0
        // position runs over [-1, x.size): -1 is the previous call's last
        // sample.
        while (position < x.size - 1) {
            val i = kotlin.math.floor(position).toInt()
            val frac = (position - i).toFloat()
            val a = if (i < 0) last else x[i]
            val b = x[i + 1]
            out[n++] = a + (b - a) * frac
            position += step
        }
        position -= x.size
        if (x.isNotEmpty()) last = x[x.size - 1]
        return out.copyOf(n)
    }

    private fun smooth(input: FloatArray): FloatArray {
        val out = FloatArray(input.size)
        for (i in input.indices) {
            historySum += input[i] - history[historyAt]
            history[historyAt] = input[i]
            historyAt = (historyAt + 1) % taps
            out[i] = historySum / taps
        }
        return out
    }
}
