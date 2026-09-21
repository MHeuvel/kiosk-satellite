package me.jxl.kiosk_satellite

import android.app.ActivityManager
import android.app.Application
import android.app.ApplicationExitInfo
import android.content.Context
import android.content.ContextWrapper
import android.system.OsConstants
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowActivityManager.ApplicationExitInfoBuilder

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, application = Application::class, sdk = [30, 34])
class ProcessExitHistoryTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    private fun exit(
        reason: Int,
        status: Int = 0,
        timestamp: Long = 1_700_000_000_000L,
        description: String = "system description",
    ): ApplicationExitInfo = ApplicationExitInfoBuilder.newBuilder()
        .setProcessName(context.packageName)
        .setPid(123)
        .setTimestamp(timestamp)
        .setReason(reason)
        .setStatus(status)
        .setImportance(ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND)
        .setPss(12345)
        .setRss(23456)
        .setDescription(description)
        .build()

    @Test fun systemHistoryReachesTheReportWithoutChangingTheExceptionJournal() {
        CrashJournal.record(context, Thread.currentThread(), IllegalStateException("original crash")) { "" }
        val journal = CrashJournal.read(context)
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        shadowOf(manager).addApplicationExitInfo(exit(ApplicationExitInfo.REASON_LOW_MEMORY))
        val report = ProcessExitHistory.read(context)
        assertTrue(report.contains("reason=LOW_MEMORY (3)"))
        assertTrue(report.contains("2023-11-14 22:13:20.000 UTC"))
        assertTrue(report.contains("process=${context.packageName} pid=123"))
        assertTrue(report.contains("importance=100 pss_kb=12345 rss_kb=23456"))
        assertTrue(report.contains("last sampled values, not memory at death"))
        assertEquals(journal, CrashJournal.read(context))
        assertEquals(report, ProcessExitHistory.read(context))
    }

    @Test fun sigkillIsNotPromotedToLowMemory() {
        val killed = exit(ApplicationExitInfo.REASON_SIGNALED, OsConstants.SIGKILL)
        val unsupported = ProcessExitHistory.format(listOf(killed), false)
        assertTrue(unsupported.contains("reason=SIGNALED (2) status=9"))
        assertTrue(unsupported.contains("SIGKILL does not establish an OOM kill"))
        assertTrue(unsupported.contains("can also report low-memory kills as SIGKILL"))
        assertFalse(unsupported.contains("reason=LOW_MEMORY"))
        val supported = ProcessExitHistory.format(listOf(killed), true)
        assertTrue(supported.contains("SIGKILL does not establish an OOM kill"))
        assertFalse(supported.contains("can also report low-memory kills as SIGKILL"))
    }

    @Test fun nativeCrashAndAnrKeepTheirOwnReasons() {
        val report = ProcessExitHistory.format(listOf(
            exit(ApplicationExitInfo.REASON_CRASH_NATIVE, OsConstants.SIGSEGV),
            exit(ApplicationExitInfo.REASON_ANR),
        ), true)
        assertTrue(report.contains("reason=CRASH_NATIVE (5) status=11"))
        assertTrue(report.contains("reason=ANR (6)"))
        assertFalse(report.contains("OOM"))
    }

    @Test fun limitsHistoryAndKeepsNewestFirst() {
        val exits = (1L..10L).map { exit(ApplicationExitInfo.REASON_EXIT_SELF, timestamp = it) }
        val report = ProcessExitHistory.format(exits, true)
        assertEquals(5, Regex("reason=").findAll(report).count())
        assertTrue(report.indexOf("00:00:00.010") < report.indexOf("00:00:00.006"))
        assertFalse(report.contains("00:00:00.005"))
    }

    @Test fun descriptionsAreBoundedAndCannotInsertLogLines() {
        val report = ProcessExitHistory.format(listOf(exit(
            ApplicationExitInfo.REASON_OTHER,
            description = "first\nsecond\r\t" + "x".repeat(2000),
        )), true)
        val description = report.lineSequence().single { it.startsWith("description=") }
            .removePrefix("description=")
        assertEquals(512, description.length)
        assertTrue(description.startsWith("first second  "))
    }

    @Test fun unknownReasonStillIncludesTheNumericCode() {
        assertTrue(ProcessExitHistory.format(listOf(exit(999)), true)
            .contains("reason=UNRECOGNIZED (999)"))
    }

    @Test fun emptyHistoryIsExplicit() {
        assertEquals("Process exit history: Android has no retained records.",
            ProcessExitHistory.read(context))
    }

    @Test fun deniedSystemReadDoesNotFailStartup() {
        val denied = object : ContextWrapper(context) {
            override fun getSystemService(name: String): Any {
                throw SecurityException("private detail")
            }
        }
        assertEquals("Process exit history unavailable: SecurityException.",
            ProcessExitHistory.read(denied))
    }

    @Test @Config(sdk = [28])
    fun olderAndroidDoesNotQueryTheSystem() {
        val unsupported = object : ContextWrapper(context) {
            override fun getSystemService(name: String): Any = error("Must not query exit history")
        }
        assertEquals("Process exit history unavailable: requires Android 11 or newer.",
            ProcessExitHistory.read(unsupported))
    }

    @Test @Config(sdk = [30])
    fun olderUserRequestedReasonCanAlsoBeAnUpdate() {
        val report = ProcessExitHistory.format(listOf(exit(ApplicationExitInfo.REASON_USER_REQUESTED)), true)
        assertTrue(report.contains("USER_REQUESTED can also mean an app update or component change"))
    }

    @Test @Config(sdk = [34])
    fun updatesAndUserStopsAreDistinctOnNewerAndroid() {
        val report = ProcessExitHistory.format(listOf(
            exit(ApplicationExitInfo.REASON_PACKAGE_UPDATED),
            exit(ApplicationExitInfo.REASON_USER_REQUESTED),
        ), true)
        assertTrue(report.contains("reason=PACKAGE_UPDATED (16)"))
        assertTrue(report.contains("reason=USER_REQUESTED (10)"))
        assertFalse(report.contains("can also mean an app update"))
    }
}
