package me.jxl.kiosk_satellite

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class CameraMotionActivityTest {
    @Test
    fun sensorNoiseDoesNotOpenTheVisionGate() {
        for (changedCells in 0..3) {
            assertFalse(isVisionActivity(changedCells, illumination = false))
        }
    }

    @Test
    fun aHandSizedChangeOpensTheVisionGate() {
        assertTrue(isVisionActivity(changedCells = 4, illumination = false))
        assertTrue(isVisionActivity(changedCells = 12, illumination = false))
    }

    @Test
    fun lightingChangesDoNotOpenTheVisionGate() {
        assertFalse(isVisionActivity(changedCells = 12, illumination = true))
    }
}
