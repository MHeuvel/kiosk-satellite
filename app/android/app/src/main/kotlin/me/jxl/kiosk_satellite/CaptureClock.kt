package me.jxl.kiosk_satellite

/**
 * When the last frame read was captured, by counting frames: the count is
 * exact, where a read's return time wanders by milliseconds and Android's
 * own capture timestamps cannot be relied on (an Echo Show 8 reports frame
 * positions that are not this record's). The count is anchored to the
 * system clock at the first read and kept as close behind it as the reads
 * allow: pulled back at once when a read returns before the count says its
 * last frame was captured, and eased forward when every read in a while
 * came well after, which follows drift between the audio and system clocks
 * over a capture that runs for days.
 *
 * The easing moves at most [MAX_EASE_NS] a window, a little over any
 * crystal's drift. A read can also come late because audio waited in a
 * buffer, and following that at once moved the echo reference by tens of
 * milliseconds in one step, which the canceller had to relearn.
 */
internal class CaptureClock {
    private var anchorNs = 0L
    private var anchorFrames = 0L
    private var anchored = false
    private var windowStartNs = 0L
    private var minSlackNs = Long.MAX_VALUE

    fun reset() {
        anchored = false
    }

    fun heard(frames: Long, rate: Int, nowNs: Long): Long {
        if (!anchored) {
            anchorNs = nowNs
            anchorFrames = frames
            anchored = true
            windowStartNs = nowNs
            minSlackNs = Long.MAX_VALUE
            return nowNs
        }
        var heardNs = anchorNs + (frames - anchorFrames) * 1_000_000_000L / rate
        val slackNs = nowNs - heardNs
        if (slackNs < 0 || slackNs > RESET_NS) {
            // Captured after it was read cannot be, and a count this far
            // behind means reads were lost: start again from this read.
            anchorNs += slackNs
            heardNs = anchorNs + (frames - anchorFrames) * 1_000_000_000L / rate
        }
        minSlackNs = minOf(minSlackNs, nowNs - heardNs)
        if (nowNs - windowStartNs >= WINDOW_NS) {
            if (minSlackNs > EASE_NS) anchorNs += minOf(minSlackNs - EASE_NS, MAX_EASE_NS)
            windowStartNs = nowNs
            minSlackNs = Long.MAX_VALUE
        }
        return heardNs
    }

    private companion object {
        const val RESET_NS = 500_000_000L
        const val WINDOW_NS = 10_000_000_000L
        const val EASE_NS = 2_000_000L

        /** 2 ms a window, 200 ppm: drift is followed, a backed-up buffer barely moves it. */
        const val MAX_EASE_NS = 2_000_000L
    }
}
