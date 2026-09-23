package me.jxl.kiosk_satellite

import android.app.Activity
import android.app.Application
import android.view.SurfaceView
import android.view.View
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterView
import org.junit.After
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
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

    @Test fun standaloneFlutterUsesItsSurface() {
        assertSame(surface, flutterScreenshotSurface(root))
    }

    @Test fun hybridCompositionKeepsTheWindowUntilItsImageIsGone() {
        flutter.convertToImageView()
        val image = flutter.currentImageSurface!!
        image.alpha = 1f
        assertNull(flutterScreenshotSurface(root))

        image.alpha = 0f
        assertSame(surface, flutterScreenshotSurface(root))
    }

    @Test fun hiddenFlutterAndUnpaintedSurfacesAreNotCaptured() {
        flutter.visibility = View.INVISIBLE
        assertNull(flutterScreenshotSurface(root))
        flutter.visibility = View.VISIBLE
        surface.alpha = 0f
        assertNull(flutterScreenshotSurface(root))
        surface.alpha = 1f
        surface.layout(0, 0, 0, 0)
        assertNull(flutterScreenshotSurface(root))
    }

    @Test fun unrelatedSurfaceViewsDoNotReplaceTheWindow() {
        root.removeAllViews()
        val video = SurfaceView(root.context)
        root.addView(video)
        video.layout(0, 0, 1280, 800)
        assertNull(flutterScreenshotSurface(root))
    }
}
