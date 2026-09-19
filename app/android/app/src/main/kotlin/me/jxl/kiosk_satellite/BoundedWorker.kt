package me.jxl.kiosk_satellite

import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadFactory
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/** One reusable thread with a fixed backlog. Rejected work never runs on the caller. */
internal class BoundedWorker(
    name: String,
    capacity: Int,
    factory: ThreadFactory = ThreadFactory { task -> Thread(task, name).apply { isDaemon = true } },
) {
    private val executor = ThreadPoolExecutor(
        1, 1, 0, TimeUnit.MILLISECONDS, ArrayBlockingQueue(capacity), factory,
        ThreadPoolExecutor.AbortPolicy(),
    )

    fun execute(task: () -> Unit): Boolean = try {
        executor.execute(task)
        true
    } catch (_: RejectedExecutionException) {
        false
    } catch (_: OutOfMemoryError) {
        // Starting the first worker can fail under native thread pressure.
        // Errors inside an accepted task still reach the crash journal.
        false
    }

    /** Only for work whose owner has already canceled its result. */
    fun discardPending() = executor.queue.clear()

    fun shutdown() = executor.shutdown()
}
