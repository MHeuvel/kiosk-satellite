package me.jxl.kiosk_satellite

import android.app.Application
import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowCameraCharacteristics

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, application = Application::class, sdk = [28])
class CameraFacingsTest {
    private val context: Context = RuntimeEnvironment.getApplication()

    private fun addCamera(id: String, facing: Int) {
        val characteristics = ShadowCameraCharacteristics.newCameraCharacteristics()
        shadowOf(characteristics).set(CameraCharacteristics.LENS_FACING, facing)
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        shadowOf(manager).addCamera(id, characteristics)
    }

    @Test
    fun countsAnExternalOnlyCamera() {
        // A Raspberry Pi whose only camera is a monitor's USB webcam.
        addCamera("100", CameraCharacteristics.LENS_FACING_EXTERNAL)
        assertEquals(listOf("external"), cameraFacings(context))
    }

    @Test
    fun listsEachFacingOnce() {
        addCamera("0", CameraCharacteristics.LENS_FACING_BACK)
        addCamera("1", CameraCharacteristics.LENS_FACING_FRONT)
        addCamera("2", CameraCharacteristics.LENS_FACING_EXTERNAL)
        addCamera("3", CameraCharacteristics.LENS_FACING_EXTERNAL)
        assertEquals(listOf("back", "front", "external"), cameraFacings(context))
    }

    @Test
    fun skipsAnUnknownFacing() {
        addCamera("0", CameraCharacteristics.LENS_FACING_FRONT)
        addCamera("1", 255)
        assertEquals(listOf("front"), cameraFacings(context))
    }
}
