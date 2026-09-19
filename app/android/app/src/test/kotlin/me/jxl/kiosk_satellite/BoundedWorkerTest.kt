package me.jxl.kiosk_satellite

import java.util.concurrent.CountDownLatch
import java.util.concurrent.ThreadFactory
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.*
import org.junit.Test

class BoundedWorkerTest {
    @Test fun blockedWorkHasAFixedBacklogAndReusesOneThread() {
        val starts = AtomicInteger()
        val worker = BoundedWorker("test", 2, ThreadFactory { task ->
            starts.incrementAndGet()
            Thread(task).apply { isDaemon = true }
        })
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val finished = CountDownLatch(3)
        val rejectedRan = AtomicInteger()
        try {
            assertTrue(worker.execute { entered.countDown(); release.await(); finished.countDown() })
            assertTrue(entered.await(3, TimeUnit.SECONDS))
            repeat(2) { assertTrue(worker.execute { finished.countDown() }) }
            repeat(1_000) { assertFalse(worker.execute { rejectedRan.incrementAndGet() }) }
            assertEquals(1, starts.get())
            release.countDown()
            assertTrue(finished.await(3, TimeUnit.SECONDS))
            repeat(20) {
                val done = CountDownLatch(1)
                assertTrue(worker.execute { done.countDown() })
                assertTrue(done.await(3, TimeUnit.SECONDS))
            }
            assertEquals(1, starts.get())
            assertEquals(0, rejectedRan.get())
        } finally {
            release.countDown()
            worker.shutdown()
        }
        assertFalse(worker.execute { fail("Work submitted after shutdown") })
    }

    @Test fun failedThreadCreationRejectsTheCallAndAllowsALaterRetry() {
        val attempts = AtomicInteger()
        val worker = BoundedWorker("test", 1, ThreadFactory { task ->
            if (attempts.getAndIncrement() == 0) throw OutOfMemoryError("pthread_create failed")
            Thread(task).apply { isDaemon = true }
        })
        try {
            assertFalse(worker.execute { fail("Rejected task must not be retained") })
            val done = CountDownLatch(1)
            assertTrue(worker.execute { done.countDown() })
            assertTrue(done.await(3, TimeUnit.SECONDS))
            assertEquals(2, attempts.get())
        } finally { worker.shutdown() }
    }

    @Test fun cancelingOldPendingWorkMakesRoomForTheNextSession() {
        val worker = BoundedWorker("test", 1)
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val finished = CountDownLatch(1)
        val canceledRan = AtomicInteger()
        try {
            assertTrue(worker.execute { entered.countDown(); release.await() })
            assertTrue(entered.await(3, TimeUnit.SECONDS))
            assertTrue(worker.execute { canceledRan.incrementAndGet() })
            worker.discardPending()
            assertTrue(worker.execute { finished.countDown() })
            release.countDown()
            assertTrue(finished.await(3, TimeUnit.SECONDS))
            assertEquals(0, canceledRan.get())
        } finally {
            release.countDown()
            worker.shutdown()
        }
    }
}
