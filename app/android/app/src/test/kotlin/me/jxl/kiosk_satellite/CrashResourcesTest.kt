package me.jxl.kiosk_satellite

import android.app.Application
import java.io.File
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, application = Application::class, sdk = [28])
class CrashResourcesTest {
    @get:Rule val temp = TemporaryFolder()

    @Test fun recordsMemoryAndThreadFamiliesWithoutArbitraryNames() {
        val proc = temp.newFolder()
        File(proc, "status").writeText("Name:\tprivate-name\nThreads:\t3\nVmRSS:\t12000 kB\nVmSize:\t24000 kB\nUid:\t1234\n")
        listOf("fleet-mdns-tx", "fleet-mdns-rx", "secret-hostname").forEachIndexed { index, name ->
            File(proc, "task/$index").mkdirs()
            File(proc, "task/$index/comm").writeText(name)
        }
        val snapshot = CrashResources.snapshot(proc)
        assertTrue(snapshot.contains("Threads:\t3"))
        assertTrue(snapshot.contains("VmSize:\t24000 kB"))
        assertTrue(snapshot.contains("fleet-mdns: 2"))
        assertTrue(snapshot.contains("other: 1"))
        assertFalse(snapshot.contains("private-name"))
        assertFalse(snapshot.contains("secret-hostname"))
        assertFalse(snapshot.contains("Uid:"))
    }

    @Test fun capsThreadSamplingAndToleratesMissingProcFiles() {
        val proc = temp.newFolder()
        repeat(300) {
            File(proc, "task/$it").mkdirs()
            File(proc, "task/$it/comm").writeText("Thread-$it")
        }
        val snapshot = CrashResources.snapshot(proc)
        assertTrue(snapshot.contains("process_status=unavailable"))
        assertTrue(snapshot.contains("read=256 listed=300 limit=256"))
        assertTrue(snapshot.contains("Thread-: 256"))
    }

    @Test fun diagnosticFailureCannotEraseTheOriginalCrash() {
        val context = RuntimeEnvironment.getApplication()
        CrashJournal.clear(context)
        CrashJournal.record(context, Thread.currentThread(), IllegalStateException("original failure")) {
            throw OutOfMemoryError("diagnostic allocation failed")
        }
        val journal = CrashJournal.read(context)
        assertTrue(journal.contains("java.lang.IllegalStateException: original failure"))
        assertFalse(journal.contains("diagnostic allocation failed"))
        CrashJournal.record(context, Thread.currentThread(), IllegalArgumentException("next failure")) { "resource details" }
        val next = CrashJournal.read(context)
        assertTrue(next.contains("original failure"))
        assertTrue(next.indexOf("next failure") < next.indexOf("resource details"))
    }
}
