package me.jxl.kiosk_satellite

import java.util.ArrayDeque

/** A bounded handoff of owned PCM buffers to the platform thread. */
internal class PcmDelivery(
    private val maxBytes: Int,
    private val post: (Runnable) -> Boolean,
    private val remove: (Runnable) -> Unit,
    private val deliver: (ByteArray) -> Unit,
) {
    private val pending = ArrayDeque<ByteArray>()
    private var pendingBytes = 0
    private var scheduled = false
    @Volatile var isOpen = true
        private set
    @Volatile var droppedChunks = 0L
        private set

    init { require(maxBytes > 0) }

    private val drain = Runnable { drainOne() }

    /** The caller gives up ownership of [pcm] and must not modify it later. */
    @Synchronized
    fun offer(pcm: ByteArray) {
        if (!isOpen || pcm.isEmpty()) return
        if (pcm.size > maxBytes) {
            droppedChunks++
            return
        }
        // Stale speech is not useful after a UI stall. Keep the newest
        // bounded window instead of retaining every capture until resume.
        while (pendingBytes > maxBytes - pcm.size) {
            pendingBytes -= pending.removeFirst().size
            droppedChunks++
        }
        pending.addLast(pcm)
        pendingBytes += pcm.size
        schedule()
    }

    /** Called on the platform thread, like [deliver]. */
    @Synchronized
    fun close() {
        isOpen = false
        pending.clear()
        pendingBytes = 0
        remove(drain)
        scheduled = false
    }

    private fun schedule() {
        if (scheduled || !isOpen || pending.isEmpty()) return
        scheduled = true
        if (!post(drain)) close()
    }

    private fun drainOne() {
        val pcm = synchronized(this) {
            if (!isOpen) return
            pending.pollFirst()?.also { pendingBytes -= it.size }
        }
        try {
            if (pcm != null) deliver(pcm)
        } finally {
            synchronized(this) {
                scheduled = false
                // One chunk per callback lets the UI process other work.
                schedule()
            }
        }
    }
}
