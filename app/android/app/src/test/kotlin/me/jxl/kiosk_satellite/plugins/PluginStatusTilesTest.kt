package me.jxl.kiosk_satellite.plugins

import org.junit.Assert.*
import org.junit.Test

class PluginStatusTilesTest {
    private fun rejects(action: () -> Unit) {
        try { action(); fail("Expected status tile rejection") } catch (_: IllegalArgumentException) {} catch (_: IllegalStateException) {}
    }
    @Test fun publishesUpdatesAndRemovesByKey() {
        val store = PluginStatusTiles()
        store.publish("webview", "WebView responsiveness", "on", "smooth")
        store.publish("webview", "WebView responsiveness", "warn", "occasional stalls")
        assertEquals(listOf(mapOf("key" to "webview", "title" to "WebView responsiveness", "level" to "warn", "text" to "occasional stalls")), store.snapshot())
        store.remove("webview")
        store.remove("missing")
        assertTrue(store.snapshot().isEmpty())
    }
    @Test fun validatesEveryFieldAndKeepsThePreviousTile() {
        val store = PluginStatusTiles()
        store.publish("webview", "WebView", "on", "smooth")
        rejects { store.publish("../bad", "WebView", "on", "smooth") }
        rejects { store.publish("webview", "", "on", "smooth") }
        rejects { store.publish("webview", "a".repeat(41), "on", "smooth") }
        rejects { store.publish("webview", "Web\nView", "on", "smooth") }
        rejects { store.publish("webview", "WebView", "green", "smooth") }
        rejects { store.publish("webview", "WebView", "On", "smooth") }
        rejects { store.publish("webview", "WebView", "on", "a".repeat(81)) }
        rejects { store.publish("webview", "WebView", "on", "smooth") }
        assertEquals("on", store.snapshot().single()["level"])
        store.publish("webview", "WebView", "", "")
        assertEquals(mapOf("key" to "webview", "title" to "WebView", "level" to "", "text" to ""), store.snapshot().single())
    }
    @Test fun boundsTilesAndChangesPerSession() {
        var now = 0L
        val store = PluginStatusTiles { now }
        store.publish("first", "First", "on", "ok")
        store.publish("second", "Second", "off", "down")
        rejects { store.publish("third", "Third", "warn", "meh") }
        assertEquals(listOf("first", "second"), store.snapshot().map { it["key"] })
        repeat(6) { store.publish("first", "First", "on", "ok $it") }
        rejects { store.remove("second") }
        now += 1_000_000_000L
        store.remove("second")
        store.publish("third", "Third", "warn", "meh")
        assertEquals(listOf("first", "third"), store.snapshot().map { it["key"] })
        store.close()
        assertTrue(store.snapshot().isEmpty())
        rejects { store.publish("late", "Late", "on", "ok") }
        rejects { store.remove("first") }
    }
}
