package io.flutter.plugins.imagepicker

import android.app.Activity
import android.app.Application
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import java.io.File
import java.util.concurrent.AbstractExecutorService
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, application = Application::class, sdk = [29, 33])
class ImagePickerLaunchTest {
    class PickerActivity : Activity() {
        var failure: RuntimeException? = null
        var requestCode = 0
        var launches = 0

        override fun startActivityForResult(intent: Intent, requestCode: Int) {
            this.requestCode = requestCode
            launches++
            failure?.let { throw it }
        }
    }

    private class InlineExecutor : AbstractExecutorService() {
        override fun execute(command: Runnable) = command.run()
        override fun shutdown() {}
        override fun shutdownNow(): MutableList<Runnable> = mutableListOf()
        override fun isShutdown() = false
        override fun isTerminated() = false
        override fun awaitTermination(timeout: Long, unit: TimeUnit) = true
    }

    private fun delegate(activity: Activity) = ImagePickerDelegate(
        activity, ImageResizer(activity, ExifDataCopier()), null, null, null,
        ImagePickerCache(activity), null, null, FileUtils(), InlineExecutor(),
    )

    private fun launch(
        delegate: ImagePickerDelegate,
        kind: String,
        photoPicker: Boolean,
        reply: (Result<List<String>>) -> Unit,
    ) {
        val images = ImageSelectionOptions(null, null, 100)
        val videos = VideoSelectionOptions(null)
        when (kind) {
            "image" -> delegate.chooseImageFromGallery(images, photoPicker, reply)
            "images" -> delegate.chooseMultiImageFromGallery(images, photoPicker, 5, reply)
            "video" -> delegate.chooseVideoFromGallery(videos, photoPicker, reply)
            "videos" -> delegate.chooseMultiVideoFromGallery(videos, photoPicker, 5, reply)
            "media" -> delegate.chooseMediaFromGallery(
                MediaSelectionOptions(images), GeneralOptions(true, photoPicker, 5), reply,
            )
            else -> error("Unknown picker: $kind")
        }
    }

    private fun forEachPicker(test: (ImagePickerDelegate, PickerActivity, String, Boolean) -> Unit) {
        for (kind in listOf("image", "images", "video", "videos", "media")) {
            for (photoPicker in listOf(false, true)) {
                val controller = Robolectric.buildActivity(PickerActivity::class.java).setup()
                try {
                    val activity = controller.get()
                    test(delegate(activity), activity, kind, photoPicker)
                } finally {
                    controller.pause().stop().destroy()
                }
            }
        }
    }

    @Test fun missingPickerRepliesOnceDespiteLateCancellationAndAllowsRetry() {
        checkFailedLaunch(ActivityNotFoundException("No picker installed"), "activity_not_found")
    }

    @Test fun deniedPickerRepliesOnceDespiteLateCancellationAndAllowsRetry() {
        checkFailedLaunch(SecurityException("Picker access denied"), "picker_access_denied")
    }

    private fun checkFailedLaunch(failure: RuntimeException, code: String) = forEachPicker {
            delegate, activity, kind, photoPicker ->
        activity.failure = failure
        val replies = mutableListOf<Result<List<String>>>()
        launch(delegate, kind, photoPicker) {
            check(replies.isEmpty()) { "Reply already submitted" }
            replies += it
        }
        assertEquals("$kind must report the launch failure", 1, replies.size)
        val error = replies.single().exceptionOrNull() as FlutterError
        assertEquals(code, error.code)

        // Android can send cancellation even though startActivityForResult threw.
        delegate.onActivityResult(activity.requestCode, Activity.RESULT_CANCELED, null)
        delegate.onActivityResult(activity.requestCode, Activity.RESULT_CANCELED, null)
        assertEquals(1, replies.size)
        assertNull(delegate.retrieveLostImage())

        activity.failure = null
        val retryReplies = mutableListOf<Result<List<String>>>()
        launch(delegate, kind, photoPicker) { retryReplies += it }
        assertEquals(2, activity.launches)
        assertTrue(retryReplies.isEmpty())
        delegate.onActivityResult(activity.requestCode, Activity.RESULT_CANCELED, null)
        assertEquals(emptyList<String>(), retryReplies.single().getOrThrow())
    }

    @Test fun failedLaunchAllowsRetryEvenWithoutAnAndroidCancellation() = forEachPicker {
            delegate, activity, kind, photoPicker ->
        activity.failure = ActivityNotFoundException()
        val first = mutableListOf<Result<List<String>>>()
        launch(delegate, kind, photoPicker) { first += it }
        assertTrue(first.single().isFailure)

        activity.failure = null
        val retry = mutableListOf<Result<List<String>>>()
        launch(delegate, kind, photoPicker) { retry += it }
        assertEquals(2, activity.launches)
        assertTrue(retry.isEmpty())
        delegate.onActivityResult(activity.requestCode, Activity.RESULT_CANCELED, null)
        assertEquals(emptyList<String>(), retry.single().getOrThrow())
    }

    @Test fun normalCancellationRepliesOnceAndConcurrentPickKeepsOriginalRequest() = forEachPicker {
            delegate, activity, kind, photoPicker ->
        val first = mutableListOf<Result<List<String>>>()
        launch(delegate, kind, photoPicker) { first += it }
        val second = mutableListOf<Result<List<String>>>()
        launch(delegate, kind, photoPicker) { second += it }
        assertEquals("already_active", (second.single().exceptionOrNull() as FlutterError).code)
        assertEquals(1, activity.launches)
        assertTrue(first.isEmpty())
        delegate.onActivityResult(activity.requestCode, Activity.RESULT_CANCELED, null)
        delegate.onActivityResult(activity.requestCode, Activity.RESULT_CANCELED, null)
        assertEquals(emptyList<String>(), first.single().getOrThrow())
        assertEquals(1, second.size)
    }

    @Test fun unrelatedLaunchErrorsAreNotSuppressed() = forEachPicker {
            delegate, activity, kind, photoPicker ->
        activity.failure = IllegalStateException("Unexpected failure")
        assertThrows(IllegalStateException::class.java) {
            launch(delegate, kind, photoPicker) { fail("Unexpected callback") }
        }
    }

    @Test fun selectedFileStillReturnsItsCopiedContents() = forEachPicker {
            delegate, activity, kind, photoPicker ->
        val input = File.createTempFile("picker", ".jpg", activity.cacheDir)
        val bytes = byteArrayOf(1, 2, 3, 4)
        input.writeBytes(bytes)
        val replies = mutableListOf<Result<List<String>>>()
        launch(delegate, kind, photoPicker) { replies += it }
        assertTrue(replies.isEmpty())
        delegate.onActivityResult(
            activity.requestCode, Activity.RESULT_OK, Intent().setData(Uri.fromFile(input)),
        )
        val copied = File(replies.single().getOrThrow().single())
        assertNotEquals(input.absolutePath, copied.absolutePath)
        assertArrayEquals(bytes, copied.readBytes())
    }
}
