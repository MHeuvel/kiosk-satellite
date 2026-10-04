package me.jxl.kiosk_satellite

import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/** Queued audio keeps its generation after the writer takes it out of the queue. */
internal class PlaybackPcmQueue(val lock: Any = Any()) {
    class Chunk(val pcm: ByteArray, val generation: Long)

    private val chunks = LinkedBlockingQueue<Chunk>()
    private var generation = 0L

    fun offer(pcm: ByteArray) = synchronized(lock) {
        chunks.offer(Chunk(pcm, generation))
    }

    fun poll(): Chunk? = chunks.poll(100, TimeUnit.MILLISECONDS)

    fun clear() = synchronized(lock) {
        generation++
        chunks.clear()
    }

    /**
     * Check and write under the same lock used to flush the track. The
     * action must not block: a full AudioTrack returns zero and is retried.
     * Null means this chunk was discarded by a flush or stop.
     */
    fun write(chunk: Chunk, action: (ByteArray) -> Int): Int? = synchronized(lock) {
        if (chunk.generation == generation) action(chunk.pcm) else null
    }
}
