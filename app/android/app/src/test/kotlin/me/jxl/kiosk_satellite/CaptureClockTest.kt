package me.jxl.kiosk_satellite

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CaptureClockTest {
    @Test fun bufferedReadsMoveTheEchoReferenceAtMostTwoMillisecondsATime() {
        val clock = CaptureClock()
        val start = 1_000_000_000L
        assertEquals(start, clock.heard(1280, 16000, start))
        var previous = 0L
        for (chunk in 1L..750L) {
            val captured = start + chunk * 80_000_000L
            val queued = when {
                chunk < 125 -> 16_000_000L
                chunk < 375 -> 48_000_000L
                else -> 32_000_000L
            }
            val error = clock.heard((chunk + 1) * 1280, 16000, captured + queued) - captured
            // A minute of reads 16 to 48 ms late moves it in steps of 2 ms
            // at most, never by the lateness itself.
            assertTrue("step at chunk $chunk", error - previous in 0L..2_000_000L)
            assertTrue("error at chunk $chunk", error <= 12_000_000L)
            previous = error
        }
    }

    @Test fun driftBetweenTheAudioAndSystemClocksIsFollowed() {
        val clock = CaptureClock()
        val start = 1_000_000_000L
        // The audio clock runs 100 ppm slow: each 80 ms chunk takes 80.008 ms.
        var worst = 0L
        for (chunk in 0L..(2 * 3600 * 1000 / 80)) {
            val captured = start + chunk * 80_008_000L
            val error = captured - clock.heard((chunk + 1) * 1280, 16000, captured + 5_000_000L)
            if (chunk > 1000) worst = maxOf(worst, kotlin.math.abs(error))
        }
        // Two hours at 100 ppm is 720 ms of drift: the clock stays within
        // a few milliseconds of it instead of sliding until it resets.
        assertTrue("worst $worst", worst <= 10_000_000L)
    }

    @Test fun anEarlierReadTightensTheCaptureTimeWithoutLaterReversingIt() {
        val clock = CaptureClock()
        clock.heard(1280, 16000, 1_016_000_000L)
        assertEquals(1_080_000_000L, clock.heard(2560, 16000, 1_080_000_000L))
        assertEquals(1_160_000_000L, clock.heard(3840, 16000, 1_192_000_000L))
    }

    @Test fun lostCaptureAndAReopenedRecorderCanStartANewClock() {
        val clock = CaptureClock()
        clock.heard(1280, 16000, 1_000_000_000L)
        assertEquals(2_000_000_000L, clock.heard(2560, 16000, 2_000_000_000L))
        assertEquals(2_080_000_000L, clock.heard(3840, 16000, 2_112_000_000L))
        clock.reset()
        assertEquals(4_000_000_000L, clock.heard(1280, 16000, 4_000_000_000L))
    }
}
