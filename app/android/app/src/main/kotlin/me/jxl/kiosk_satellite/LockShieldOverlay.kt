package me.jxl.kiosk_satellite

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView

/**
 * Lockdown Mode's screen-level shield: a full-screen draw-over-apps window,
 * the same architecture Fully Kiosk uses for its maintenance lock.
 *
 * The Flutter LockdownShield guards only the app's own surface: anything
 * that gets out from under the Activity — a launched app, desktop mode, a
 * Home press that beats the reclaim watchdog — has a live screen until the
 * reclaim lands. This window covers the display itself. The launcher,
 * other apps and desktop-mode windows all sit behind it, untouchable, so
 * leaving the app stops being worth anything. Only true system windows
 * (the bars, the shade, the pin consent) draw above it, and those have
 * their own answers: the shield band and the System UI guard.
 *
 * On a Meta Portal with the System UI guard enabled, the shield is hosted
 * by the guard instead, as a TYPE_ACCESSIBILITY_OVERLAY. Meta's Control
 * Center draws its swipe-up strip and its panel as TYPE_KEYGUARD_DIALOG,
 * above the draw-over-apps window, so they took touches through the lock
 * (issue #857). The accessibility overlay sits above every system window.
 * It is limited to the Portal so other devices keep the shield they were
 * tested with. The shield moves between hosts as the guard connects and
 * disconnects ([rehost]).
 *
 * Owned by the process, not the Activity: the window is added with the
 * application context, so a task kill takes the kiosk Activity but never
 * the lock. The Activity-scoped KioskLock re-hooks [onTouch] on each
 * rebirth; between deaths the shield still blocks, it just does not count
 * exit taps until the kiosk is back (seconds, via the reclaim watchdog).
 *
 * [setPassThrough] briefly stops consuming touches so the exit gesture's
 * PIN dialog — ordinary Flutter UI underneath this window — can be typed
 * into. The window stays up throughout, it just lets touches fall
 * through to the app. Blackout stays black too, except on the guard's
 * overlay ([paint]).
 */
object LockShieldOverlay {
    private const val TAG = "LockShieldOverlay"
    private val main = Handler(Looper.getMainLooper())
    private var view: FrameLayout? = null
    private var pill: TextView? = null
    private var lockedText = "Screen is locked"

    /** Update the label without changing the shield or its touch handling. */
    fun setText(value: String) {
        lockedText = value
        pill?.text = value
    }
    private var hidePill: Runnable? = null
    private var blackout = false
    private var passThrough = false

    /// The context the window was added with: the guard while it is
    /// connected, the application context otherwise.
    private var host: Context? = null
    private var appContext: Context? = null
    private var wanted = false
    private val onPortal = Build.MANUFACTURER.equals("Facebook", true)

    /** KioskLock's exit-gesture counter; the Activity never sees these. */
    @Volatile
    var onTouch: ((MotionEvent) -> Unit)? = null

    /** Push the wanted state; adds, restyles or removes the window. */
    fun sync(context: Context, wanted: Boolean, black: Boolean) {
        appContext = context.applicationContext
        this.wanted = wanted
        if (!wanted) {
            remove()
            return
        }
        blackout = black
        if (view != null) {
            paint()
            return
        }
        val guard =
            if (onPortal) KioskAccessibilityService.instance else null
        val hostContext: Context = guard ?: context.applicationContext
        if (guard == null && !Settings.canDrawOverlays(context)) return
        passThrough = false
        val dm = hostContext.resources.displayMetrics
        fun dp(v: Float) = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, v, dm)

        val root = FrameLayout(hostContext)
        root.setBackgroundColor(if (black) Color.BLACK else Color.TRANSPARENT)

        // The acknowledgement pill, twin of the Flutter shield's: a tap on
        // a locked screen should read as locked, not broken.
        val text = TextView(hostContext)
        text.text = lockedText
        text.setTextColor(Color.WHITE)
        text.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14.5f)
        text.setPadding(
            dp(18f).toInt(), dp(10f).toInt(), dp(18f).toInt(), dp(10f).toInt())
        text.background = GradientDrawable().apply {
            setColor(0xB8000000.toInt())
            cornerRadius = dp(18f)
        }
        text.alpha = 0f
        val pillParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
        )
        pillParams.bottomMargin = (dm.heightPixels * 0.09).toInt()
        root.addView(text, pillParams)

        root.setOnTouchListener { v, ev ->
            if (ev.actionMasked == MotionEvent.ACTION_DOWN) showPill()
            if (ev.actionMasked == MotionEvent.ACTION_UP) v.performClick()
            onTouch?.invoke(ev)
            true
        }

        try {
            hostContext.getSystemService(WindowManager::class.java)
                .addView(root, params(guard != null))
            view = root
            pill = text
            host = hostContext
        } catch (e: Exception) {
            // A racing grant revocation; the Flutter shield still holds
            // inside the app and the reclaim watchdog holds outside it.
            Log.w(TAG, "the lockdown shield was refused: $e")
        }
    }

    /** Let touches through (the PIN dialog) without dropping the cover. */
    fun setPassThrough(value: Boolean) {
        val v = view ?: return
        val h = host ?: return
        if (passThrough == value) return
        passThrough = value
        try {
            h.getSystemService(WindowManager::class.java)
                .updateViewLayout(v, params(h is KioskAccessibilityService))
        } catch (_: Exception) {
        }
        paint()
    }

    /**
     * Blackout's black, except while the PIN dialog is up on the guard's
     * overlay: that window sits above the keyboard too, so a black shield
     * would leave the PIN to be typed blind. The draw-over-apps window sits
     * below the keyboard and keeps its black.
     */
    private fun paint() {
        val clear = passThrough && host is KioskAccessibilityService
        view?.setBackgroundColor(
            if (blackout && !clear) Color.BLACK else Color.TRANSPARENT)
    }

    /**
     * Move a standing shield to the host that now fits: onto the guard when
     * it connects, back to a draw-over-apps window when it goes (the system
     * drops the guard's windows with it). A shield that could not be added
     * for want of the overlay grant comes up once the guard connects.
     * Called by the guard.
     */
    fun rehost() {
        main.post {
            val ctx = appContext ?: return@post
            if (!wanted) return@post
            val keepPassThrough = passThrough
            remove()
            sync(ctx, true, blackout)
            if (keepPassThrough) setPassThrough(true)
        }
    }

    private fun params(accessibility: Boolean): WindowManager.LayoutParams {
        var flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        if (passThrough) {
            flags = flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        val p = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (accessibility) {
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
            } else {
                overlayWindowType()
            },
            flags,
            PixelFormat.TRANSLUCENT,
        )
        if (Build.VERSION.SDK_INT >= 30) {
            p.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        } else if (Build.VERSION.SDK_INT >= 28) {
            p.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams
                    .LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        return p
    }

    private fun showPill() {
        val p = pill ?: return
        hidePill?.let { main.removeCallbacks(it) }
        p.animate().alpha(1f).setDuration(250).start()
        val hide = Runnable {
            hidePill = null
            pill?.animate()?.alpha(0f)?.setDuration(250)?.start()
        }
        hidePill = hide
        main.postDelayed(hide, 1600)
    }

    private fun remove() {
        val v = view ?: return
        val h = host
        view = null
        pill = null
        host = null
        hidePill?.let { main.removeCallbacks(it) }
        hidePill = null
        try {
            h?.getSystemService(WindowManager::class.java)?.removeView(v)
        } catch (_: Exception) {
        }
    }
}
