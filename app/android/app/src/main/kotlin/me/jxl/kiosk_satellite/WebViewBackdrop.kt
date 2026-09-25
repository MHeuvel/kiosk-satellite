package me.jxl.kiosk_satellite

import android.app.Activity
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.view.SurfaceHolder
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.webkit.WebView
import io.flutter.embedding.android.FlutterImageView
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterView

/** Avoid sampling Flutter's background while the dashboard covers it. */
class WebViewBackdrop(activity: Activity) : ViewTreeObserver.OnPreDrawListener {
    private val root = activity.window.decorView
    private val viewport = Rect()
    private val pageBounds = Rect()
    private var hidden: FlutterImageView? = null
    private var discarded: FlutterSurfaceView? = null
    private var pending: Pair<FlutterSurfaceView, SurfaceHolder.Callback>? = null
    private var backedPage: WebView? = null

    init {
        root.viewTreeObserver.addOnPreDrawListener(this)
    }

    override fun onPreDraw(): Boolean {
        val flutter = findFlutterView(root)
        val image = flutter?.currentImageSurface
        // The first WebView is the dashboard. A second full-screen WebView
        // may be a transparent overlay and must not suppress its background.
        val page = flutter?.let { firstWebView(it) }
        val covers = image != null && page != null && page.isShown &&
            page.isHardwareAccelerated && unblended(page, flutter) &&
            flutter.getGlobalVisibleRect(viewport) &&
            page.getGlobalVisibleRect(pageBounds) && pageBounds.contains(viewport)
        if (covers && backedPage !== page) {
            // KioskScreen's scaffold is black. Give transparent documents
            // that same background directly so every pixel stays covered.
            val background = page!!.background
            if (!page.isOpaque && (background == null ||
                background is ColorDrawable && Color.alpha(background.color) == 0)) {
                page.setBackgroundColor(Color.BLACK)
                // WebView's opacity hint can stay false after the color
                // changes. A native drawable guarantees the same fill.
                page.background = ColorDrawable(Color.BLACK)
            }
            backedPage = page
        }
        val color = (page?.background as? ColorDrawable)?.color ?: Color.TRANSPARENT
        val opaque = page?.isOpaque == true || Color.alpha(color) == 255
        val next = if (covers && opaque) image else null
        if (page == null) backedPage = null
        if (hidden !== next) {
            hidden?.let(::reveal)
            hidden = next
        }
        // Flutter can replace or reattach its image surface after a route
        // transition. Reassert only when necessary to avoid redraw loops.
        if (next != null && next.alpha != 0f) next.alpha = 0f
        discardStaleSurface(flutter, next != null)
        return true
    }

    /**
     * While the dashboard covers the window Flutter draws into its image
     * view, and its paused SurfaceView keeps the last frame from before,
     * such as the end of the previous screensaver. When Flutter switches
     * back, it drops the image view as soon as the surface's first frame is
     * submitted, which can be a refresh before that frame is on screen, so
     * the old frame flashed. Hiding the surface for a moment once the
     * dashboard covers it discards that buffer, and the surface Android
     * creates again starts empty.
     *
     * The surface must be back before Flutter resumes. A paused Flutter
     * ignores the surface going away and coming back and later only swaps
     * to it. Resumed without a surface, it would tear down and rebuild its
     * renderer when one appears, and with the dashboard on screen that
     * teardown runs on the main thread, which leaves Impeller's OpenGL ES
     * context stuck there (see [MainThreadEgl]) and Flutter never draws
     * again.
     */
    private fun discardStaleSurface(flutter: FlutterView?, covered: Boolean) {
        val surface = flutter?.let { findSurface(it) } ?: return
        if (!covered) {
            discarded = null
            restore(surface)
            return
        }
        if (discarded === surface) return
        discarded = surface
        // Without a surface there is no old buffer, and no destroy callback
        // would ever bring the view back.
        if (surface.holder.surface?.isValid != true) return
        val callback = object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {}
            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}
            override fun surfaceDestroyed(holder: SurfaceHolder) {
                surface.post { restore(surface) }
            }
        }
        surface.holder.addCallback(callback)
        pending = surface to callback
        surface.visibility = View.INVISIBLE
    }

    private fun restore(surface: FlutterSurfaceView) {
        pending?.let { (view, callback) ->
            view.holder.removeCallback(callback)
            if (view !== surface) view.visibility = View.VISIBLE
        }
        pending = null
        if (surface.visibility != View.VISIBLE) surface.visibility = View.VISIBLE
    }

    private fun findSurface(view: View): FlutterSurfaceView? {
        if (view is FlutterSurfaceView) return view
        if (view is ViewGroup) for (i in 0 until view.childCount) {
            findSurface(view.getChildAt(i))?.let { return it }
        }
        return null
    }

    /**
     * An alpha change reuses the view's last recorded drawing, and the image
     * view has not drawn since it was hidden: showing it that way flashes
     * whatever Flutter drew before the dashboard covered it, such as the end
     * of the previous screensaver. Redraw it with its current frame.
     */
    private fun reveal(image: FlutterImageView) {
        image.invalidate()
        image.alpha = 1f
    }

    private fun unblended(view: View, flutter: FlutterView): Boolean {
        var current: View? = view
        while (current != null && current !== flutter) {
            // Flutter uses a hardware layer for platform-view opacity.
            // Leave it alone during fades and any other cached composition.
            if (current.alpha != 1f || current.layerType != View.LAYER_TYPE_NONE) return false
            current = current.parent as? View
        }
        return current === flutter
    }

    private fun findFlutterView(view: View): FlutterView? {
        if (view is FlutterView) return view
        if (view is ViewGroup) for (i in 0 until view.childCount) {
            findFlutterView(view.getChildAt(i))?.let { return it }
        }
        return null
    }

    private fun firstWebView(view: View): WebView? {
        if (view is WebView) return view
        if (view is ViewGroup) for (i in 0 until view.childCount) {
            firstWebView(view.getChildAt(i))?.let { return it }
        }
        return null
    }

    fun dispose() {
        if (root.viewTreeObserver.isAlive) {
            root.viewTreeObserver.removeOnPreDrawListener(this)
        }
        hidden?.let(::reveal)
        hidden = null
        pending?.let { (view, callback) ->
            view.holder.removeCallback(callback)
            view.visibility = View.VISIBLE
        }
        pending = null
        discarded = null
        backedPage = null
    }
}
