package me.jxl.kiosk_satellite.plugins

/**
 * Bounded, session-owned native overlays: the placement and factory per
 * key. The views themselves are built by [PluginOverlayViews] when Flutter
 * lays the overlay out. A replaced overlay gets a new generation, so Flutter
 * builds a fresh view from the new factory instead of keeping the old one.
 */
internal class PluginOverlays<F : Any>(private val clock: () -> Long = System::nanoTime) {
    class Entry<F>(val key: String, val placement: Map<String, Any>, val factory: F, val generation: Int)

    private val entries = linkedMapOf<String, Entry<F>>()
    private var closed = false
    private var generation = 0
    private var window = clock()
    private var changes = 0

    @Synchronized fun show(
        key: String,
        anchor: String,
        width: Int,
        height: Int,
        inset: Int,
        closeOnBack: Boolean,
        onTop: Boolean,
        touchable: Boolean,
        factory: F,
    ): Entry<F> {
        check(!closed) { "Plugin session has ended" }
        require(key.matches(Regex("[a-z][a-z0-9_]{0,39}"))) { "Invalid overlay key" }
        require(entries.containsKey(key) || entries.size < MAX_OVERLAYS) { "At most four overlays are supported" }
        require(anchor in ANCHORS) { "Unknown overlay anchor" }
        require(validSize(width) && validSize(height)) { "Overlay sizes must be WRAP, FILL or 1 to 4096 dp" }
        require(inset in 0..MAX_INSET) { "Overlay inset must be 0 to 200 dp" }
        val now = clock()
        if (now - window >= 1_000_000_000L) { window = now; changes = 0 }
        check(changes < 8) { "At most eight overlay changes per second are supported" }
        changes++
        val entry = Entry(key, mapOf(
            "anchor" to anchor, "width" to width, "height" to height, "inset" to inset,
            "closeOnBack" to closeOnBack, "onTop" to onTop, "touchable" to touchable,
        ), factory, ++generation)
        // A replacement moves to the top, like a new overlay.
        entries.remove(key)
        entries[key] = entry
        return entry
    }

    /** Ignored once the session ends, so a plugin may hide its overlays in stop(). */
    @Synchronized fun hide(key: String): Boolean = !closed && entries.remove(key) != null

    /** Removes the overlay only if it is still the generation Flutter showed. */
    @Synchronized fun closed(key: String, generation: Int): Boolean =
        !closed && entries[key]?.generation == generation && entries.remove(key) != null

    @Synchronized fun get(key: String, generation: Int): Entry<F>? = entries[key]?.takeIf { it.generation == generation }

    @Synchronized fun snapshot(): List<Map<String, Any>> =
        entries.values.map { it.placement + mapOf("key" to it.key, "generation" to it.generation) }

    @Synchronized fun close() { closed = true; entries.clear() }

    companion object {
        const val MAX_OVERLAYS = 4
        const val MAX_INSET = 200
        const val WRAP = -1
        const val FILL = -2
        val ANCHORS = setOf("top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right")
        private fun validSize(value: Int) = value == WRAP || value == FILL || value in 1..4096
    }
}
