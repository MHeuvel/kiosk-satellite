package me.jxl.kiosk_satellite

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CaptureWalkTest {
    private val second = 1_000_000_000L

    @Test
    fun freshRungGetsTwoSecondsAndATrustedRungThirty() {
        val walk = CaptureWalk(3, 0)
        assertFalse(walk.trusted)
        assertEquals(2L * 32000, walk.zeroLimitBytes)
        walk.audible()
        assertTrue(walk.trusted)
        assertEquals(30L * 32000, walk.zeroLimitBytes)
        // A different rung, fresh again, until it delivers audio of its own.
        walk.opened(1)
        assertFalse(walk.trusted)
        assertEquals(2L * 32000, walk.zeroLimitBytes)
        // Back on the rung that delivered audio earlier: trusted, even reopened.
        walk.opened(0)
        assertTrue(walk.trusted)
    }

    @Test
    fun exhaustedGoesBackToTheRungThatDeliveredAudio() {
        val walk = CaptureWalk(3, 0)
        walk.audible()
        walk.opened(1)
        walk.opened(2)
        assertEquals(0, walk.exhausted(0))
    }

    @Test
    fun exhaustedWithNothingAudibleGoesBackToTheFirstRung() {
        // Hardware format: the walk began on the card's rung, not rung 0
        // of the ladder, and nothing delivered audio, so the ladder's own
        // first rung is the best guess.
        val walk = CaptureWalk(3, 1)
        walk.opened(2)
        assertEquals(0, walk.exhausted(0))
    }

    @Test
    fun exhaustedRemembersTheLatestAudibleRung() {
        val walk = CaptureWalk(3, 0)
        walk.audible()
        walk.opened(1)
        walk.audible()
        walk.opened(2)
        assertEquals(1, walk.exhausted(0))
    }

    @Test
    fun walksFreelyUntilTheFirstExhaustionThenBacksOffDoubling() {
        val walk = CaptureWalk(3, 0)
        assertTrue(walk.mayWalk(0))
        assertTrue(walk.mayWalk(5 * second))

        walk.exhausted(10 * second)
        assertEquals(60, walk.waitSeconds)
        assertFalse(walk.mayWalk(10 * second))
        assertFalse(walk.mayWalk(69 * second))
        assertTrue(walk.mayWalk(70 * second))
        // Once open, the walk stays open until the next exhaustion.
        assertTrue(walk.mayWalk(500 * second))

        walk.exhausted(80 * second)
        assertEquals(120, walk.waitSeconds)
        assertFalse(walk.mayWalk(199 * second))
        assertTrue(walk.mayWalk(200 * second))

        walk.exhausted(200 * second)
        assertEquals(240, walk.waitSeconds)
        walk.exhausted(500 * second)
        assertEquals(480, walk.waitSeconds)
        walk.exhausted(1000 * second)
        assertEquals(600, walk.waitSeconds)
        walk.exhausted(2000 * second)
        assertEquals(600, walk.waitSeconds)
        assertFalse(walk.mayWalk(2599 * second))
        assertTrue(walk.mayWalk(2600 * second))
    }

    @Test
    fun audioDoesNotShortenTheBackoff() {
        // A gated microphone delivers audio between its silences; that
        // must not turn every quiet minute into a fresh walk.
        val walk = CaptureWalk(3, 0)
        walk.exhausted(0)
        walk.audible()
        walk.exhausted(70 * second)
        assertEquals(120, walk.waitSeconds)
    }

    @Test
    fun aHealthyRateIsHonestWithOrWithoutASound() {
        for (played in listOf(false, true)) {
            assertEquals(CaptureWalk.RateVerdict.HONEST, CaptureWalk.rateVerdict(0.98, played))
            assertEquals(CaptureWalk.RateVerdict.HONEST, CaptureWalk.rateVerdict(0.6, played))
            assertEquals(CaptureWalk.RateVerdict.HONEST, CaptureWalk.rateVerdict(1.6, played))
        }
    }

    @Test
    fun tooManyFramesIsALieEvenUnderASound() {
        // The MT8167 panel's 16 kHz mono open: its 48 kHz stereo misread
        // arrives at twice the rate, and playback cannot add frames.
        assertEquals(CaptureWalk.RateVerdict.LIE, CaptureWalk.rateVerdict(2.0, played = false))
        assertEquals(CaptureWalk.RateVerdict.LIE, CaptureWalk.rateVerdict(2.0, played = true))
        assertEquals(CaptureWalk.RateVerdict.LIE, CaptureWalk.rateVerdict(6.0, played = true))
    }

    @Test
    fun tooFewFramesIsALieOnlyInAQuietWindow() {
        // Mono under a stereo label delivers half the frames all the time.
        assertEquals(CaptureWalk.RateVerdict.LIE, CaptureWalk.rateVerdict(0.5, played = false))
        // The same panel starved under its chime (54%) and an answer (6%):
        // measured again, not a reason to leave a working format.
        assertEquals(CaptureWalk.RateVerdict.MEASURE_AGAIN, CaptureWalk.rateVerdict(0.54, played = true))
        assertEquals(CaptureWalk.RateVerdict.MEASURE_AGAIN, CaptureWalk.rateVerdict(0.06, played = true))
    }
}
