package me.jxl.kiosk_satellite

import androidx.media3.common.audio.AudioProcessor.AudioFormat
import androidx.media3.common.audio.AudioProcessor.UnhandledAudioFormatException
import androidx.media3.common.audio.BaseAudioProcessor
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer

/**
 * AudioTrack accepts whole PCM frames. A partial frame can otherwise leave
 * DefaultAudioSink retrying a write forever, even after decoder end of stream.
 * Keep fragments across buffers and discard only an incomplete final frame.
 */
@androidx.annotation.OptIn(UnstableApi::class)
internal class FrameAlignedAudioProcessor(
    private val onIncompleteFrame: (Int) -> Unit,
) : BaseAudioProcessor() {
    private var fragment = ByteArray(0)
    private var fragmentSize = 0

    override fun onConfigure(inputAudioFormat: AudioFormat): AudioFormat {
        if (inputAudioFormat.bytesPerFrame <= 0) {
            throw UnhandledAudioFormatException(inputAudioFormat)
        }
        return inputAudioFormat
    }

    override fun onFlush() {
        fragment = ByteArray(inputAudioFormat.bytesPerFrame.coerceAtLeast(0))
        fragmentSize = 0
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        if (!inputBuffer.hasRemaining()) return
        val total = fragmentSize + inputBuffer.remaining()
        val outputSize = total - total % fragment.size
        if (outputSize > 0) {
            val output = replaceOutputBuffer(outputSize)
            output.put(fragment, 0, fragmentSize)
            val limit = inputBuffer.limit()
            inputBuffer.limit(inputBuffer.position() + outputSize - fragmentSize)
            output.put(inputBuffer)
            inputBuffer.limit(limit)
            output.flip()
            fragmentSize = 0
        }
        val remaining = inputBuffer.remaining()
        inputBuffer.get(fragment, fragmentSize, remaining)
        fragmentSize += remaining
    }

    override fun onQueueEndOfStream() {
        if (fragmentSize > 0) onIncompleteFrame(fragmentSize)
        fragmentSize = 0
    }

    override fun onReset() {
        fragment = ByteArray(0)
        fragmentSize = 0
    }
}
