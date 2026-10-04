package me.jxl.kiosk_satellite

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin
import kotlin.math.sqrt
import org.junit.Assert.*
import org.junit.Test

class ReferenceResamplerTest {
    private fun tone(rate: Int, frequency: Int) =
        FloatArray(rate) { sin(2 * PI * frequency * it / rate).toFloat() }

    private fun rms(samples: FloatArray): Double {
        val settled = samples.drop(100)
        return sqrt(settled.sumOf { it.toDouble() * it } / settled.size)
    }

    @Test fun rejectsPlaybackAboveTheMicrophoneBand() {
        for (rate in listOf(24000, 44100, 48000, 96000)) {
            val out = ReferenceResampler(rate, 16000).process(tone(rate, 10000))
            assertTrue("$rate Hz aliases 10 kHz into the reference", rms(out) < .007)
        }
    }

    @Test fun keepsSpeechAtItsOriginalLevel() {
        for (rate in listOf(24000, 44100, 48000, 96000)) {
            val out = ReferenceResampler(rate, 16000).process(tone(rate, 1000))
            assertEquals("$rate Hz speech level", 1 / sqrt(2.0), rms(out), .015)
            assertTrue(abs(out.size - 16000) <= 1)
        }
    }

    @Test fun arbitraryChunkBoundariesMatchOneContinuousStream() {
        val input = tone(44100, 1379)
        val expected = ReferenceResampler(44100, 16000).process(input)
        val converter = ReferenceResampler(44100, 16000)
        val actual = ArrayList<Float>()
        var at = 0
        val sizes = intArrayOf(1, 37, 255, 480, 3, 997)
        var chunk = 0
        while (at < input.size) {
            val end = minOf(input.size, at + sizes[chunk++ % sizes.size])
            actual.addAll(converter.process(input.copyOfRange(at, end)).asList())
            assertTrue(converter.process(FloatArray(0)).isEmpty())
            at = end
        }
        assertArrayEquals(expected, actual.toFloatArray(), .00001f)
        converter.reset()
        assertArrayEquals(expected, converter.process(input), .00001f)
    }

    @Test fun nativeRatePassesThroughWithoutDelayOrFiltering() {
        val input = tone(16000, 7000)
        assertSame(input, ReferenceResampler(16000, 16000).process(input))
    }
}
