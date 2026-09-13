package me.jxl.kiosk_satellite.plugins

/** Bounded, session-owned Overview status tiles. Never persisted or included in fleet settings. */
internal class PluginStatusTiles(private val clock: () -> Long = System::nanoTime) {
    private val tiles = linkedMapOf<String, Map<String, String>>()
    private var closed = false
    private var window = clock()
    private var changes = 0

    @Synchronized fun publish(key: String, title: String, level: String, text: String) {
        check(!closed) { "Plugin session has ended" }
        require(key.matches(Regex("[a-z][a-z0-9_]{0,39}"))) { "Invalid status tile key" }
        require(tiles.containsKey(key) || tiles.size < MAX_TILES) { "At most two status tiles are supported" }
        require(title.isNotBlank() && title.length <= 40 && title.none { it < ' ' }) { "Status tile title must be 1 to 40 characters" }
        require(level in LEVELS) { "Status tile level must be on, warn, off or empty" }
        require(text.length <= 80 && text.none { it < ' ' }) { "Status tile text must be at most 80 characters" }
        budget()
        tiles[key] = mapOf("key" to key, "title" to title, "level" to level, "text" to text)
    }

    private fun budget() {
        val now = clock()
        if (now - window >= 1_000_000_000L) { window = now; changes = 0 }
        check(changes < 8) { "At most eight status tile changes per second are supported" }
        changes++
    }

    @Synchronized fun remove(key: String) {
        check(!closed) { "Plugin session has ended" }
        budget()
        tiles.remove(key)
    }

    @Synchronized fun snapshot(): List<Map<String, String>> = tiles.values.toList()
    @Synchronized fun close() { closed = true; tiles.clear() }

    companion object {
        const val MAX_TILES = 2
        val LEVELS = setOf("", "on", "warn", "off")
    }
}
