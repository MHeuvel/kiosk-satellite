package me.jxl.kiosk_satellite.plugins

import org.junit.Assert.*
import org.junit.Test

class PluginOverlaysTest {
    private fun rejects(action: () -> Unit) {
        try { action(); fail("Expected overlay rejection") } catch (_: IllegalArgumentException) {} catch (_: IllegalStateException) {}
    }

    private fun PluginOverlays<String>.bar(key: String = "bar", factory: String = "first", width: Int = PluginOverlays.WRAP) =
        show(key, "top", width, PluginOverlays.WRAP, 12, true, false, true, factory)

    @Test fun snapshotCarriesPlacementKeyAndGeneration() {
        val overlays = PluginOverlays<String>()
        val entry = overlays.show("full", "center", PluginOverlays.FILL, PluginOverlays.FILL, 0, false, true, false, "factory")
        assertEquals(listOf(mapOf(
            "anchor" to "center", "width" to PluginOverlays.FILL, "height" to PluginOverlays.FILL, "inset" to 0,
            "closeOnBack" to false, "onTop" to true, "touchable" to false, "key" to "full", "generation" to entry.generation,
        )), overlays.snapshot())
        assertEquals("factory", overlays.get("full", entry.generation)?.factory)
    }

    @Test fun rejectsBadPlacements() {
        val overlays = PluginOverlays<String>()
        rejects { overlays.bar(key = "Bar") }
        rejects { overlays.show("bar", "middle", PluginOverlays.WRAP, PluginOverlays.WRAP, 0, true, false, true, "f") }
        rejects { overlays.bar(width = 0) }
        rejects { overlays.bar(width = 4097) }
        rejects { overlays.show("bar", "top", PluginOverlays.WRAP, PluginOverlays.WRAP, 201, true, false, true, "f") }
        overlays.bar(width = 4096)
    }

    @Test fun limitsEachSessionToFourOverlays() {
        val overlays = PluginOverlays<String>()
        repeat(PluginOverlays.MAX_OVERLAYS) { overlays.bar(key = "o$it") }
        rejects { overlays.bar(key = "o9") }
        // Replacing an existing key is not a new overlay.
        overlays.bar(key = "o0")
    }

    @Test fun replacingMovesToTheTopWithANewGeneration() {
        val overlays = PluginOverlays<String>()
        val first = overlays.bar(factory = "first")
        overlays.bar(key = "other")
        val second = overlays.bar(factory = "second")
        assertNotEquals(first.generation, second.generation)
        assertEquals(listOf("other", "bar"), overlays.snapshot().map { it["key"] })
        assertNull(overlays.get("bar", first.generation))
        assertEquals("second", overlays.get("bar", second.generation)?.factory)
    }

    @Test fun backClosesOnlyTheGenerationFlutterShowed() {
        val overlays = PluginOverlays<String>()
        val first = overlays.bar()
        val second = overlays.bar(factory = "second")
        assertFalse(overlays.closed("bar", first.generation))
        assertTrue(overlays.closed("bar", second.generation))
        assertTrue(overlays.snapshot().isEmpty())
    }

    @Test fun dropsABurstPastTheBudget() {
        var now = 0L
        val overlays = PluginOverlays<String> { now }
        repeat(8) { overlays.bar() }
        rejects { overlays.bar() }
        now += 1_000_000_000L
        overlays.bar()
    }

    @Test fun hidingAfterTheSessionEndsIsANoOp() {
        val overlays = PluginOverlays<String>()
        overlays.bar()
        overlays.close()
        assertFalse(overlays.hide("bar"))
        assertTrue(overlays.snapshot().isEmpty())
        rejects { overlays.bar() }
    }

    /** Defines one class itself, the way a plugin's DexClassLoader does. */
    private class OwningLoader(parent: ClassLoader, private val owned: String) : ClassLoader(parent) {
        override fun loadClass(name: String, resolve: Boolean): Class<*> {
            if (name != owned) return super.loadClass(name, resolve)
            findLoadedClass(name)?.let { return it }
            val bytes = parent.getResourceAsStream(name.replace('.', '/') + ".class")!!.readBytes()
            return defineClass(name, bytes, 0, bytes.size)
        }
    }

    class Victim

    @Test fun blamesThePluginWhoseLoaderDefinedAFrame() {
        val owned = Victim::class.java.name
        val loaders = listOf(
            "other" to OwningLoader(javaClass.classLoader!!, "nothing.Here"),
            "hello" to OwningLoader(javaClass.classLoader!!, owned),
        )
        fun crash(vararg classes: String) = RuntimeException("boom").apply {
            stackTrace = classes.map { StackTraceElement(it, "onDraw", null, 1) }.toTypedArray()
        }
        assertEquals("hello", PluginBridge.culprit(crash("android.view.View", owned), loaders))
        // KS and SDK classes resolve through the parent and never take the blame.
        assertNull(PluginBridge.culprit(crash("android.view.View", PluginOverlays::class.java.name), loaders))
        // Found through the cause too.
        val wrapped = RuntimeException("outer", crash(owned)).apply { stackTrace = emptyArray() }
        assertEquals("hello", PluginBridge.culprit(wrapped, loaders))
        assertNull(PluginBridge.culprit(crash(owned), emptyList()))
    }
}
