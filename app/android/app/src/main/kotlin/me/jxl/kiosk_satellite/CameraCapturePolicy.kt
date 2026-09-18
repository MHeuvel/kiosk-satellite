package me.jxl.kiosk_satellite

import kotlin.math.abs

/** Overlay changes can reuse both the encoder and connected viewers. */
internal fun sameRtspVideoConfiguration(previous: Map<*, *>, next: Map<*, *>): Boolean =
    previous.filterKeys { it != "dateTime" && it != "dateTimeBackground" } ==
        next.filterKeys { it != "dateTime" && it != "dateTimeBackground" }

/** Video changes need new parameter sets but keep the same listening endpoint. */
internal fun sameRtspEndpoint(previous: Map<*, *>, next: Map<*, *>): Boolean {
    val videoKeys = setOf("width", "height", "fps", "bitrate", "camera", "analysis", "dateTime", "dateTimeBackground")
    return previous.filterKeys { it !in videoKeys } == next.filterKeys { it !in videoKeys }
}

/** Select an advertised sensor range, never a fabricated fixed frame rate. */
internal fun streamingFpsRange(ranges: List<IntRange>, target: Int): IntRange? =
    ranges.minWithOrNull(compareBy<IntRange>(
        { if (target in it) 0 else 1 },
        { abs(it.last - target) },
        { abs(it.first - target) },
    ))

/** Remember a working fallback across viewer reconnects for each camera. */
internal class CameraCapturePolicy {
    private val levels = mutableMapOf<String, Int>()
    fun reset() { levels.clear() }
    fun level(camera: String): Int = levels[camera] ?: 0
    fun advance(camera: String): Boolean {
        val current = level(camera)
        if (current >= 3) return false
        levels[camera] = current + 1
        return true
    }
}
