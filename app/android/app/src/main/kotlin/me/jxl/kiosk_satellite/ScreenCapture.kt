package me.jxl.kiosk_satellite

import android.app.Activity
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.view.PixelCopy
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Captures the active Flutter surface or the composed Android window via
 * [PixelCopy], including the WebView, menus and screensaver. The GPU copy
 * never draws on the main thread. The WebView plugin's takeScreenshot renders
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
        // Hybrid composition puts Flutter and the WebView in the window.
        // Once Weather Mood hides the dashboard, Flutter returns to its
        // separate SurfaceView. Copying the window then succeeds with black.
        val flutterSurface = flutterScreenshotSurface(view)
        if (flutterSurface != null && !flutterSurface.holder.surface.isValid) {
            result.success(null)
            return
        }
        val source = flutterSurface ?: view
        val w = width.coerceIn(16, source.width.coerceAtLeast(16))
        val h = (source.height.toLong() * w / source.width).toInt().coerceAtLeast(16)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val main = Handler(Looper.getMainLooper())
        try {
            val copied = PixelCopy.OnPixelCopyFinishedListener { status ->
                // On the capture thread: encode here, answer on the platform
                // thread (MethodChannel results must come from there).
                if (status != PixelCopy.SUCCESS) {
                    bitmap.recycle()
                    main.post { result.success(null) }
                    return@OnPixelCopyFinishedListener
                }
                val out = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(1, 100), out)
                bitmap.recycle()
                main.post { result.success(out.toByteArray()) }
            }
            if (flutterSurface != null) {
                PixelCopy.request(flutterSurface, bitmap, copied, handler)
            } else {
                PixelCopy.request(window, bitmap, copied, handler)
            }
        } catch (_: Exception) {
            bitmap.recycle()
            result.success(null)
        }
    }
}

/** Select the standalone Flutter surface only while it supplies the picture.
 * During hybrid composition and its transition back, the visible image
 * surface belongs to the window and must be captured with the platform views.
 */
internal fun flutterScreenshotSurface(root: View): FlutterSurfaceView? {
    if (!root.isShown || root.alpha <= 0f) return null
    if (root is FlutterView) {
        val image = root.currentImageSurface
        if (image != null && image.isShown && image.alpha > 0f) return null
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
            flutterScreenshotSurface(root.getChildAt(index))?.let { return it }
        }
    }
    return null
}
