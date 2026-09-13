package me.jxl.kiosk_satellite

import android.util.Log
import dev.steenbakker.mobile_scanner.MobileScannerPlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * The QR scanner plugin behind a guard for the one call of its that can
 * take the whole app down.
 *
 * mobile_scanner builds its preview and asks the engine for a surface
 * producer before it binds the camera. When the bind fails, which old
 * camera HALs do (a Nexus 7, a Lenovo Tab E10 and a StarView so far), the
 * producer exists but no surface was ever created in it. On Android 9 and
 * older the engine hands out a SurfaceTextureSurfaceProducer whose
 * release() calls surface.release() with no null check, so releasing that
 * producer throws. The plugin's own dispose runs inside a method call and
 * the engine swallows that one; the same release from
 * onDetachedFromActivity runs inside Activity.onDestroy and nothing
 * catches it, so the process dies with "Unable to destroy activity". That
 * is the setup wizard, on a device that just told the user the camera
 * could not be started, crashing when the wizard closes.
 *
 * The plugin class is final and the engine's release() is unguarded on
 * master too, so the guard lives here: the real plugin is registered
 * through this wrapper, which forwards everything and only catches the
 * detach. A detach that failed leaves one stale scanner behind (its texture
 * and its analysis thread); the next Activity gets a fresh handler from
 * the plugin regardless, so the scanner keeps working after it.
 */
class ScannerPluginShield<T>(private val inner: T) : FlutterPlugin, ActivityAware
    where T : FlutterPlugin, T : ActivityAware {

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) =
        inner.onAttachedToEngine(binding)

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) =
        inner.onDetachedFromEngine(binding)

    override fun onAttachedToActivity(binding: ActivityPluginBinding) =
        inner.onAttachedToActivity(binding)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        inner.onReattachedToActivityForConfigChanges(binding)

    override fun onDetachedFromActivity() =
        guarded("onDetachedFromActivity") { inner.onDetachedFromActivity() }

    override fun onDetachedFromActivityForConfigChanges() =
        guarded("onDetachedFromActivityForConfigChanges") {
            inner.onDetachedFromActivityForConfigChanges()
        }

    private fun guarded(what: String, block: () -> Unit) {
        try {
            block()
        } catch (e: RuntimeException) {
            // The Activity is going away either way; a scanner that cannot
            // let go of a surface it never got is not worth the process.
            Log.w(TAG, "scanner plugin failed in $what; ignored", e)
        }
    }

    companion object {
        private const val TAG = "ScannerPluginShield"

        /** Swap the registered plugin for a shielded one. Call right after
         *  GeneratedPluginRegistrant, before any Activity attaches. */
        fun install(engine: FlutterEngine) {
            engine.plugins.remove(MobileScannerPlugin::class.java)
            engine.plugins.add(ScannerPluginShield(MobileScannerPlugin()))
        }
    }
}
