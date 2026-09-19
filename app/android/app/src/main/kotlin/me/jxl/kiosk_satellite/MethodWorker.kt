package me.jxl.kiosk_satellite

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/** Serializes device reads and answers excess callers without retaining their requests. */
internal class MethodWorker(name: String) {
    private val worker = BoundedWorker(name, capacity = 1)
    private val main = Handler(Looper.getMainLooper())

    fun read(result: MethodChannel.Result, operation: () -> Any?) {
        if (!worker.execute {
            val value = try {
                operation()
            } catch (e: Exception) {
                main.post { result.error("read_failed", e.message, null) }
                return@execute
            }
            main.post { result.success(value) }
        }) {
            result.error("busy", "Device read worker is unavailable. Try again later.", null)
        }
    }

    fun shutdown() = worker.shutdown()
}
