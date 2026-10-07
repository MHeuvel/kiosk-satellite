package me.jxl.kiosk_satellite.plugins

/** SDK event contract and per-session bounds for asynchronous commands. */
internal object PluginHostPolicy {
    fun entityEvent(event: String) = event.startsWith("ha.entity.") &&
        event.removePrefix("ha.entity.").let { it.length <= 255 && it.matches(Regex("[a-z0-9_]+\\.[a-z0-9_]+")) }
    fun validEvent(event: String) = event in events || entityEvent(event)
    val events = setOf(
        "screensaver.state", "screensaver.countdown", "screensaver.view",
        "screen.state", "screen.brightness", "screen.ambient",
        "device.power", "device.network", "device.volume", "device.light", "device.key",
        "detection.motion", "detection.face", "detection.proximity",
        "detection.person", "detection.presence", "voice.interaction", "voice.state",
        "wakeword.state", "wakeword.detected", "stopword.detected", "camera.view", "browser.state",
    )

    /**
     * The `device.key` payload. Null for printing and modifier keys, so typed
     * text never reaches a plugin. [name] is Android's KEYCODE_ constant.
     */
    fun keyPayload(name: String, code: Int, scanCode: Int, down: Boolean, repeat: Int, printing: Boolean, modifier: Boolean, time: String): Map<String, Any>? =
        if (printing || modifier) null else mapOf(
            "key" to name.removePrefix("KEYCODE_"),
            "code" to code,
            "scanCode" to scanCode,
            "action" to if (down) "down" else "up",
            "repeat" to repeat,
            "time" to time,
        )
}

internal class PluginCommandBudget {
    private var windowStart: Long? = null
    private var count = 0
    private var pending = 0

    @Synchronized fun acquire(now: Long = System.nanoTime()) {
        if (windowStart == null || now - windowStart!! >= 1_000_000_000L) { windowStart = now; count = 0 }
        check(pending < 8) { "At most 8 KS commands may be pending" }
        check(count < 20) { "At most 20 KS commands per second" }
        pending++; count++
    }
    @Synchronized fun release() { if (pending > 0) pending-- }
}
