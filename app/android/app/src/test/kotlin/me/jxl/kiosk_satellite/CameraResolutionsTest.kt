package me.jxl.kiosk_satellite

import org.junit.Assert.assertEquals
import org.junit.Test

class CameraResolutionsTest {
    @Test fun portalWidescreenModeOutranksTheDefaultFourByThreeOrder() {
        val candidates = listOf(640 to 480, 320 to 240, 1280 to 720)
        assertEquals(1280 to 720, orderedVideoSizes(candidates, 1280 to 720).first())
        assertEquals(640 to 480, orderedVideoSizes(candidates, 640 to 480).first())
    }

    @Test fun unsupportedFullHdFallsBackToTheClosestCameraSize() {
        assertEquals(1280 to 720,
            orderedVideoSizes(listOf(640 to 480, 1280 to 720), 1920 to 1080).first())
    }

    @Test fun exactPortraitAndSquareModesKeepTheirDimensions() {
        val candidates = listOf(1280 to 720, 720 to 1280, 1080 to 1080)
        assertEquals(720 to 1280, orderedVideoSizes(candidates, 720 to 1280).first())
        assertEquals(1080 to 1080, orderedVideoSizes(candidates, 1080 to 1080).first())
    }
}
