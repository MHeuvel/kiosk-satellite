package me.jxl.kiosk_satellite

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * PCM16 conversion for a capture opened at the sound card's own format
 * rather than the 16 kHz mono the wake word engines, the stop word, speech
 * to text and the RTSP tap all consume.
 *
 * Some sound cards record at 48 kHz stereo and nothing else (an I2S codec
 * on a Raspberry Pi, most USB interfaces), and an audio HAL that hands the
 * app's requested format straight to ALSA either refuses the 16 kHz mono
 * open or delivers the card's frames misread as 16 kHz mono, which sounds
 * like crackle. Opening at the card's format and converting here sidesteps
 * both, so the conversion has to be good enough for a genuinely 48 kHz
 * microphone: a proper low-pass ahead of the 3:1 decimation, not a boxcar,
 * or everything the mic hears above 8 kHz folds into the speech band.
 */
object CaptureConvert {
    /** Interleaved PCM16 of [channels] to mono by averaging every channel. */
    fun downmix(buf: ByteArray, length: Int, channels: Int): ByteArray {
        val frames = length / 2 / channels
        val out = ByteArray(frames * 2)
        var si = 0
        var oi = 0
        repeat(frames) {
            var acc = 0
            repeat(channels) {
                acc += ((buf[si + 1].toInt() shl 8) or (buf[si].toInt() and 0xFF)).toShort().toInt()
                si += 2
            }
            val v = acc / channels
            out[oi] = (v and 0xFF).toByte()
            out[oi + 1] = ((v shr 8) and 0xFF).toByte()
            oi += 2
        }
        return out
    }

    /**
     * 48 kHz mono PCM16 to 16 kHz: a windowed-sinc low-pass at 7 kHz, then
     * every third sample. Stateful, so chunk boundaries and reads that are
     * not a multiple of three samples carry over instead of dropping
     * samples. One instance per capture.
     *
     * 63 taps with a Hamming window puts the stopband (about -50 dB) from
     * 8.3 kHz up, so what aliases into the top of the speech band is a
     * narrow sliver just above 8 kHz. Q15 integer taps: the Echo Show
     * class of device runs this on every microphone frame.
     */
    class Decimator3 {
        private val ring = IntArray(RING)
        private var pos = 0
        private var phase = 0

        fun process(buf: ByteArray, length: Int): ByteArray {
            val n = length / 2
            val out = ByteArray((phase + n) / 3 * 2)
            var si = 0
            var oi = 0
            repeat(n) {
                ring[pos] = ((buf[si + 1].toInt() shl 8) or (buf[si].toInt() and 0xFF)).toShort().toInt()
                si += 2
                pos = (pos + 1) and (RING - 1)
                if (++phase == 3) {
                    phase = 0
                    var acc = 0L
                    var p = (pos - 1) and (RING - 1)
                    for (k in 0 until TAPS.size) {
                        acc += TAPS[k].toLong() * ring[p]
                        p = (p - 1) and (RING - 1)
                    }
                    var v = ((acc + (1L shl 14)) shr 15).toInt()
                    if (v > Short.MAX_VALUE) v = Short.MAX_VALUE.toInt()
                    if (v < Short.MIN_VALUE) v = Short.MIN_VALUE.toInt()
                    out[oi] = (v and 0xFF).toByte()
                    out[oi + 1] = ((v shr 8) and 0xFF).toByte()
                    oi += 2
                }
            }
            return out
        }

        companion object {
            private const val N = 63
            private const val RING = 64
            private const val CUTOFF_HZ = 7000.0
            private const val INPUT_HZ = 48000.0

            /** Hamming-windowed sinc, unity DC gain, in Q15. */
            val TAPS: IntArray = run {
                val wc = 2 * PI * CUTOFF_HZ / INPUT_HZ
                val m = (N - 1) / 2
                val h = DoubleArray(N) { i ->
                    val k = i - m
                    val sinc = if (k == 0) wc / PI else sin(wc * k) / (PI * k)
                    sinc * (0.54 - 0.46 * cos(2 * PI * i / (N - 1)))
                }
                val sum = h.sum()
                IntArray(N) { (h[it] / sum * 32768).roundToInt() }
            }
        }
    }
}
