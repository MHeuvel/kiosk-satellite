package me.jxl.kiosk_satellite.plugins

import org.junit.Assert.*
import org.junit.Test

class PluginTriggersTest {
    private fun rejects(action: () -> Unit) {
        try { action(); fail("Expected trigger rejection") } catch (_: IllegalArgumentException) {} catch (_: IllegalStateException) {}
    }
    @Test fun firesOnlyDeclaredTriggers() {
        val triggers = PluginTriggers({ it == "hardTap" })
        assertTrue(triggers.fire("hardTap"))
        rejects { triggers.fire("other") }
    }
    @Test fun dropsABurstPastTheBudgetAndRefillsAfterASecond() {
        var now = 0L
        val triggers = PluginTriggers({ true }) { now }
        repeat(PluginTriggers.MAX_PER_SECOND) { assertTrue(triggers.fire("hardTap")) }
        assertFalse(triggers.fire("hardTap"))
        now += 999_999_999L
        assertFalse(triggers.fire("hardTap"))
        now += 1L
        assertTrue(triggers.fire("hardTap"))
    }
    @Test fun refusesAfterTheSessionCloses() {
        val triggers = PluginTriggers({ true })
        triggers.close()
        rejects { triggers.fire("hardTap") }
    }
}
