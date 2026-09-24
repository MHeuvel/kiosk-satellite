package me.jxl.kiosk_satellite

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.view.PixelCopy
import android.view.Surface
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Captures the composed Android window via [PixelCopy], including the
 * WebView, its video, menus and screensaver, with the Flutter surface
 * underneath wherever the window is transparent. The GPU copy never draws
 * on the main thread. The WebView plugin's takeScreenshot renders
 * the view hierarchy into a bitmap *on* the UI thread, which the remote
 * admin's auto-refresh turned into a visible stutter every few seconds.
 *
 * The copy lands directly in a bitmap of the requested size (PixelCopy
 * scales on the way), so a 720px preview never allocates a full-resolution
 * frame, and the JPEG encode runs on this helper's own thread.
 *
 * Activity-scoped (a window is required): registered and torn down by
 * MainActivity alongside the other Activity bridges. Returns null rather
 * than failing when there is nothing to capture. The Dart side falls back
 * to the WebView's own page capture.
 */
class ScreenCapture(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "kiosk_satellite/screen_capture")
    private val thread = HandlerThread("screen-capture").also { it.start() }
    private val handler = Handler(thread.looper)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "capture" -> capture(
                    (call.argument<Number>("width"))?.toInt() ?: 1280,
                    (call.argument<Number>("quality"))?.toInt() ?: 80,
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        thread.quitSafely()
    }

    private fun capture(width: Int, quality: Int, result: MethodChannel.Result) {
        // Window PixelCopy is API 26; older devices use the WebView fallback.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(null)
            return
        }
        val window = activity.window
        val view = window?.decorView
        if (window == null || view == null || view.width == 0 || view.height == 0) {
            result.success(null)
            return
        }
        val w = width.coerceIn(16, view.width)
        val h = (view.height.toLong() * w / view.width).toInt().coerceAtLeast(16)
        // The window copy holds the WebView, its video and Flutter while
        // hybrid composition draws Flutter into the window. Once Weather Mood
        // hides the dashboard, Flutter draws into its own SurfaceView and the
        // window copy is transparent there, so that surface fills it in.
        val under = flutterSurface(view)?.let { surface ->
            val holder = surface.holder.surface
            if (!holder.isValid) return@let null
            val at = IntArray(2).also(surface::getLocationInWindow)
            val scale = w.toFloat() / view.width
            val left = (at[0] * scale).toInt()
            val top = (at[1] * scale).toInt()
            SurfaceLayer(
                holder,
                Rect(
                    left,
                    top,
                    left + (surface.width * scale).toInt().coerceAtLeast(1),
                    top + (surface.height * scale).toInt().coerceAtLeast(1),
                ),
            )
        }
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val main = Handler(Looper.getMainLooper())
        // On the capture thread: encode here, answer on the platform thread
        // (MethodChannel results must come from there).
        fun finish(frame: Bitmap?) {
            if (frame == null) {
                main.post { result.success(null) }
                return
            }
            val out = ByteArrayOutputStream()
            frame.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(1, 100), out)
            frame.recycle()
            main.post { result.success(out.toByteArray()) }
        }
        try {
            PixelCopy.request(window, bitmap, { status ->
                if (status != PixelCopy.SUCCESS) {
                    bitmap.recycle()
                    finish(null)
                } else if (under == null || !hasTransparency(bitmap)) {
                    finish(bitmap)
                } else {
                    underlay(bitmap, under, ::finish)
                }
            }, handler)
        } catch (_: Exception) {
            bitmap.recycle()
            result.success(null)
        }
    }

    /** Copy the Flutter surface and draw the window copy over it. */
    private fun underlay(window: Bitmap, layer: SurfaceLayer, finish: (Bitmap?) -> Unit) {
        val surface = Bitmap.createBitmap(
            layer.bounds.width(),
            layer.bounds.height(),
            Bitmap.Config.ARGB_8888,
        )
        try {
            PixelCopy.request(layer.surface, surface, { status ->
                if (status != PixelCopy.SUCCESS) {
                    surface.recycle()
                    finish(window)
                    return@request
                }
                val frame = Bitmap.createBitmap(window.width, window.height, Bitmap.Config.ARGB_8888)
                Canvas(frame).apply {
                    drawColor(Color.BLACK)
                    drawBitmap(surface, null, layer.bounds, null)
                    drawBitmap(window, 0f, 0f, null)
                }
                surface.recycle()
                window.recycle()
                finish(frame)
            }, handler)
        } catch (_: Exception) {
            surface.recycle()
            finish(window)
        }
    }

    private class SurfaceLayer(val surface: Surface, val bounds: Rect)
}

/** The Flutter SurfaceView, when one is on screen. Whether it supplies any
 * of the picture shows in the window copy: hybrid composition covers it
 * with an opaque window, a hidden dashboard leaves the window transparent.
 */
internal fun flutterSurface(root: View): FlutterSurfaceView? {
    if (!root.isShown || root.alpha <= 0f) return null
    if (root is FlutterView) {
        for (index in 0 until root.childCount) {
            val child = root.getChildAt(index)
            if (child is FlutterSurfaceView && child.isShown && child.alpha > 0f &&
                child.width > 0 && child.height > 0
            ) return child
        }
        return null
    }
    if (root is ViewGroup) {
        for (index in 0 until root.childCount) {
            flutterSurface(root.getChildAt(index))?.let { return it }
        }
    }
    return null
}

/** True when any pixel of [bitmap] lets a layer below it show through. */
internal fun hasTransparency(bitmap: Bitmap): Boolean {
    val row = IntArray(bitmap.width)
    for (y in 0 until bitmap.height) {
        bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
        for (pixel in row) {
            if (pixel ushr 24 != 0xFF) return true
        }
    }
    return false
}
