package me.jxl.kiosk_satellite.plugins

import org.junit.Assert.*
import org.junit.Test

class PluginStartupGuardTest {
    private val v1 = 1_000L
    private val v2 = 2_000L

    @Test fun aFinishedStartupCountsNothing() {
        assertEquals(0, PluginBridge.startupStrikes(pending = false, startedUpdatedAt = v1, updatedAt = v1, strikes = 1))
    }
    @Test fun anUpdateDuringStartupCountsNothing() {
        assertEquals(0, PluginBridge.startupStrikes(pending = true, startedUpdatedAt = v1, updatedAt = v2, strikes = 1))
    }
    @Test fun oneIncompleteStartupDoesNotDisable() {
        assertTrue(PluginBridge.startupStrikes(pending = true, startedUpdatedAt = v1, updatedAt = v1, strikes = 0) < PluginBridge.STARTUP_STRIKES)
    }
    @Test fun twoIncompleteStartupsInARowDisable() {
        assertEquals(PluginBridge.STARTUP_STRIKES, PluginBridge.startupStrikes(pending = true, startedUpdatedAt = v1, updatedAt = v1, strikes = 1))
    }
}
