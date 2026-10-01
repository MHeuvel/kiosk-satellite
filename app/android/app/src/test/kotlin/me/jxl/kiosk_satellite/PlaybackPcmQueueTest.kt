package me.jxl.kiosk_satellite

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

class PlaybackPcmQueueTest {
    @Test fun interruptedChunkCannotResumeAfterItWasDequeued() {
        val queue = PlaybackPcmQueue()
        queue.offer(byteArrayOf(1, 2, 3, 4))
        val old = queue.poll()!!
        assertEquals(2, queue.write(old) { 2 })
        queue.clear()
        queue.offer(byteArrayOf(5, 6))
        assertNull(queue.write(old) { fail("Discarded audio reached the track"); 0 })
        assertEquals(2, queue.write(queue.poll()!!) { assertArrayEquals(byteArrayOf(5, 6), it); it.size })
    }

    @Test fun fullTrackRetryDoesNotReviveAFlushedAnswer() {
        val queue = PlaybackPcmQueue()
        queue.offer(byteArrayOf(1, 2))
        val chunk = queue.poll()!!
        assertEquals(0, queue.write(chunk) { 0 })
        queue.clear()
        assertNull(queue.write(chunk) { fail("Retry wrote the old answer"); 0 })
    }

    @Test fun flushCannotSplitTheTrackWriteFromTheReferenceWrite() {
        val queue = PlaybackPcmQueue()
        queue.offer(byteArrayOf(1, 2))
        val chunk = queue.poll()!!
        val entered = CountDownLatch(1)
        val finish = CountDownLatch(1)
        val flushRequested = CountDownLatch(1)
        val events = mutableListOf<String>()
        val writer = thread {
            queue.write(chunk) {
                events.add("track")
                entered.countDown()
                check(finish.await(5, TimeUnit.SECONDS))
                events.add("reference")
                it.size
            }
        }
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        val flusher = thread {
            flushRequested.countDown()
            synchronized(queue.lock) {
                queue.clear()
                events.add("flush")
            }
        }
        assertTrue(flushRequested.await(5, TimeUnit.SECONDS))
        finish.countDown()
        writer.join(5000)
        flusher.join(5000)
        assertFalse(writer.isAlive)
        assertFalse(flusher.isAlive)
        assertEquals(listOf("track", "reference", "flush"), events)
        assertNull(queue.write(chunk) { fail("Old answer survived flush"); 0 })
    }
}
