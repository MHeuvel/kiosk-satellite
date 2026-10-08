package me.jxl.kiosk_satellite.btproxy

import android.app.Application
import android.os.Looper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE, application = Application::class)
class BleScanEngineLifecycleTest {
    @Test
    fun packageReplacementPauseRetainsDemandUntilFailedInstallResumes() {
        val states = mutableListOf<ScannerState>()
        val engine = BleScanEngine(
            RuntimeEnvironment.getApplication(),
            onAdvertisement = {},
            onStateChange = { state, _ -> states += state },
        )

        assertTrue(engine.pauseForPackageReplacement())
        assertEquals(listOf(ScannerState.STOPPING), states)

        engine.requestStart(ScannerMode.PASSIVE)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf(ScannerState.STOPPING), states)

        engine.resumeAfterPackageReplacementFailure()
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(states.size > 1)
        assertNotEquals(ScannerState.STOPPING, states.last())

        engine.shutdown()
        shadowOf(Looper.getMainLooper()).idle()
    }
}
