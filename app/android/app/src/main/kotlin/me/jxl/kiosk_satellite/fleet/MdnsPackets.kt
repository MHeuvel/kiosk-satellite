package me.jxl.kiosk_satellite.fleet

import java.io.ByteArrayOutputStream
import java.net.DatagramPacket
import java.net.Inet4Address

/** DNS packet handling shared by the announcer and its JVM tests. */
internal object MdnsPackets {
    /**
     * A live A record claiming our name at another address. This needs no
     * fleet PTR or TXT records, so it also works with discovery disabled.
     * Ignore our looped-back records and goodbye records.
     */
    fun conflictingHostAddress(
        packet: DatagramPacket,
        host: String,
        localAddresses: Set<String>,
    ): String? {
        if (host.isEmpty()) return null
        val r = DnsReader(packet.data, packet.offset, packet.length)
        r.u16()
        if (r.u16() and 0x8000 == 0) return null
        val qd = r.u16()
        val count = r.u16() + r.u16() + r.u16()
        repeat(qd) { r.name(); r.u16(); r.u16() }
        var conflict: String? = null
        repeat(count) {
            val name = r.name()
            val type = r.u16()
            val klass = r.u16() and 0x7fff
            val ttl = r.u32()
            val size = r.u16()
            val data = r.bytes(size)
            if (name.equals(host, true) && type == 1 && klass == 1 && ttl != 0 && size == 4) {
                val address = data.joinToString(".") { (it.toInt() and 0xff).toString() }
                if (address !in localAddresses) conflict = address
            }
        }
        return conflict
    }

    /**
     * One DNS label as it travels: its length byte and its bytes, letters
     * lowercased. The needle for [mentions].
     */
    fun labelNeedle(label: String): ByteArray {
        val bytes = label.lowercase().toByteArray(Charsets.UTF_8)
        return byteArrayOf((bytes.size and 0xFF).toByte()) + bytes
    }

    /**
     * Whether the message spells out the label [needle] anywhere, checked
     * on the raw bytes before anything is parsed. A name travels as
     * length-prefixed labels, and a compression pointer can only refer to
     * labels spelled out earlier in the same message, so every label of
     * every name a message carries appears in it verbatim at least once:
     * a miss is certain, a hit is a reason to parse. Letters compare
     * case-insensitively, as DNS names do. Cheap enough to run on every
     * packet a busy network delivers, which is what it is for: without it
     * the receiver walked the network interfaces and parsed every record
     * of every response on the network, a full core on a wall panel among
     * a few dozen ESPHome nodes, speakers and printers (issue #567).
     */
    fun mentions(packet: DatagramPacket, needle: ByteArray): Boolean =
        mentions(packet.data, packet.offset, packet.length, needle)

    fun mentions(buf: ByteArray, offset: Int, length: Int, needle: ByteArray): Boolean {
        if (needle.isEmpty()) return false
        val last = offset + length - needle.size
        var i = offset
        outer@ while (i <= last) {
            if (buf[i] != needle[0]) { i++; continue }
            for (k in 1 until needle.size) {
                var b = buf[i + k].toInt()
                if (b in 0x41..0x5A) b = b or 0x20
                if (b.toByte() != needle[k]) { i++; continue@outer }
            }
            return true
        }
        return false
    }

    fun mentionsLabel(packet: DatagramPacket, label: String): Boolean =
        mentions(packet, labelNeedle(label))

    /** A cursor over one DNS message, with name decompression. */
    internal class DnsReader(private val buf: ByteArray, private val start: Int, length: Int) {
        var pos = start
        private val end = start + length

        fun u8(): Int {
            if (pos >= end) throw IndexOutOfBoundsException("dns")
            return buf[pos++].toInt() and 0xFF
        }
        fun u16(): Int = (u8() shl 8) or u8()
        fun u32(): Int = (u16() shl 16) or u16()
        fun bytes(n: Int): ByteArray {
            if (pos + n > end) throw IndexOutOfBoundsException("dns")
            return buf.copyOfRange(pos, pos + n).also { pos += n }
        }

