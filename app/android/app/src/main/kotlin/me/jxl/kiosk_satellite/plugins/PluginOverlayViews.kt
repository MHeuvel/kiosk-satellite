package me.jxl.kiosk_satellite.plugins

import android.content.Context
import android.content.res.AssetManager
import android.graphics.Typeface
import android.os.Build
import android.util.Log
import android.view.ContextThemeWrapper
import android.view.View
import android.widget.FrameLayout
import io.flutter.FlutterInjector
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import me.jxl.kiosk.plugins.KsTheme
import me.jxl.kiosk.plugins.OverlayFactory

/**
 * Hosts plugin overlay views as Flutter platform views. Dart shows them as
 * texture-composited AndroidViews inside the kiosk's own stack, so the
 * menu, the screensaver and the lockdown shield cover them the way they
 * cover the dashboard, and they leave with the Activity. Everything here
 * runs on the main thread.
 */
internal class PluginOverlayViews(
    assets: AssetManager,
    /** The live factory for a view request, or null once the overlay is gone. */
    private val lookup: (id: String, session: String, key: String, generation: Int) -> OverlayFactory?,
    /** A plugin threw from its view code. KS disables it. */
    private val failed: (id: String, session: String, error: Throwable) -> Unit,
    /** A wrapped overlay measured a new size, in physical pixels. */
    private val measured: (Map<String, Any>) -> Unit,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    companion object {
        const val VIEW_TYPE = "kiosk_satellite/plugin_overlay"
        private const val TAG = "PluginOverlayViews"
    }

    private inner class Hosted(
        val id: String,
        val session: String,
        val factory: OverlayFactory,
        val frame: OverlayFrame,
        var themeArgs: Map<*, *>?,
    ) : PlatformView {
        var content: View? = null
        override fun getView(): View = frame
        override fun dispose() {
            live.remove(this)
            val built = content ?: return
            content = null
            frame.removeAllViews()
            guard(this) { factory.onDestroy(built) }
        }
    }

    private val fonts = Fonts(assets)
    private val live = mutableListOf<Hosted>()

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<Any, Any>()
        val id = params["id"] as? String ?: ""
        val session = params["session"] as? String ?: ""
        val key = params["key"] as? String ?: ""
        val generation = (params["generation"] as? Number)?.toInt() ?: -1
        val themeArgs = params["theme"] as? Map<*, *>
        val wrapWidth = (params["width"] as? Number)?.toInt() == PluginOverlays.WRAP
        val wrapHeight = (params["height"] as? Number)?.toInt() == PluginOverlays.WRAP
        val inset = (params["inset"] as? Number)?.toInt() ?: 0
        val frame = OverlayFrame(context, wrapWidth, wrapHeight, inset) { width, height ->
            measured(mapOf("id" to id, "session" to session, "key" to key, "generation" to generation, "width" to width, "height" to height))
        }
        val factory = lookup(id, session, key, generation)
            // Hidden or replaced between Dart building it and this request.
            ?: return object : PlatformView {
                override fun getView(): View = frame
                override fun dispose() {}
            }
        val hosted = Hosted(id, session, factory, frame, themeArgs)
        live.add(hosted)
        val theme = theme(context, themeArgs)
        val themed = ContextThemeWrapper(context,
            if (theme.isDark) android.R.style.Theme_DeviceDefault_NoActionBar else android.R.style.Theme_DeviceDefault_Light_NoActionBar)
        guard(hosted) {
            val view = factory.create(themed, theme) ?: throw IllegalStateException("Overlay factory returned no view")
            hosted.content = view
            frame.addView(view)
        }
        return hosted
    }

    /** Dart's theme changed: restyle every live overlay. */
    fun setTheme(args: Map<*, *>) {
        for (hosted in live.toList()) {
            if (hosted.themeArgs == args) continue
            hosted.themeArgs = args
            val view = hosted.content ?: continue
            val theme = theme(hosted.frame.context, args)
            guard(hosted) { hosted.factory.onThemeChanged(view, theme) }
        }
    }

    private fun guard(hosted: Hosted, action: () -> Unit) {
        try { action() } catch (error: Throwable) {
            Log.w(TAG, "Plugin ${hosted.id} overlay failed", error)
            failed(hosted.id, hosted.session, error)
        }
    }

    private fun theme(context: Context, args: Map<*, *>?): KsTheme {
        val colors = (args?.get("colors") as? Map<*, *>)?.entries
            ?.mapNotNull { (role, value) -> (role as? String)?.let { name -> (value as? Number)?.let { name to it.toInt() } } }
            ?.toMap() ?: emptyMap()
        return KsTheme(args?.get("dark") as? Boolean ?: true, context.resources.displayMetrics.density, colors, fonts)
    }

    /** Rubik, the KS typeface, at real weights from its variable wght axis. */
    private class Fonts(private val assets: AssetManager) : KsTheme.Fonts {
        private val path by lazy {
            try { FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/fonts/Rubik.ttf") } catch (_: Throwable) { null }
        }
        private val cache = HashMap<Int, Typeface?>()

        @Synchronized override fun typeface(weight: Int): Typeface? {
            val rounded = (weight + 50) / 100 * 100
            return cache.getOrPut(rounded) {
                val asset = path ?: return@getOrPut null
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Typeface.Builder(assets, asset).setFontVariationSettings("'wght' $rounded").build()
                    } else {
                        val base = Typeface.createFromAsset(assets, asset)
                        if (rounded >= 600) Typeface.create(base, Typeface.BOLD) else base
                    }
                } catch (_: Throwable) { null }
            }
        }
    }

    /**
     * Sizes the plugin's view. Flutter gives the frame an exact size. A side
     * the plugin asked to wrap is measured against the space the kiosk has,
     * and the result goes back to Dart, which resizes the platform view.
     */
    private class OverlayFrame(
        context: Context,
        private val wrapWidth: Boolean,
        private val wrapHeight: Boolean,
        private val insetDp: Int,
        private val onMeasured: (Int, Int) -> Unit,
    ) : FrameLayout(context) {
        private var reported: Pair<Int, Int>? = null

        override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
            val child = getChildAt(0)
            val width = MeasureSpec.getSize(widthMeasureSpec)
            val height = MeasureSpec.getSize(heightMeasureSpec)
            if (child == null) { setMeasuredDimension(width, height); return }
            val metrics = resources.displayMetrics
            val inset = Math.round(insetDp * 2 * metrics.density)
            fun spec(wrap: Boolean, exact: Int, available: Int) =
                if (wrap) MeasureSpec.makeMeasureSpec(maxOf(0, available - inset), MeasureSpec.AT_MOST)
                else MeasureSpec.makeMeasureSpec(exact, MeasureSpec.EXACTLY)
            child.measure(spec(wrapWidth, width, metrics.widthPixels), spec(wrapHeight, height, metrics.heightPixels))
            setMeasuredDimension(width, height)
            if (!wrapWidth && !wrapHeight) return
            val size = (if (wrapWidth) child.measuredWidth else width) to (if (wrapHeight) child.measuredHeight else height)
            if (size != reported) {
                reported = size
                onMeasured(size.first, size.second)
            }
        }

        override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
            val child = getChildAt(0) ?: return
            child.layout(0, 0, child.measuredWidth, child.measuredHeight)
        }
    }
}
