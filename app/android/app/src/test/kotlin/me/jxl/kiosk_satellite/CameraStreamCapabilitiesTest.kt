package me.jxl.kiosk_satellite

import android.app.Application
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.Rect
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.util.Range
import android.util.Size
import android.util.SizeF
import android.view.Surface
import androidx.camera.camera2.Camera2Config
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowCameraCharacteristics
import org.robolectric.shadows.ShadowLog
import org.robolectric.shadows.StreamConfigurationMapBuilder

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, application = Application::class, sdk = [28])
class CameraStreamCapabilitiesTest {
    private lateinit var provider: ProcessCameraProvider
    private lateinit var capabilities: CameraStreamCapabilities
    private val size = Size(640, 480)
    private val captures = mutableListOf<ImageCapture>()

    @Before fun setUp() {
        val context = RuntimeEnvironment.getApplication()
        val characteristics = ShadowCameraCharacteristics.newCameraCharacteristics()
        val shadow = shadowOf(characteristics)
        shadow.set(CameraCharacteristics.LENS_FACING, CameraCharacteristics.LENS_FACING_BACK)
        shadow.set(CameraCharacteristics.SENSOR_ORIENTATION, 90)
        shadow.set(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL,
            CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY)
        shadow.set(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES,
            intArrayOf(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_BACKWARD_COMPATIBLE))
        shadow.set(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE, Rect(0, 0, 640, 480))
        shadow.set(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE, size)
        shadow.set(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE, SizeF(4f, 3f))
        shadow.set(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS, floatArrayOf(3f))
        shadow.set(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES, arrayOf(Range(15, 30)))
        shadow.set(CameraCharacteristics.CONTROL_MAX_REGIONS_AF, 0)
        shadow.set(CameraCharacteristics.FLASH_INFO_AVAILABLE, false)
        shadow.set(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM, 1f)
        shadow.set(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP,
            StreamConfigurationMapBuilder.newBuilder()
                .addOutputSize(size)
                .addOutputSize(ImageFormat.YUV_420_888, size)
                // StreamConfigurationMap stores JPEG as the HAL BLOB format.
                .addOutputSize(0x21, size)
                .build())
        shadowOf(context.getSystemService(Context.CAMERA_SERVICE) as CameraManager)
            .addCamera("0", characteristics)
        ProcessCameraProvider.configureInstance(Camera2Config.defaultConfig())
        provider = ProcessCameraProvider.getInstance(context).get(10, TimeUnit.SECONDS)
        capabilities = CameraStreamCapabilities(context) {
            ImageCapture.Builder()
                .setResolutionSelector(videoResolutionSelector(size, exact = true))
                .build().also { captures.add(it) }
        }
    }

    @After fun tearDown() {
        ProcessCameraProvider.shutdown().get(10, TimeUnit.SECONDS)
    }

    private fun accepts(size: Size = this.size, analysis: Boolean = false): Boolean {
        val method = CameraStreamCapabilities::class.java.getDeclaredMethod(
            "accepts", ProcessCameraProvider::class.java, CameraSelector::class.java,
            Size::class.java, Size::class.java, Int::class.javaPrimitiveType,
            Boolean::class.javaPrimitiveType,
        ).apply { isAccessible = true }
        return method.invoke(capabilities, provider, CameraSelector.DEFAULT_BACK_CAMERA,
            size, this.size, Surface.ROTATION_0, analysis) as Boolean
    }

    @Test fun repeatedProbesReleaseTheirUseCasesWithoutInvalidCameraWarnings() {
        repeat(8) {
            assertTrue(accepts())
            assertTrue(accepts(analysis = true))
        }
        assertEquals(8, captures.size)
        assertTrue(captures.none { provider.isBound(it) })
        assertTrue(ShadowLog.getLogsForTag("LifecycleCameraRepository").none {
            it.msg.contains("invalid camera")
        })
    }

    @Test fun rejectedProbeDoesNotBreakLaterProbesOrAnotherOwner() {
        val owner = object : LifecycleOwner {
            val registry = LifecycleRegistry(this).apply { currentState = Lifecycle.State.CREATED }
            override val lifecycle: Lifecycle get() = registry
        }
        val preview = Preview.Builder()
            .setResolutionSelector(videoResolutionSelector(size, exact = true)).build()
        provider.bindToLifecycle(owner, CameraSelector.DEFAULT_BACK_CAMERA, preview)
        try {
            assertFalse(accepts(Size(123, 456)))
            assertTrue(accepts())
            assertTrue(provider.isBound(preview))
            assertTrue(ShadowLog.getLogsForTag("LifecycleCameraRepository").none {
                it.msg.contains("invalid camera")
            })
        } finally {
            owner.registry.currentState = Lifecycle.State.DESTROYED
        }
        assertFalse(provider.isBound(preview))
    }

    @Test fun snapshotLifecycleDestructionReleasesCaptureWithoutExplicitUnbind() {
        repeat(8) {
            val owner = CameraLifecycle()
            val capture = ImageCapture.Builder()
                .setResolutionSelector(videoResolutionSelector(size, exact = true)).build()
            provider.bindToLifecycle(owner, CameraSelector.DEFAULT_BACK_CAMERA, capture)
            assertTrue(provider.isBound(capture))
            owner.destroy()
            assertFalse(provider.isBound(capture))
            assertEquals(Lifecycle.State.DESTROYED, owner.lifecycle.currentState)
        }
        assertTrue(ShadowLog.getLogsForTag("LifecycleCameraRepository").none {
            it.msg.contains("invalid camera")
        })
    }
}
