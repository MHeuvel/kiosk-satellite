package me.jxl.kiosk_satellite

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import android.app.Application
import java.lang.reflect.Proxy

/**
 * The shield forwards every plugin callback and only ever swallows a
 * failing detach: the call the engine makes from Activity.onDestroy, where
 * mobile_scanner's surface release throws on old camera HALs.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, application = Application::class)
class ScannerPluginShieldTest {
    private class Inner(private val failDetach: Boolean) : FlutterPlugin, ActivityAware {
        val calls = mutableListOf<String>()
        override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) { calls += "engine+" }
        override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { calls += "engine-" }
        override fun onAttachedToActivity(binding: ActivityPluginBinding) { calls += "activity+" }
        override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { calls += "activity~" }
        override fun onDetachedFromActivity() {
            calls += "activity-"
            if (failDetach) throw NullPointerException("Attempt to invoke virtual method 'void android.view.Surface.release()' on a null object reference")
        }
        override fun onDetachedFromActivityForConfigChanges() {
            calls += "activity-config"
            if (failDetach) throw NullPointerException("surface")
        }
    }

    private val binding: ActivityPluginBinding = Proxy.newProxyInstance(
        ActivityPluginBinding::class.java.classLoader,
        arrayOf(ActivityPluginBinding::class.java),
    ) { _, _, _ -> null } as ActivityPluginBinding

    @Test fun aFailingDetachIsSwallowedAndTheRestForwarded() {
        val inner = Inner(failDetach = true)
        val shield = ScannerPluginShield(inner)
        shield.onAttachedToActivity(binding)
        shield.onDetachedFromActivity()
        shield.onReattachedToActivityForConfigChanges(binding)
        shield.onDetachedFromActivityForConfigChanges()
        assertEquals(listOf("activity+", "activity-", "activity~", "activity-config"), inner.calls)
    }

    @Test fun aHealthyPluginIsUntouched() {
        val inner = Inner(failDetach = false)
        val shield = ScannerPluginShield(inner)
        shield.onAttachedToActivity(binding)
        shield.onDetachedFromActivity()
        assertEquals(listOf("activity+", "activity-"), inner.calls)
    }
}
