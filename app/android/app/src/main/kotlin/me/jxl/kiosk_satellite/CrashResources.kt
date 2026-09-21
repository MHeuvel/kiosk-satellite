package me.jxl.kiosk_satellite

import android.os.Debug
import android.os.SystemClock
import java.io.File

/** Small process measurements without allocating stack traces for every thread. */
internal object CrashResources {
    private val startedAt = SystemClock.elapsedRealtime()
    private val statusFields = setOf("Threads", "VmPeak", "VmSize", "VmRSS", "VmData", "VmStk", "VmSwap")
    private val families = listOf(
        "fleet-mdns", "btproxy-mdns", "btproxy-r-", "btproxy-w-", "btproxy-tick", "btproxy-accept",
        "ks-backgroundRead", "ks-cpu", "ks-sound", "ks-intercom", "ks-aec-release",
        "camera-rtsp", "camera-video", "screen-capture", "vsww", "Sendspin", "CameraX",
        "Chrome", "Cr", "RenderThread", "Dart", "flutter", "io.flutter", "tflite", "TfLite",
        "NNAPI", "Binder:", "HwBinder:", "pool-", "Thread-", "HeapTaskDaemon",
        "Finalizer", "ReferenceQueue", "Jit thread", "Signal Catcher",
    )

    fun initialize() { /* Set the uptime origin at journal installation. */ }

    fun snapshot(proc: File = File("/proc/self")): String = buildString {
        append("Resource snapshot (best effort):\n")
        append("journal_uptime_ms=${SystemClock.elapsedRealtime() - startedAt}\n")
        val runtime = Runtime.getRuntime()
        append("java_heap_bytes: used=${runtime.totalMemory() - runtime.freeMemory()}")
        append(" committed=${runtime.totalMemory()} max=${runtime.maxMemory()}\n")
        append("native_heap_bytes: allocated=${Debug.getNativeHeapAllocatedSize()}\n")
        try {
            File(proc, "status").bufferedReader().useLines { lines ->
                lines.take(100).forEach { line ->
                    if (line.substringBefore(':') in statusFields) append(line).append('\n')
                }
            }
        } catch (_: Exception) {
            append("process_status=unavailable\n")
        }
        // Kernel names are short but can contain user data. Emit only
        // known families, never names supplied by a plugin or a server.
        val tasks = File(proc, "task").listFiles()
        val counts = sortedMapOf<String, Int>()
        var sampled = 0
        for (task in tasks.orEmpty().take(256)) {
            val name = try {
                File(task, "comm").bufferedReader().use { it.readLine()?.take(16) }
            } catch (_: Exception) { null } ?: continue
            val family = families.firstOrNull { name.startsWith(it.take(15)) } ?: "other"
            counts[family] = (counts[family] ?: 0) + 1
            sampled++
        }
        append("native_thread_sample: read=$sampled listed=${tasks?.size ?: -1} limit=256\n")
        counts.forEach { (family, count) -> append("  $family: $count\n") }
    }
}
