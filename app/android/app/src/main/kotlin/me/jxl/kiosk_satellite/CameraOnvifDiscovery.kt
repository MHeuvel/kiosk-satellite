package me.jxl.kiosk_satellite

import java.net.DatagramPacket
import java.net.Inet4Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.MulticastSocket
import java.net.NetworkInterface
import java.util.Collections
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.thread
import me.jxl.kiosk_satellite.CameraOnvifService.Companion.child

/** WS-Discovery announcements and Probe replies. Discovery never opens the camera. */
class CameraOnvifDiscovery(
    private val deviceId: String,
    private val port: Int,
    deviceName: String = "Kiosk Satellite",
    private val tls: Boolean = false,
) : AutoCloseable {
    private val scopes = CameraOnvifService.scopes(deviceName)
    @Volatile private var socket: MulticastSocket? = null
    @Volatile var error: String? = null
        private set
    private val joinedNetworks = mutableListOf<NetworkInterface>()
    private val sequence = AtomicLong()
    private val instance = instances.incrementAndGet()

    fun start() {
        val listener = MulticastSocket(null)
        try {
            listener.reuseAddress = true
            listener.bind(InetSocketAddress(3702))
            val group = InetSocketAddress("239.255.255.250", 3702)
            val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces()).filter {
                it.isUp && !it.isLoopback && it.supportsMulticast() && Collections.list(it.inetAddresses).any { ip -> ip is Inet4Address }
            }
            var joined = 0
            for (network in interfaces) {
                try { listener.joinGroup(group, network); joinedNetworks.add(network); joined++ } catch (_: Exception) { }
            }
            check(joined > 0) { "No multicast network available. Connect using the ONVIF URL." }
            socket = listener
        } catch (e: Exception) {
            listener.close()
            error = e.message ?: "Discovery unavailable. Connect using the ONVIF URL."
            return
        }
        announcements.execute { announce(listener, joinedNetworks, bye = false) }
        thread(name = "camera-onvif-discovery", isDaemon = true) {
            val buffer = ByteArray(8192)
            var window = System.nanoTime()
            var replies = 0
            while (!listener.isClosed) {
                try {
                    val packet = DatagramPacket(buffer, buffer.size)
                    listener.receive(packet)
                    if (packet.length >= buffer.size || packet.address.isMulticastAddress || packet.address.isAnyLocalAddress) continue
                    val now = System.nanoTime()
                    if (now - window >= 1_000_000_000L) { window = now; replies = 0 }
                    if (replies >= 20) continue
                    val addresses = localAddresses()
                    val response = probeReply(packet.data.copyOf(packet.length), addresses) ?: continue
                    val bytes = response.toByteArray(Charsets.UTF_8)
                    listener.send(DatagramPacket(bytes, bytes.size, packet.address, packet.port))
                    error = null
                    replies++
                } catch (e: Exception) {
                    if (listener.isClosed) break
                    error = e.message ?: "Discovery failed. Connect using the ONVIF URL."
                }
            }
        }
    }

    fun probeReply(bytes: ByteArray, addresses: List<String>): String? {
        val root = try { CameraOnvifService.parse(bytes).documentElement } catch (_: Exception) { return null }
        if (root.namespaceURI != CameraOnvifService.SOAP || root.localName != "Envelope" || addresses.isEmpty()) return null
        val header = root.child(CameraOnvifService.SOAP, "Header") ?: return null
        if (header.child(ADDRESSING, "Action")?.textContent != "$DISCOVERY/Probe") return null
        val messageId = header.child(ADDRESSING, "MessageID")?.textContent?.takeIf { it.length in 1..256 } ?: return null
        val probe = root.child(CameraOnvifService.SOAP, "Body")?.child(DISCOVERY, "Probe") ?: return null
        val types = probe.child(DISCOVERY, "Types")
        if (types != null && types.textContent.trim().isNotEmpty()) {
            for (type in types.textContent.trim().split(Regex("\\s+"))) {
                val prefix = type.substringBefore(':', "")
                val namespace = types.lookupNamespaceURI(prefix.ifEmpty { null })
                val local = type.substringAfter(':')
                if (!(namespace == "http://www.onvif.org/ver10/network/wsdl" && local == "NetworkVideoTransmitter") &&
                    !(namespace == CameraOnvifService.DEVICE && local == "Device")) return null
            }
        }
        val scopes = probe.child(DISCOVERY, "Scopes")
        if (scopes != null) {
            val matchBy = scopes.getAttribute("MatchBy")
            if (matchBy.isNotEmpty() && matchBy != "$DISCOVERY/rfc3986") return null
            val supported = this.scopes.split(' ')
            for (scope in scopes.textContent.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }) {
                if (supported.none { it == scope || it.startsWith(scope.trimEnd('/') + "/") }) return null
            }
        }
        return message("ProbeMatches", "<d:ProbeMatches><d:ProbeMatch>${description(addresses)}</d:ProbeMatch></d:ProbeMatches>", messageId)
    }

    internal fun announcement(addresses: List<String>, bye: Boolean = false): String {
        val action = if (bye) "Bye" else "Hello"
        val content = if (bye) endpoint() else description(addresses)
        return message(action, "<d:$action>$content</d:$action>")
    }

    private fun endpoint() = "<a:EndpointReference><a:Address>urn:uuid:${CameraOnvifService.xml(deviceId)}</a:Address></a:EndpointReference>"

    private fun description(addresses: List<String>): String {
        val xaddrs = addresses.take(8).joinToString(" ") { "${if (tls) "https" else "http"}://${CameraOnvifService.xml(it)}:$port/onvif/device_service" }
        return endpoint() + "<d:Types>dn:NetworkVideoTransmitter</d:Types><d:Scopes>$scopes</d:Scopes>" +
            "<d:XAddrs>$xaddrs</d:XAddrs><d:MetadataVersion>1</d:MetadataVersion>"
    }

    private fun message(action: String, body: String, relatesTo: String? = null): String =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
            "<s:Envelope xmlns:s=\"${CameraOnvifService.SOAP}\" xmlns:a=\"$ADDRESSING\" xmlns:d=\"$DISCOVERY\" " +
            "xmlns:dn=\"http://www.onvif.org/ver10/network/wsdl\"><s:Header>" +
            "<a:Action>$DISCOVERY/$action</a:Action><a:MessageID>urn:uuid:${UUID.randomUUID()}</a:MessageID>" +
            (relatesTo?.let { "<a:RelatesTo>${CameraOnvifService.xml(it)}</a:RelatesTo>" } ?: "") +
            "<a:To>${if (relatesTo == null) "urn:schemas-xmlsoap-org:ws:2005:04:discovery" else "$ADDRESSING/role/anonymous"}</a:To>" +
            "<d:AppSequence InstanceId=\"$instance\" MessageNumber=\"${sequence.incrementAndGet()}\"/>" +
            "</s:Header><s:Body>$body</s:Body></s:Envelope>"

    private fun announce(sender: MulticastSocket, networks: List<NetworkInterface>, bye: Boolean) {
        val group = InetAddress.getByName("239.255.255.250")
        for (network in networks) {
            try {
                val addresses = Collections.list(network.inetAddresses).filterIsInstance<Inet4Address>()
                    .filter { !it.isLoopbackAddress && !it.isLinkLocalAddress }.mapNotNull { it.hostAddress }
                if (addresses.isEmpty() && !bye) continue
                val bytes = announcement(addresses, bye).toByteArray(Charsets.UTF_8)
                sender.networkInterface = network
                sender.send(DatagramPacket(bytes, bytes.size, group, 3702))
            } catch (e: Exception) {
                if (!bye && !sender.isClosed) error = e.message ?: "ONVIF announcement failed."
            }
        }
    }

    override fun close() {
        val listener = socket ?: return
        socket = null
        listener.close()
        // Queue Bye before the next Hello when settings restart discovery.
        // A separate socket releases port 3702 without blocking the UI thread.
        val networks = joinedNetworks.toList()
        announcements.execute {
            try { MulticastSocket().use { announce(it, networks, bye = true) } } catch (_: Exception) { }
        }
    }

    companion object {
        private val instances = AtomicLong(System.currentTimeMillis() / 1000)
        private val announcements = Executors.newSingleThreadExecutor { task ->
            Thread(task, "camera-onvif-announcements").apply { isDaemon = true }
        }
        const val DISCOVERY = "http://schemas.xmlsoap.org/ws/2005/04/discovery"
        const val ADDRESSING = "http://schemas.xmlsoap.org/ws/2004/08/addressing"
        fun localAddresses(): List<String> = try {
            Collections.list(NetworkInterface.getNetworkInterfaces()).filter { it.isUp && !it.isLoopback }
                .flatMap { Collections.list(it.inetAddresses) }.filterIsInstance<Inet4Address>()
                .filter { !it.isLoopbackAddress && !it.isLinkLocalAddress }.mapNotNull(InetAddress::getHostAddress)
        } catch (_: Exception) { emptyList() }
    }
}
