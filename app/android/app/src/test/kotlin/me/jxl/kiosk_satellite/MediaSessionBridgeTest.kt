package me.jxl.kiosk_satellite

import android.media.session.PlaybackState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MediaSessionBridgeTest {
    @Test fun actionsBecomeTheControlsCommands() {
        val actions = PlaybackState.ACTION_PLAY_PAUSE or
            PlaybackState.ACTION_SKIP_TO_NEXT or
            PlaybackState.ACTION_SKIP_TO_PREVIOUS or
            PlaybackState.ACTION_SEEK_TO
        assertEquals(
            listOf("play", "pause", "next", "previous", "seek"),
            MediaSessionBridge.commandsFor(actions, 200_000),
        )
    }

    @Test fun noSeekWithoutADuration() {
        // A live stream reports no length, so there is no bar to seek on.
        assertEquals(
            listOf("pause"),
            MediaSessionBridge.commandsFor(PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_SEEK_TO, 0),
        )
    }

    @Test fun aSessionWithoutActionsGetsTheBasics() {
        assertEquals(
            listOf("play", "pause", "next", "previous"),
            MediaSessionBridge.commandsFor(0, 0),
        )
    }

    @Test fun pausedShowsAndStoppedDoesNot() {
        assertTrue(MediaSessionBridge.isShowable(PlaybackState.STATE_PAUSED))
        assertTrue(MediaSessionBridge.isShowable(PlaybackState.STATE_BUFFERING))
        assertFalse(MediaSessionBridge.isShowable(PlaybackState.STATE_STOPPED))
        assertFalse(MediaSessionBridge.isShowable(PlaybackState.STATE_NONE))
        assertFalse(MediaSessionBridge.isPlaying(PlaybackState.STATE_PAUSED))
    }
}
