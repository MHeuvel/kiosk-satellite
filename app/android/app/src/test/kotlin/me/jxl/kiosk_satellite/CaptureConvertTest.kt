package me.jxl.kiosk_satellite

import kotlin.math.PI
import kotlin.math.sin
import kotlin.math.sqrt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CaptureConvertTest {
    private fun pcm(samples: IntArray): ByteArray {
        val out = ByteArray(samples.size * 2)
        samples.forEachIndexed { i, v ->
            out[i * 2] = (v and 0xFF).toByte()
            out[i * 2 + 1] = ((v shr 8) and 0xFF).toByte()
        }
        return out
    }

    private fun samples(buf: ByteArray): IntArray = IntArray(buf.size / 2) { i ->
        ((buf[i * 2 + 1].toInt() shl 8) or (buf[i * 2].toInt() and 0xFF)).toShort().toInt()
    }

    private fun tone(hz: Double, rate: Int, seconds: Double, amp: Int): IntArray =
        IntArray((rate * seconds).toInt()) { (amp * sin(2 * PI * hz * it / rate)).toInt() }

    private fun rms(s: IntArray, from: Int): Double {
        var acc = 0.0
        for (i in from until s.size) acc += s[i].toDouble() * s[i]
        return sqrt(acc / (s.size - from))
    }

    private fun zeroCrossings(s: IntArray, from: Int): Int {
        var n = 0
        for (i in from + 1 until s.size) if ((s[i - 1] < 0) != (s[i] < 0)) n++
        return n
    }

    @Test fun downmixAveragesInterleavedChannels() {
        val stereo = pcm(intArrayOf(1000, 3000, -2000, -4000, 32767, 32767, 7, 8))
        assertEquals(listOf(2000, -3000, 32767, 7), samples(CaptureConvert.downmix(stereo, stereo.size, 2)).toList())
        val quad = pcm(intArrayOf(4, 8, 12, 16))
        assertEquals(listOf(10), samples(CaptureConvert.downmix(quad, quad.size, 4)).toList())
    }

    @Test fun speechBandToneComesThroughAtOneThirdTheRate() {
        val input = tone(1000.0, 48000, 0.5, 10000)
        val out = samples(CaptureConvert.Decimator3().process(pcm(input), input.size * 2))
        assertEquals(input.size / 3, out.size)
        val expected = 10000 / sqrt(2.0)
        assertEquals(expected, rms(out, 200), expected * 0.03)
        // 1 kHz over the last 0.4 s at 16 kHz is 800 zero crossings.
        val crossings = zeroCrossings(out, 1600)
        assertTrue("zero crossings $crossings", crossings in 796..804)
    }

    @Test fun contentAboveTheNewNyquistIsRejected() {
        val input = tone(15000.0, 48000, 0.5, 10000)
        val out = samples(CaptureConvert.Decimator3().process(pcm(input), input.size * 2))
        // Better than -40 dB: a boxcar would leave this at about -10 dB.
        assertTrue("aliased rms ${rms(out, 200)}", rms(out, 200) < 10000 / sqrt(2.0) / 100)
    }

    @Test fun chunkBoundariesAndOddReadsCarryOver() {
        val input = tone(1000.0, 48000, 0.5, 10000)
        val whole = samples(CaptureConvert.Decimator3().process(pcm(input), input.size * 2))
        val d = CaptureConvert.Decimator3()
        val pieces = ArrayList<Int>()
        var at = 0
        var size = 1
        while (at < input.size) {
            val end = minOf(input.size, at + size)
            pieces += samples(d.process(pcm(input.copyOfRange(at, end)), (end - at) * 2)).toList()
            at = end
            size = size % 7 + 1 // 1..7 samples, so most reads are not a multiple of three
        }
        assertEquals(whole.toList(), pieces)
    }

    @Test fun upsampledSixteenKilohertzAudioSurvivesTheRoundTrip() {
        // The deafness fallback on a 16 kHz device: AudioFlinger's 3x
        // upsample, approximated by sample repetition, then our decimation.
        val original = tone(1500.0, 16000, 0.5, 8000)
        val held = IntArray(original.size * 3) { original[it / 3] }
        val out = samples(CaptureConvert.Decimator3().process(pcm(held), held.size * 2))
        val expected = 8000 / sqrt(2.0)
        assertEquals(expected, rms(out, 200), expected * 0.05)
    }

    @Test fun fullScaleInputDoesNotWrap() {
        val input = IntArray(4800) { if (it % 2 == 0) 32767 else -32768 }
        val out = samples(CaptureConvert.Decimator3().process(pcm(input), input.size * 2))
        assertTrue(out.all { it in -32768..32767 })
        val dc = IntArray(4800) { 32767 }
        val flat = samples(CaptureConvert.Decimator3().process(pcm(dc), dc.size * 2))
        assertEquals(32767.0, flat.drop(100).average(), 2.0)
    }
}
