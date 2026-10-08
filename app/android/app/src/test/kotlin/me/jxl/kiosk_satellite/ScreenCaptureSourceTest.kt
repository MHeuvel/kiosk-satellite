package me.jxl.kiosk_satellite

import android.app.Activity
import android.app.Application
import android.graphics.Bitmap
import android.graphics.Color
import android.view.SurfaceView
import android.view.View
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterView
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE, application = Application::class)
class ScreenCaptureSourceTest {
    private val controller = Robolectric.buildActivity(Activity::class.java)
    private lateinit var root: FrameLayout
    private lateinit var surface: FlutterSurfaceView
    private lateinit var flutter: FlutterView

    @Before fun setUp() {
        val activity = controller.setup().visible().get()
        root = FrameLayout(activity)
        surface = FlutterSurfaceView(activity)
        flutter = FlutterView(activity, surface)
        root.addView(flutter)
        activity.setContentView(root)
        root.layout(0, 0, 1280, 800)
        flutter.layout(0, 0, 1280, 800)
        surface.layout(0, 0, 1280, 800)
        surface.alpha = 1f
    }

    @After fun tearDown() {
        flutter.currentImageSurface?.closeImageReader()
        controller.pause().stop().destroy()
    }

    @Test fun findsTheFlutterSurface() {
        assertEquals(listOf(surface), surfaceLayers(root))
    }

    @Test fun hybridCompositionStillOffersTheSurface() {
        // The window copy decides whether it shows: an opaque window from
        // hybrid composition covers it completely.
        flutter.convertToImageView()
        assertEquals(listOf(surface), surfaceLayers(root))
    }

    @Test fun hiddenFlutterAndUnpaintedSurfacesAreNotCaptured() {
        flutter.visibility = View.INVISIBLE
        assertTrue(surfaceLayers(root).isEmpty())
        flutter.visibility = View.VISIBLE
        surface.alpha = 0f
        assertTrue(surfaceLayers(root).isEmpty())
        surface.alpha = 1f
        surface.layout(0, 0, 0, 0)
        assertTrue(surfaceLayers(root).isEmpty())
    }

    // Issue #894: a video on a platform view is a SurfaceView of its own,
    // which the window copy shows only as a hole.
    @Test fun aPlatformViewVideoComesAboveFlutter() {
        val holder = FrameLayout(root.context)
        val video = SurfaceView(root.context)
        holder.addView(video)
        flutter.addView(holder)
        holder.layout(0, 100, 1280, 700)
        video.layout(0, 0, 1280, 600)
        assertEquals(listOf(surface, video), surfaceLayers(root))
        holder.visibility = View.GONE
        assertEquals(listOf(surface), surfaceLayers(root))
    }

    @Test fun opaqueWindowNeedsNoUnderlay() {
        val bitmap = Bitmap.createBitmap(32, 20, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.BLACK)
        assertFalse(hasTransparency(bitmap))
    }

    @Test fun anyTransparentPixelNeedsTheUnderlay() {
        val bitmap = Bitmap.createBitmap(32, 20, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.BLACK)
        bitmap.setPixel(31, 19, Color.TRANSPARENT)
        assertTrue(hasTransparency(bitmap))
    }
}
