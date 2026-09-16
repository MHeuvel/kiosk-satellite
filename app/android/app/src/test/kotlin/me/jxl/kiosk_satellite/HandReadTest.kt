package me.jxl.kiosk_satellite

import kotlin.math.cos
import kotlin.math.sin
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The finger count behind the Show fingers gesture, on hand shaped
 * landmark sets: a right hand, palm to the camera, fingers up, in square
 * units. A finger is up when its tip sits above its knuckles and curled
 * when the tip folds back toward the wrist. The thumb is spread out
 * beside the palm or tucked across it.
 */
class HandReadTest {
    private fun hand(
        up: List<Boolean>,
        thumbTucked: Boolean,
    ): Array<Pair<Float, Float>> {
        val p = Array(21) { 0f to 0f }
        p[0] = 0.50f to 0.90f // wrist
        p[9] = 0.50f to 0.60f // middle knuckle: palm = 0.3
        val fingers = listOf(intArrayOf(5, 6, 7, 8), intArrayOf(9, 10, 11, 12), intArrayOf(13, 14, 15, 16), intArrayOf(17, 18, 19, 20))
        val xs = listOf(0.40f, 0.50f, 0.60f, 0.70f)
        for ((i, f) in fingers.withIndex()) {
            val x = xs[i]
            p[f[0]] = x to 0.60f
            if (up[i]) {
                p[f[1]] = x to 0.48f
                p[f[2]] = x to 0.40f
                p[f[3]] = x to 0.32f
            } else {
                p[f[1]] = x to 0.52f
                p[f[2]] = x to 0.62f
                p[f[3]] = x to 0.72f
            }
        }
        // Thumb: MCP low on the index side, then out beside the palm or
        // folded across it toward the pinky.
        p[1] = 0.36f to 0.85f
        p[2] = 0.32f to 0.78f
        if (thumbTucked) {
            p[3] = 0.40f to 0.72f
            p[4] = 0.50f to 0.70f
        } else {
            p[3] = 0.24f to 0.70f
            p[4] = 0.16f to 0.62f
        }
        return p
    }

    private fun read(p: Array<Pair<Float, Float>>) = readHand({ p[it].first }, { p[it].second })

    private val allUp = listOf(true, true, true, true)

    @Test
    fun anOpenHandReadsFive() {
        val r = read(hand(allUp, thumbTucked = false))
        assertEquals(5, r.fingers, r.detail)
        assertEquals(listOf(true, true, true, true, true), r.up)
        assertTrue(r.detail.endsWith("(counted)"), r.detail)
    }

    @Test
    fun fourFingersWithTheThumbTuckedReadFour() {
        val r = read(hand(allUp, thumbTucked = true))
        assertEquals(4, r.fingers, r.detail)
        assertEquals(listOf(false, true, true, true, true), r.up)
        assertTrue(r.detail.endsWith("(not counted)"), r.detail)
    }

    @Test
    fun aSpreadThumbNeverAddsToFewerThanFourFingers() {
        assertEquals(0, read(hand(listOf(false, false, false, false), thumbTucked = false)).fingers, "thumb up")
        assertEquals(1, read(hand(listOf(true, false, false, false), thumbTucked = false)).fingers, "pointing")
        val victory = read(hand(listOf(true, true, false, false), thumbTucked = false))
        assertEquals(2, victory.fingers, "victory, thumb resting out")
        assertEquals(listOf(false, true, true, false, false), victory.up, "the resting thumb is not up")
        assertEquals(3, read(hand(listOf(true, true, true, false), thumbTucked = false)).fingers, "three, thumb resting out")
    }

    @Test
    fun aFistReadsZero() {
        assertEquals(0, read(hand(listOf(false, false, false, false), thumbTucked = true)).fingers)
    }

    @Test
    fun theCountSurvivesRotationAndMirroring() {
        for (deg in listOf(90f, 180f, -45f)) {
            val a = Math.toRadians(deg.toDouble())
            fun turn(p: Array<Pair<Float, Float>>) = Array(21) { i ->
                val (x, y) = p[i]
                val cx = x - 0.5f; val cy = y - 0.6f
                (0.5f + cx * cos(a).toFloat() - cy * sin(a).toFloat()) to (0.6f + cx * sin(a).toFloat() + cy * cos(a).toFloat())
            }
            assertEquals(5, read(turn(hand(allUp, thumbTucked = false))).fingers, "open at $deg")
            assertEquals(4, read(turn(hand(allUp, thumbTucked = true))).fingers, "four at $deg")
        }
        fun mirror(p: Array<Pair<Float, Float>>) = Array(21) { i -> (1f - p[i].first) to p[i].second }
        assertEquals(5, read(mirror(hand(allUp, thumbTucked = false))).fingers, "left hand open")
        assertEquals(4, read(mirror(hand(allUp, thumbTucked = true))).fingers, "left hand four")
    }

    @Test
    fun tiltReadsDegreesOffFingersUp() {
        assertEquals(0f, read(hand(allUp, thumbTucked = false)).tilt, 0.01f)
    }
}