        fun name(): String {
            val labels = ArrayList<String>()
            var p = pos
            var jumped = false
            var hops = 0
            while (true) {
                if (p >= end) throw IndexOutOfBoundsException("dns name")
                val len = buf[p].toInt() and 0xFF
                when {
                    len == 0 -> { p++; break }
                    len and 0xC0 == 0xC0 -> {
                        if (p + 1 >= end) throw IndexOutOfBoundsException("dns pointer")
                        val target = start + (((len and 0x3F) shl 8) or (buf[p + 1].toInt() and 0xFF))
                        if (!jumped) pos = p + 2
                        jumped = true
                        p = target
                        if (++hops > 32) throw IllegalStateException("dns pointer loop")
                    }
                    else -> {
                        p++
                        if (p + len > end) throw IndexOutOfBoundsException("dns label")
                        labels.add(String(buf, p, len, Charsets.UTF_8))
                        p += len
                    }
                }
            }
            if (!jumped) pos = p
            return labels.joinToString(".")
        }
    }

    /**
     * The answer to a query for one or more of this kiosk's host names. A
     * [legacy] answer echoes the query's id and [questions] (the raw
     * question section, whose name pointers stay valid behind an
     * identical header), caps the TTL at ten seconds and leaves the
     * cache-flush bit off, as RFC 6762 section 6.7 has it.
     */
    internal fun buildHostAnswer(
        hosts: Collection<String>,
        address: Inet4Address,
        hostTtl: Int = 120,
        qid: Int = 0,
        questions: ByteArray? = null,
        qd: Int = 0,
        legacy: Boolean = false,
    ): ByteArray {
        val body = ByteArrayOutputStream(128)
        var count = 0
        val ttl = if (legacy) minOf(hostTtl, 10) else hostTtl
        for (h in hosts) count += body.hostRecords(h, address, ttl, flush = !legacy)
        val out = ByteArrayOutputStream(128 + body.size() + (questions?.size ?: 0))
        out.u16(qid); out.u16(0x8400); out.u16(if (questions != null) qd else 0)
        out.u16(count); out.u16(0); out.u16(0)
        questions?.let { out.write(it) }
        body.writeTo(out)
        return out.toByteArray()
    }

    /**
     * A host's A record, with cache-flush unless [flush] is off for a
     * legacy reply. Returns how many records were written.
     *
     * The A record alone, no NSEC saying there is no AAAA. RFC 6762
     * suggests one so a resolver asking for both families need not wait
     * out the IPv6 half, and macOS and Android took a reply that carried
     * one, but the Windows resolver did not: a capture on a Windows
     * machine showed the unicast and the multicast reply arriving, A and
     * a well-formed NSEC each, and ping reporting no such host, while the
     * same reply without the NSEC resolved. Avahi hosts, which Windows
     * resolves every day, send the address alone too.
     */
    internal fun ByteArrayOutputStream.hostRecords(
        host: String,
        address: Inet4Address,
        ttl: Int,
        flush: Boolean = true,
    ): Int {
        name(host); u16(1); u16(if (flush) 0x8001 else 1); u32(ttl)
        lengthPrefixed { it.write(address.address) }
        return 1
    }

    internal fun ByteArrayOutputStream.u16(v: Int) {
        write((v ushr 8) and 0xFF); write(v and 0xFF)
    }

    internal fun ByteArrayOutputStream.u32(v: Int) {
        write((v ushr 24) and 0xFF); write((v ushr 16) and 0xFF)
        write((v ushr 8) and 0xFF); write(v and 0xFF)
    }

    internal fun ByteArrayOutputStream.name(dotted: String) {
        for (label in dotted.split(".")) {
            val bytes = label.toByteArray(Charsets.UTF_8)
            write(bytes.size)
            write(bytes)
        }
        write(0)
    }

    internal fun ByteArrayOutputStream.lengthPrefixed(fill: (ByteArrayOutputStream) -> Unit) {
        val body = ByteArrayOutputStream(64)
        fill(body)
        u16(body.size())
        body.writeTo(this)
    }
}
