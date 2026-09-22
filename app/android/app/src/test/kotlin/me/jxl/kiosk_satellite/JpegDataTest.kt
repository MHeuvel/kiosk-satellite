package me.jxl.kiosk_satellite

import java.nio.ByteBuffer
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class JpegDataTest {
    private fun jpeg(progressive: Boolean = false): ByteArray =
        javaClass.getResourceAsStream("/camera/${if (progressive) "progressive" else "baseline"}.jpg")!!
            .use { it.readBytes() }

    @Test
    fun stripsOversizedCameraPaddingWithoutReencoding() {
        for (progressive in listOf(false, true)) {
            val original = jpeg(progressive)
            val padded = original.copyOf(12_174_771)
            val clean = JpegData.read(ByteBuffer.wrap(padded))
            assertContentEquals(original, clean)
            assertTrue(clean.size < 8 * 1024 * 1024)
        }
    }

    @Test
    fun keepsEmbeddedThumbnailAndExifIntact() {
        val original = jpeg()
        // An APP1 payload with an embedded JPEG and its own end marker.
        val metadata = byteArrayOf(0xFF.toByte(), 0xE1.toByte(), 0, 12,
            69, 120, 105, 102, 0, 0, 0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xD9.toByte())
        val expected = original.copyOfRange(0, 2) + metadata + original.copyOfRange(2, original.size)
        assertContentEquals(expected, JpegData.read(ByteBuffer.wrap(expected.copyOf(expected.size + 4096))))
    }

    @Test
    fun respectsBufferPositionAndLimitWithoutChangingThem() {
        val original = jpeg()
        val data = ByteBuffer.allocateDirect(original.size + 64)
        data.position(7)
        data.put(original)
        data.limit(data.position() + 10)
        data.position(7)
        assertContentEquals(original, JpegData.read(data.asReadOnlyBuffer()))
        assertEquals(7, data.position())
        assertEquals(original.size + 17, data.limit())
    }

    @Test
    fun keepsIncompleteAndNonJpegDataIntact() {
        val original = jpeg()
        val cases = listOf(
            ByteArray(0), byteArrayOf(1, 2, 3), original.copyOf(original.size - 2),
            byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE1.toByte(), 0, 1),
            byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE1.toByte(), 127, 127),
        )
        for (bytes in cases) assertContentEquals(bytes, JpegData.read(ByteBuffer.wrap(bytes)))
    }
}
