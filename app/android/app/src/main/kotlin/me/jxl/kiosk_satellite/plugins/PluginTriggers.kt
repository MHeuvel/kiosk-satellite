package me.jxl.kiosk_satellite.plugins

/**
 * Session-owned gate for gesture triggers. Only declared triggers fire, and
 * a burst past the budget is dropped rather than failing the plugin: a held
 * or bouncing hardware key must not disable it.
 */
internal class PluginTriggers(private val declared: (String) -> Boolean, private val clock: () -> Long = System::nanoTime) {
    private var closed = false
    private var window = clock()
    private var fired = 0

    /** True when the trigger should reach the gestures, false when dropped. */
    @Synchronized fun fire(id: String): Boolean {
        check(!closed) { "Plugin session has ended" }
        require(declared(id)) { "Unknown plugin trigger" }
        val now = clock()
        if (now - window >= 1_000_000_000L) { window = now; fired = 0 }
        if (fired >= MAX_PER_SECOND) return false
        fired++
        return true
    }

    @Synchronized fun close() { closed = true }

    companion object {
        const val MAX_PER_SECOND = 4
    }
}
