package me.jxl.kiosk_satellite

import android.app.Activity
import android.content.pm.ActivityInfo

/**
 * Applies the "Screen orientation" setting (screen.orientation) to an
 * Activity.
 *
 * Automatic hands the choice back to the system: the rotation sensor where
 * the device has one, the boot orientation where it does not. The forced
 * modes pin the window one way regardless, which is the whole point for a
 * panel with no sensor or one mounted a way the sensor misreads (issue
 * #541). The manifest lists orientation and screenSize under configChanges,
 * so a runtime change turns the window in place without re-creating the
 * Activity, and the dashboard WebView reflows for the new size.
 *
 * Called from MainActivity.onCreate with the SharedPreferences mirror of
 * the setting (right from the first frame), and from KioskLock.apply when
 * the setting changes at runtime.
 */
object ScreenOrientation {
    fun apply(activity: Activity, mode: String) {
        val wanted = when (mode) {
            "landscape" -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            "reverse_landscape" -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
            "portrait" -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            "reverse_portrait" -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT
            else -> ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        // A no-op request still costs a relayout pass; skip it.
        if (activity.requestedOrientation != wanted) {
            activity.requestedOrientation = wanted
        }
    }
}
