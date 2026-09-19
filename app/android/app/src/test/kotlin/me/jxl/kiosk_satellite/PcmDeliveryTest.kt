package me.jxl.kiosk_satellite

import java.util.ArrayDeque
import org.junit.Assert.*
import org.junit.Test

class PcmDeliveryTest {
    private class PlatformQueue {
        val tasks = ArrayDeque<Runnable>()
        var maxTasks = 0
        fun post(task: Runnable): Boolean {
            tasks.addLast(task)
            maxTasks = maxOf(maxTasks, tasks.size)
            return true
        }
        fun remove(task: Runnable) { tasks.removeAll { it === task } }
        fun drain() { while (tasks.isNotEmpty()) tasks.removeFirst().run() }
    }

    @Test fun anHourOfStalledDeliveryRetainsOnlyTheLatest320Milliseconds() {
        val platform = PlatformQueue()
        val received = mutableListOf<Int>()
        val delivery = PcmDelivery(4 * 2560, platform::post, platform::remove) {
            received.add(it[0].toInt() and 255)
        }
        // 45,000 normal chunks are an hour of capture and 115 MB of PCM.
        // None of the platform callbacks run until all chunks are offered.
        repeat(45_000) { delivery.offer(ByteArray(2560).also { pcm -> pcm[0] = it.toByte() }) }
        assertEquals(1, platform.tasks.size)
        assertEquals(44_996L, delivery.droppedChunks)
        platform.drain()
        assertEquals((44_996 until 45_000).map { it and 255 }, received)
        assertEquals(1, platform.maxTasks)
        assertTrue(delivery.isOpen)
    }

    @Test fun normalDeliveryPreservesEveryByteAndItsOrder() {
        val platform = PlatformQueue()
        val received = mutableListOf<ByteArray>()
        val delivery = PcmDelivery(10_240, platform::post, platform::remove, received::add)
        val chunks = listOf(byteArrayOf(1, 2, 3, 4), byteArrayOf(5, 6), byteArrayOf(7, 8))
        chunks.forEach { delivery.offer(it); platform.drain() }
        assertEquals(chunks.size, received.size)
        chunks.zip(received).forEach { (expected, actual) -> assertArrayEquals(expected, actual) }
        assertEquals(0L, delivery.droppedChunks)
    }

    @Test fun theLimitCountsBytesIncludingShortReadsAndRejectsOversizedChunks() {
        val platform = PlatformQueue()
        val received = mutableListOf<Int>()
        val delivery = PcmDelivery(10, platform::post, platform::remove) { received.add(it.size) }
        delivery.offer(ByteArray(4))
        delivery.offer(ByteArray(4))
        delivery.offer(ByteArray(6))
        delivery.offer(ByteArray(11))
        delivery.offer(ByteArray(0))
        platform.drain()
        assertEquals(listOf(4, 6), received)
        assertEquals(2L, delivery.droppedChunks)
    }

    @Test fun canceledCaptureCannotDeliverIntoAReplacementSession() {
        val platform = PlatformQueue()
        val received = mutableListOf<String>()
        val old = PcmDelivery(10, platform::post, platform::remove) { received.add("old") }
        old.offer(byteArrayOf(1, 2))
        val alreadyDequeued = platform.tasks.first()
        old.close()
        assertTrue(platform.tasks.isEmpty())
        val current = PcmDelivery(10, platform::post, platform::remove) { received.add("new") }
        current.offer(byteArrayOf(3, 4))
        // A late read and a callback already taken by the platform both
        // belong to the closed delivery even after capture opens again.
        old.offer(byteArrayOf(5, 6))
        alreadyDequeued.run()
        platform.drain()
        assertEquals(listOf("new"), received)
        assertFalse(old.isOpen)
        assertTrue(current.isOpen)
    }

    @Test fun captureContinuingDuringDeliveryCannotFloodThePlatformQueue() {
        val platform = PlatformQueue()
        val received = mutableListOf<Int>()
        lateinit var delivery: PcmDelivery
        delivery = PcmDelivery(8, platform::post, platform::remove) {
            received.add(it[0].toInt() and 255)
            if (received.size == 1) {
                repeat(100) { n -> delivery.offer(byteArrayOf((n + 1).toByte(), 0)) }
                assertTrue(platform.tasks.isEmpty())
            }
        }
        delivery.offer(byteArrayOf(0, 0))
        platform.drain()
        assertEquals(listOf(0, 97, 98, 99, 100), received)
        assertEquals(1, platform.maxTasks)
    }

    @Test fun cancellationDuringDeliveryDiscardsTheRest() {
        val platform = PlatformQueue()
        var received = 0
        lateinit var delivery: PcmDelivery
        delivery = PcmDelivery(10, platform::post, platform::remove) {
            received++
            delivery.close()
        }
        repeat(4) { delivery.offer(byteArrayOf(1, 2)) }
        platform.drain()
        assertEquals(1, received)
        assertFalse(delivery.isOpen)
        assertTrue(platform.tasks.isEmpty())
    }

    @Test fun aStoppedPlatformQueueReleasesPendingAudio() {
        val delivery = PcmDelivery(10, { false }, {}) { fail("Platform is stopped") }
        delivery.offer(byteArrayOf(1, 2))
        delivery.offer(byteArrayOf(3, 4))
        assertFalse(delivery.isOpen)
    }
}
