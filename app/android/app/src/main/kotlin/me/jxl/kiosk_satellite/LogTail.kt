package me.jxl.kiosk_satellite

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/**
 * A long-running `logcat` follow, one event per line, for the person
 * sensor (the Meta Portal's presence heartbeat is only in the log).
 *
 * Spawned here rather than with Dart's Process.start because a child
 * started from Dart inherits every descriptor the app has open, sockets
 * included. A tail started after the ESPHome server kept its listening
 * socket and Home Assistant's sessions alive, so the next server restart
 * failed with EADDRINUSE and the device dropped out of Home Assistant
 * until the app restarted (issue #734). ProcessBuilder closes everything
 * above stderr in the child.
 *
 * The listen argument is the logcat argument list after `logcat`. The
 * stream ends when logcat exits; cancelling kills it.
 */
class LogTail(messenger: BinaryMessenger) {
    private val events = EventChannel(messenger, "kiosk_satellite/log_tail")
    private val main = Handler(Looper.getMainLooper())
    private var process: Process? = null

    init {
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                stop()
                val argv = (args as? List<*>)?.map { it.toString() } ?: emptyList()
                val proc = try {
                    ProcessBuilder(listOf("logcat") + argv).start()
                } catch (e: Exception) {
                    sink.error("spawn_failed", e.message, null)
                    sink.endOfStream()
                    return
                }
                process = proc
                // Both readers catch: destroy() closes the pipes under a
                // blocked read, which throws, and an uncaught throw on
                // either thread takes the whole app down.
                Thread({
                    try {
                        proc.errorStream.bufferedReader().forEachLine {
                            Log.d(TAG, "logcat: $it")
                        }
                    } catch (_: Exception) {
                        // Killed by cancel.
                    }
                }, "log-tail-err").apply { isDaemon = true }.start()
                Thread({
                    try {
                        proc.inputStream.bufferedReader().forEachLine { line ->
                            main.post { if (process === proc) sink.success(line) }
                        }
                    } catch (_: Exception) {
                        // Killed by cancel: the stream is already gone.
                    }
                    main.post { if (process === proc) { process = null; sink.endOfStream() } }
                }, "log-tail").apply { isDaemon = true }.start()
            }

            override fun onCancel(args: Any?) = stop()
        })
    }

    private fun stop() {
        val proc = process ?: return
        process = null
        proc.destroy()
    }

    private companion object {
        const val TAG = "LogTail"
    }
}
