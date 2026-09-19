package me.jxl.kiosk_satellite

import android.app.Application
import android.os.Looper
import java.net.DatagramPacket
import java.net.MulticastSocket
import java.net.SocketException
import java.time.Duration
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import me.jxl.kiosk_satellite.btproxy.MdnsAnnouncer
import me.jxl.kiosk_satellite.btproxy.ProxyIdentity
import me.jxl.kiosk_satellite.fleet.FleetDiscovery
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, application = Application::class, sdk = [28])
@LooperMode(LooperMode.Mode.PAUSED)
class MdnsLifecycleTest {
    private class Socket : MulticastSocket(0) {
        val receiving = CountDownLatch(1)
        val receivedExit = CountDownLatch(1)
        val sending = CountDownLatch(1)
        val closed = CountDownLatch(1)
        @Volatile var blockSend = false

        override fun send(packet: DatagramPacket) {
            if (blockSend) {
                sending.countDown()
                check(closed.await(5, TimeUnit.SECONDS))
            }
            if (isClosed) throw SocketException("closed")
        }

        override fun receive(packet: DatagramPacket) {
            receiving.countDown()
            try {
                check(closed.await(5, TimeUnit.SECONDS))
                throw SocketException("closed")
            } finally { receivedExit.countDown() }
        }

        override fun close() {
            super.close()
            closed.countDown()
        }
    }

    private class Harness(fleet: Boolean, factory: (Int) -> MulticastSocket) {
        private val context = RuntimeEnvironment.getApplication()
        private val discovery = if (fleet) FleetDiscovery(context, factory) {} else null
        private val announcer = if (fleet) null else MdnsAnnouncer(
            context, ProxyIdentity("test", "Test", "AA:BB:CC:DD:EE:FF", "2026.1.0", "test", "test", "test", "1"), 8123, openSocket = factory,
        )
        private val owner: Any = discovery ?: announcer!!
        fun start() { discovery?.start("Test", 8123, "test") ?: announcer!!.start() }
        fun stop() { discovery?.stop() ?: announcer!!.stop() }
        fun nudge() { discovery?.nudge() ?: announcer!!.nudge() }
        fun socket(): Any? = owner.javaClass.getDeclaredField("socket").let {
            it.isAccessible = true
            it.get(owner)
        }
    }

    private fun await(condition: () -> Boolean) {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5)
        while (System.nanoTime() < deadline) {
            shadowOf(Looper.getMainLooper()).idle()
            if (condition()) return
            Thread.sleep(5)
        }
        fail("Asynchronous mDNS work did not finish")
    }

    @Test fun initializationCompletingAfterStopClosesItsOwnSocket() {
        for (fleet in listOf(true, false)) {
            val old = Socket()
            val replacement = Socket()
            val opening = CountDownLatch(1)
            val release = CountDownLatch(1)
            val calls = AtomicInteger()
            val harness = Harness(fleet) {
                if (calls.getAndIncrement() == 0) {
                    opening.countDown()
                    check(release.await(5, TimeUnit.SECONDS))
                    old
                } else replacement
            }
            try {
                harness.start()
                assertTrue(opening.await(3, TimeUnit.SECONDS))
                harness.stop()
                harness.start()
                release.countDown()
                await { old.isClosed && harness.socket() === replacement }
                assertFalse(replacement.isClosed)
                assertEquals(1L, old.receiving.count)
                if (fleet) assertTrue(replacement.receiving.await(3, TimeUnit.SECONDS))
            } finally {
                release.countDown()
                harness.stop()
                shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(300))
                old.close()
                replacement.close()
            }
        }
    }

    @Test fun blockedSendIsReleasedByCleanupWithoutClosingTheReplacement() {
        for (fleet in listOf(true, false)) {
            val old = Socket()
            val replacement = Socket()
            val calls = AtomicInteger()
            val harness = Harness(fleet) { if (calls.getAndIncrement() == 0) old else replacement }
            try {
                harness.start()
                await { harness.socket() === old }
                if (fleet) assertTrue(old.receiving.await(3, TimeUnit.SECONDS))
                old.blockSend = true
                harness.nudge()
                assertTrue(old.sending.await(3, TimeUnit.SECONDS))
                harness.stop()
                harness.start()
                shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(300))
                await { harness.socket() === replacement }
                assertTrue(old.isClosed)
                assertFalse(replacement.isClosed)
                if (fleet) {
                    assertTrue(old.receivedExit.await(3, TimeUnit.SECONDS))
                    assertTrue(replacement.receiving.await(3, TimeUnit.SECONDS))
                }
                shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2))
                assertSame(replacement, harness.socket())
                assertFalse(replacement.isClosed)
            } finally {
                harness.stop()
                shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(300))
                old.close()
                replacement.close()
            }
        }
    }
}
