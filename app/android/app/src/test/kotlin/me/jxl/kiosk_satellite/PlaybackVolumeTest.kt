package me.jxl.kiosk_satellite

import org.junit.Assert.assertEquals
import org.junit.Test

class PlaybackVolumeTest {
    @Test fun fadersMultiply() {
        assertEquals(0.125f, PlaybackVolume.level(0.5f, 0.5f, 0.5f), 0.0001f)
        assertEquals(0.25f, PlaybackVolume.level(1f, 0.25f, 1f), 0.0001f)
    }

    @Test fun anyMutedFaderSilences() {
        assertEquals(0f, PlaybackVolume.level(0f, 1f, 1f), 0f)
        assertEquals(0f, PlaybackVolume.level(1f, 0f, 1f), 0f)
        assertEquals(0f, PlaybackVolume.level(1f, 1f, 0f), 0f)
    }

    @Test fun levelStaysWithinPlayerRange() {
        assertEquals(1f, PlaybackVolume.level(2f, 1f, 1f), 0f)
        assertEquals(0f, PlaybackVolume.level(-1f, 1f, 1f), 0f)
    }
}
