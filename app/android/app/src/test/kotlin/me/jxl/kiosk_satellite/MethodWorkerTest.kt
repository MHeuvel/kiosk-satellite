package me.jxl.kiosk_satellite

import android.app.Application
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, application = Application::class, sdk = [28])
@LooperMode(LooperMode.Mode.PAUSED)
class MethodWorkerTest {
    private class Reply : MethodChannel.Result {
        var calls = 0
        var value: Any? = null
        var error: String? = null
        override fun success(result: Any?) {
            assertSame(Looper.getMainLooper(), Looper.myLooper())
            calls++
            value = result
        }
        override fun error(code: String, message: String?, details: Any?) {
            assertSame(Looper.getMainLooper(), Looper.myLooper())
            calls++
            error = code
        }
        override fun notImplemented() = fail("Unexpected reply")
    }

    @Test fun overloadAndReadFailuresReplyOnceAndAllowAnotherRead() {
        val worker = MethodWorker("test-query")
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val first = Reply()
        val second = Reply()
        try {
            worker.read(first) { entered.countDown(); release.await(); 42 }
            assertTrue(entered.await(3, TimeUnit.SECONDS))
            worker.read(second) { throw IllegalStateException("read failed") }
            repeat(100) {
                val busy = Reply()
                worker.read(busy) { fail("Rejected operation ran") }
                assertEquals("busy", busy.error)
                assertEquals(1, busy.calls)
            }
            release.countDown()
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(3)
            while (second.calls == 0 && System.nanoTime() < deadline) {
                shadowOf(Looper.getMainLooper()).idle()
                Thread.sleep(5)
            }
            assertEquals(42, first.value)
            assertEquals(1, first.calls)
            assertEquals("read_failed", second.error)
            assertEquals(1, second.calls)
            val next = Reply()
            worker.read(next) { null }
            val retryDeadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(3)
            while (next.calls == 0 && System.nanoTime() < retryDeadline) {
                shadowOf(Looper.getMainLooper()).idle()
                Thread.sleep(5)
            }
            assertEquals(1, next.calls)
            assertNull(next.error)
        } finally {
            release.countDown()
            worker.shutdown()
        }
    }
}
