package me.jxl.kiosk_satellite

import java.nio.ByteBuffer

/** Copies the encoded JPEG without unused camera buffer space after its end marker. */
internal object JpegData {
    fun read(buffer: ByteBuffer): ByteArray {
        val data = buffer.slice()
        val length = encodedLength(data) ?: data.remaining()
        return ByteArray(length).also { data.get(it) }
    }

    private fun encodedLength(data: ByteBuffer): Int? {
        val size = data.remaining()
        fun byte(index: Int) = data.get(index).toInt() and 0xFF
        if (size < 4 || byte(0) != 0xFF || byte(1) != 0xD8) return null
        var offset = 2
        var inScan = false
        while (offset < size) {
            if (byte(offset) != 0xFF) {
                if (!inScan) return null
                offset++
                continue
            }
            // Markers can have extra FF fill bytes. Inside a scan, FF 00
            // encodes a literal FF and restart markers carry no length.
            while (offset < size && byte(offset) == 0xFF) offset++
            if (offset == size) return null
            val marker = byte(offset++)
            when {
                marker == 0xD9 -> return offset
                marker == 0x00 || marker in 0xD0..0xD7 -> {
                    if (!inScan) return null
                }
                marker == 0x01 -> Unit // TEM has no payload.
                marker == 0xD8 -> return null
                else -> {
                    if (size - offset < 2) return null
                    val length = (byte(offset) shl 8) or byte(offset + 1)
                    if (length < 2 || length > size - offset) return null
                    // Skip metadata by its declared length. An EXIF
                    // thumbnail can contain its own JPEG end marker.
                    offset += length
                    if (marker == 0xDA) inScan = true
                }
            }
        }
        // Keep incomplete or unrecognized data intact for the caller.
        return null
    }
}
