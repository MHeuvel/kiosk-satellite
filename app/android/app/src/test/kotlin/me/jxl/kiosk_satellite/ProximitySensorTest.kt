package me.jxl.kiosk_satellite

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ProximitySensorTest {
    @Test
    fun px30ReadingsAlternateBetweenFarAndNear() {
        val threshold = proximityNearThreshold(9f, 9f)
        val readings = listOf(1f, 0f, 1f, 0f, 1f, 0f)
        assertEquals(
            listOf(false, true, false, true, false, true),
            readings.map { it < threshold },
        )
    }

    @Test
    fun binarySensorsRecognizeNearAndFarAcrossRanges() {
        for (range in listOf(9f, 5f, 1f, 0.4f)) {
            val threshold = proximityNearThreshold(range, range)
            assertTrue(0f < threshold, "near at range $range")
            assertFalse(range < threshold, "far at range $range")
            assertFalse(1f < threshold, "far flag at range $range")
        }
    }

    @Test
    fun continuousSensorsKeepTheirDistanceRange() {
        val threshold = proximityNearThreshold(5f, 0.1f)
        assertTrue(2f < threshold)
        assertTrue(4.9f < threshold)
        assertFalse(5f < threshold)
        assertFalse(6f < threshold)
    }

    @Test
    fun missingRangeStillDistinguishesBinaryFlags() {
        for (range in listOf(0f, -1f)) {
            val threshold = proximityNearThreshold(range, 0f)
            assertTrue(0f < threshold)
            assertFalse(1f < threshold)
        }
    }
}
