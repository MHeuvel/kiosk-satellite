package me.jxl.kiosk_satellite

import org.junit.Assert.assertEquals
import org.junit.Test

class PlaybackVolumeTest {
    @Test fun quieterCallStreamPreservesAssistantLevelWithinAvailableRange() {
        val compensation = PlaybackVolume.compensation(0f, 0f, -6.0206f, 0f)
        val level = PlaybackVolume.level(1f, 0.25f, compensation)
        assertEquals(0.5f, level, 0.0001f)
        assertEquals(0.25f, level / compensation, 0.0001f)
    }

    @Test fun assistantSliderStillScalesCompensatedPlayback() {
        val compensation = PlaybackVolume.compensation(0f, 0f, -6.0206f, 0f)
        val at50 = PlaybackVolume.level(1f, 0.25f, compensation)
        val at25 = PlaybackVolume.level(1f, 0.0625f, compensation)
        assertEquals(at50 / 4f, at25, 0.0001f)
    }

    @Test fun masterAttenuationAndMuteStillApply() {
        val compensation = PlaybackVolume.compensation(-12.0412f, 0f, -6.0206f, 0f)
        assertEquals(0.125f, PlaybackVolume.level(1f, 0.25f, compensation), 0.0001f)
        assertEquals(0f, PlaybackVolume.level(1f, 0.25f, 0f), 0f)
        assertEquals(0f, PlaybackVolume.level(1f, 0f, compensation), 0f)
    }

    @Test fun insufficientCallVolumeCapsOutputWithoutInvalidPlayerGain() {
        val compensation = PlaybackVolume.compensation(0f, 0f, -40f, 0f)
        assertEquals(1f, PlaybackVolume.level(1f, 0.25f, compensation), 0f)
        assertEquals(0f, PlaybackVolume.level(1f, 0f, compensation), 0f)
    }

    @Test fun streamsWithDifferentReferencePointsGetUnityGainAtMaximum() {
        // LG V30: media at its maximum reports about -46 dB, the call stream 0 dB.
        val compensation = PlaybackVolume.compensation(-46f, -46f, 0f, 0f)
        assertEquals(1f, compensation, 0.0001f)
        assertEquals(1f, PlaybackVolume.level(1f, 1f, compensation), 0.0001f)
    }

    @Test fun mediaAttenuationBelowItsOwnMaximumStillApplies() {
        val compensation = PlaybackVolume.compensation(-58.0412f, -46f, 0f, 0f)
        assertEquals(0.25f, PlaybackVolume.level(1f, 1f, compensation), 0.0001f)
    }
}
