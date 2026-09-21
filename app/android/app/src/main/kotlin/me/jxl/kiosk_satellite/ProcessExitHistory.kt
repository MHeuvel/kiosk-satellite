package me.jxl.kiosk_satellite

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.system.OsConstants
import androidx.annotation.RequiresApi
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Android's retained exit history, including deaths that cannot write a crash journal. */
object ProcessExitHistory {
    private const val LIMIT = 5

    // Read on a worker: the system query is a Binder call. Android retains
    // this history across process starts, so no second journal is needed.
    fun read(context: Context): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return "Process exit history unavailable: requires Android 11 or newer."
        }
        return try {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            format(
                manager.getHistoricalProcessExitReasons(context.packageName, 0, LIMIT),
                ActivityManager.isLowMemoryKillReportSupported(),
            )
        } catch (e: Exception) {
            "Process exit history unavailable: ${e.javaClass.simpleName}."
        }
    }

    @RequiresApi(Build.VERSION_CODES.R)
    internal fun format(exits: List<ApplicationExitInfo>, lowMemorySupported: Boolean): String {
        val recent = exits.sortedByDescending { it.timestamp }.take(LIMIT)
        if (recent.isEmpty()) return "Process exit history: Android has no retained records."
        val date = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS 'UTC'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        return buildString {
            append("Recent process exits retained by Android (newest first, up to $LIMIT):\n")
            append("low_memory_kill_reporting_supported=$lowMemorySupported\n")
            append("PSS/RSS are last sampled values, not memory at death. Zero means unavailable.\n")
            for (exit in recent) {
                append("at=${date.format(Date(exit.timestamp))}")
                append(" process=${oneLine(exit.processName)} pid=${exit.pid}\n")
                append("reason=${reasonName(exit.reason)} (${exit.reason})")
                append(" status=${exit.status} importance=${exit.importance}")
                append(" pss_kb=${exit.pss} rss_kb=${exit.rss}\n")
                if (!exit.description.isNullOrBlank()) {
                    append("description=${oneLine(exit.description)}\n")
                }
                if (exit.reason == ApplicationExitInfo.REASON_SIGNALED &&
                    exit.status == OsConstants.SIGKILL) {
                    append("SIGKILL does not establish an OOM kill.")
                    if (!lowMemorySupported) {
                        append(" This device can also report low-memory kills as SIGKILL.")
                    }
                    append('\n')
                }
                if (exit.reason == ApplicationExitInfo.REASON_USER_REQUESTED &&
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    append("On this Android version, USER_REQUESTED can also mean an app update or component change.\n")
                }
            }
        }.trimEnd()
    }

    private fun oneLine(value: String?): String =
        value?.take(512)?.map { if (it.isISOControl()) ' ' else it }?.joinToString("")
            ?: "unavailable"

    private fun reasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_UNKNOWN -> "UNKNOWN"
        ApplicationExitInfo.REASON_EXIT_SELF -> "EXIT_SELF"
        ApplicationExitInfo.REASON_SIGNALED -> "SIGNALED"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY"
        ApplicationExitInfo.REASON_CRASH -> "CRASH"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE"
        ApplicationExitInfo.REASON_ANR -> "ANR"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "PERMISSION_CHANGE"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "USER_REQUESTED"
        ApplicationExitInfo.REASON_USER_STOPPED -> "USER_STOPPED"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "DEPENDENCY_DIED"
        ApplicationExitInfo.REASON_OTHER -> "OTHER"
        ApplicationExitInfo.REASON_FREEZER -> "FREEZER"
        ApplicationExitInfo.REASON_PACKAGE_STATE_CHANGE -> "PACKAGE_STATE_CHANGE"
        ApplicationExitInfo.REASON_PACKAGE_UPDATED -> "PACKAGE_UPDATED"
        else -> "UNRECOGNIZED"
    }
}
