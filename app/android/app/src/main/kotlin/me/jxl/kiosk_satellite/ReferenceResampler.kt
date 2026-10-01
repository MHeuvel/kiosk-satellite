package me.jxl.kiosk_satellite

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Streaming conversion of playback PCM to the echo reference's sample rate.
 * A low-pass filter removes frequencies above the capture band before reducing
 * the rate. Otherwise those frequencies fold into speech that the microphone
 * never heard, so the canceller learns from a different signal.
 */
internal class ReferenceResampler(private val from: Int, private val to: Int) {
    init {
        require(from > 0 && to > 0)
    }

    private var position = 0.0
    private var last = 0f
    private val coefficients = if (from > to) {
        // Keep the transition width and delay similar across input rates.
        // At 48 kHz this is a 63-tap Hamming filter with a 7 kHz cutoff.
        val count = (21.0 * from / to).roundToInt().coerceAtLeast(3) or 1
        val middle = (count - 1) / 2
        val cutoff = .4375 * to / from
        val taps = DoubleArray(count) { i ->
            val k = i - middle
            val sinc = if (k == 0) 2 * cutoff else sin(2 * PI * cutoff * k) / (PI * k)
            sinc * (.54 - .46 * cos(2 * PI * i / (count - 1)))
        }
        val sum = taps.sum()
        FloatArray(count) { (taps[it] / sum).toFloat() }
    } else {
        floatArrayOf(1f)
    }
    private val history = FloatArray(coefficients.size)
    private var historyAt = 0

    fun reset() {
        position = 0.0
        last = 0f
        history.fill(0f)
        historyAt = 0
    }

    fun process(input: FloatArray): FloatArray {
        if (from == to) return input
        if (input.isEmpty()) return FloatArray(0)
        val filtered = if (from > to) lowPass(input) else input
        val step = from.toDouble() / to
        val out = FloatArray(((filtered.size - position) / step).toInt() + 2)
        var size = 0
        while (position < filtered.size - 1) {
            val i = floor(position).toInt()
            val fraction = (position - i).toFloat()
            val a = if (i < 0) last else filtered[i]
            out[size++] = a + (filtered[i + 1] - a) * fraction
            position += step
        }
        position -= filtered.size
        last = filtered.last()
        return out.copyOf(size)
    }

    private fun lowPass(input: FloatArray): FloatArray {
        val out = FloatArray(input.size)
        for (i in input.indices) {
            history[historyAt] = input[i]
            var at = historyAt
            var sum = 0f
            for (coefficient in coefficients) {
                sum += coefficient * history[at]
                if (--at < 0) at = history.lastIndex
            }
            out[i] = sum
            if (++historyAt == history.size) historyAt = 0
        }
        return out
    }
}
