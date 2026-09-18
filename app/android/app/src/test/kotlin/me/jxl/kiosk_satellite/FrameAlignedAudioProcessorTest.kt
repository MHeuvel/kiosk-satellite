package me.jxl.kiosk_satellite

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor.AudioFormat
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [27], application = android.app.Application::class, manifest = Config.NONE)
class FrameAlignedAudioProcessorTest {
    private fun configure(processor: FrameAlignedAudioProcessor, channels: Int = 2) {
        processor.configure(AudioFormat(44100, channels, C.ENCODING_PCM_16BIT))
        processor.flush()
    }

    private fun drain(processor: FrameAlignedAudioProcessor): ByteArray {
        val buffer = processor.output
        return ByteArray(buffer.remaining()).also { buffer.get(it) }
    }

    @Test fun splitFramesPreserveEveryByteInOrder() {
        for (channels in listOf(1, 2, 6)) {
            for (chunk in 1..29) {
                val processor = FrameAlignedAudioProcessor { fail("Complete audio must not be discarded") }
                configure(processor, channels)
                val source = ByteArray(240) { it.toByte() }
                val result = ByteArrayOutputStream()
                for (start in source.indices step chunk) {
                    val count = minOf(chunk, source.size - start)
                    val input = ByteBuffer.wrap(source, start, count)
                    processor.queueInput(input)
                    assertFalse(input.hasRemaining())
                    val output = drain(processor)
                    assertEquals(0, output.size % (channels * 2))
                    result.write(output)
                }
                processor.queueEndOfStream()
                result.write(drain(processor))
                assertTrue(processor.isEnded)
                assertArrayEquals(source, result.toByteArray())
            }
        }
    }

    @Test fun incompleteStereoTailCannotHoldEndOfStreamOpen() {
        val discarded = mutableListOf<Int>()
        val processor = FrameAlignedAudioProcessor { discarded.add(it) }
        configure(processor)
        processor.queueInput(ByteBuffer.wrap(byteArrayOf(1, 2, 3, 4, 5, 6)))
        processor.queueEndOfStream()
        assertFalse(processor.isEnded)
        assertArrayEquals(byteArrayOf(1, 2, 3, 4), drain(processor))
        assertTrue(processor.isEnded)
        assertEquals(listOf(2), discarded)
    }

    @Test fun fragmentOnlyStreamAndEmptyBuffersCanEnd() {
        val discarded = mutableListOf<Int>()
        val processor = FrameAlignedAudioProcessor { discarded.add(it) }
        configure(processor)
        processor.queueInput(ByteBuffer.allocate(0))
        processor.queueInput(ByteBuffer.wrap(byteArrayOf(1)))
        assertEquals(0, drain(processor).size)
        processor.queueEndOfStream()
        assertTrue(processor.isEnded)
        assertEquals(listOf(1), discarded)
    }

    @Test fun flushDiscardsOldFragmentBeforeNewFormat() {
        val processor = FrameAlignedAudioProcessor { fail("Flushed audio must not reach the new stream") }
        configure(processor)
        processor.queueInput(ByteBuffer.wrap(byteArrayOf(1, 2, 3)))
        configure(processor, channels = 1)
        processor.queueInput(ByteBuffer.wrap(byteArrayOf(4, 5)))
        assertArrayEquals(byteArrayOf(4, 5), drain(processor))
        processor.queueEndOfStream()
        assertTrue(processor.isEnded)
        processor.reset()
        configure(processor)
        processor.queueInput(ByteBuffer.wrap(byteArrayOf(6, 7, 8, 9)))
        assertArrayEquals(byteArrayOf(6, 7, 8, 9), drain(processor))
    }
}
