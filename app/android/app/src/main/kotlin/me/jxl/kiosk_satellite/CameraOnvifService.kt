package me.jxl.kiosk_satellite

import java.io.ByteArrayInputStream
import java.net.InetAddress
import java.net.NetworkInterface
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import javax.xml.parsers.DocumentBuilderFactory
import org.w3c.dom.Element

/** Read-only ONVIF device and Media1 services for the shared camera stream. */
class CameraOnvifService(
    private var width: Int,
    private var height: Int,
    private var fps: Int,
    private var bitrate: Int,
    private val audio: Boolean,
    private val username: String?,
    private val password: String,
    private val encodeBase64: (ByteArray) -> String,
    private val decodeBase64: (String) -> ByteArray,
    private val deviceId: String,
    private val firmware: String,
    private val networkInfo: (String) -> NetworkInfo? = ::networkInfoFor,
    deviceName: String = "Kiosk Satellite",
    private val tls: Boolean = false,
) {
    data class Response(val status: String, val body: String)
    data class NetworkInfo(val name: String, val enabled: Boolean, val hardwareAddress: String?, val mtu: Int?)
    private val name = deviceName.trim().ifEmpty { "Kiosk Satellite" }
    private val scopes = scopes(name)
    private val usedTokens = mutableMapOf<String, Long>()

    @Synchronized fun updateVideo(width: Int, height: Int, fps: Int, bitrate: Int) {
        this.width = width
        this.height = height
        this.fps = fps
        this.bitrate = bitrate
    }

    @Synchronized fun respond(path: String, bytes: ByteArray, host: String, port: Int): Response {
        if (path !in listOf("/onvif/device_service", "/onvif/media_service")) {
            return Response("404 Not Found", "")
        }
        val document = try { parse(bytes) } catch (_: Exception) {
            return fault("ter:InvalidArgVal", "Invalid SOAP request", "400 Bad Request")
        }
        val envelope = document.documentElement
        val body = envelope.child(SOAP, "Body")
        val operation = body?.let { node ->
            (0 until node.childNodes.length).map { node.childNodes.item(it) }.filterIsInstance<Element>().singleOrNull()
        } ?: return fault("ter:InvalidArgVal", "Expected one SOAP operation", "400 Bad Request")
        val namespace = if (path.endsWith("device_service")) DEVICE else MEDIA
        if (envelope.namespaceURI != SOAP || envelope.localName != "Envelope" || operation.namespaceURI != namespace) {
            return fault("ter:ActionNotSupported", "Unsupported service")
        }
        val name = operation.localName
        // ONVIF clients obtain UTC before constructing their UsernameToken.
        if (name != "GetSystemDateAndTime" && !authenticated(envelope)) {
            return fault("ter:NotAuthorized", "Authentication required", "400 Bad Request")
        }
        val base = "${if (tls) "https" else "http"}://${xml(host)}:$port/onvif"
        val profileToken = operation.child(MEDIA, "ProfileToken")?.textContent
        if (name in listOf("GetProfile", "GetStreamUri") && profileToken != "camera") {
            return fault("ter:InvalidArgVal", "Unknown profile token", subcode = "ter:NoProfile")
        }
        val content = if (namespace == DEVICE) when (name) {
            "GetDeviceInformation" -> "<tds:Manufacturer>Kiosk Satellite</tds:Manufacturer>" +
                "<tds:Model>${xml(this.name)}</tds:Model><tds:FirmwareVersion>${xml(firmware)}</tds:FirmwareVersion>" +
                "<tds:SerialNumber>${xml(deviceId)}</tds:SerialNumber><tds:HardwareId>camera</tds:HardwareId>"
            "GetNetworkInterfaces" -> {
                val network = networkInfo(host) ?: return fault("ter:ActionNotSupported",
                    "GetNetworkInterfaces is not implemented for this interface")
                // Android can hide the physical MAC. Leave that field empty so
                // clients can use the persistent serial number as the identity.
                "<tds:NetworkInterfaces token=\"${xml(network.name)}\"><tt:Enabled>${network.enabled}</tt:Enabled>" +
                    "<tt:Info><tt:Name>${xml(network.name)}</tt:Name>" +
                    "<tt:HwAddress>${xml(network.hardwareAddress ?: "")}</tt:HwAddress>" +
                    (network.mtu?.let { "<tt:MTU>$it</tt:MTU>" } ?: "") +
                    "</tt:Info></tds:NetworkInterfaces>"
            }
            "GetSystemDateAndTime" -> dateAndTime()
            "GetServices" -> service("tds", DEVICE, "$base/device_service", operation) +
                service("trt", MEDIA, "$base/media_service", operation)
            "GetCapabilities" -> {
                val category = operation.child(DEVICE, "Category")?.textContent ?: "All"
                if (category !in listOf("All", "Device", "Media")) return fault("ter:ActionNotSupported", "Unsupported capability")
                "<tds:Capabilities>" + (if (category != "Media")
                    "<tt:Device><tt:XAddr>$base/device_service</tt:XAddr>" +
                    "<tt:Network><tt:IPFilter>false</tt:IPFilter><tt:ZeroConfiguration>false</tt:ZeroConfiguration>" +
                    "<tt:IPVersion6>false</tt:IPVersion6><tt:DynDNS>false</tt:DynDNS></tt:Network>" +
                    "<tt:System><tt:DiscoveryResolve>false</tt:DiscoveryResolve><tt:DiscoveryBye>true</tt:DiscoveryBye>" +
                    "<tt:RemoteDiscovery>false</tt:RemoteDiscovery><tt:SystemBackup>false</tt:SystemBackup>" +
                    "<tt:SystemLogging>false</tt:SystemLogging><tt:FirmwareUpgrade>false</tt:FirmwareUpgrade>" +
                    "<tt:SupportedVersions><tt:Major>2</tt:Major><tt:Minor>0</tt:Minor></tt:SupportedVersions></tt:System>" +
                    "<tt:Security><tt:TLS1.1>false</tt:TLS1.1><tt:TLS1.2>$tls</tt:TLS1.2>" +
                    "<tt:OnboardKeyGeneration>false</tt:OnboardKeyGeneration><tt:AccessPolicyConfig>false</tt:AccessPolicyConfig>" +
                    "<tt:X.509Token>false</tt:X.509Token><tt:SAMLToken>false</tt:SAMLToken>" +
                    "<tt:KerberosToken>false</tt:KerberosToken><tt:RELToken>false</tt:RELToken></tt:Security></tt:Device>" else "") +
                    (if (category != "Device") "<tt:Media><tt:XAddr>$base/media_service</tt:XAddr>" +
                        "<tt:StreamingCapabilities><tt:RTPMulticast>false</tt:RTPMulticast>" +
                        "<tt:RTP_TCP>false</tt:RTP_TCP><tt:RTP_RTSP_TCP>true</tt:RTP_RTSP_TCP>" +
                        "</tt:StreamingCapabilities></tt:Media>" else "") + "</tds:Capabilities>"
            }
            "GetServiceCapabilities" -> deviceCapabilities()
            "GetScopes" -> scopes.split(' ').joinToString("") {
                "<tds:Scopes><tt:ScopeDef>Fixed</tt:ScopeDef><tt:ScopeItem>$it</tt:ScopeItem></tds:Scopes>"
            }
            "GetHostname" -> "<tds:HostnameInformation><tt:FromDHCP>false</tt:FromDHCP>" +
                "<tt:Name>${xml(this.name)}</tt:Name></tds:HostnameInformation>"
            else -> return fault("ter:ActionNotSupported", "Unsupported device operation: ${xml(name)}")
        } else when (name) {
            "GetServiceCapabilities" -> mediaCapabilities()
            "GetProfiles" -> profile("Profiles")
            "GetProfile" -> profile("Profile")
            "GetStreamUri" -> {
                val setup = operation.child(MEDIA, "StreamSetup")
                val transport = setup?.child(SCHEMA, "Transport")?.child(SCHEMA, "Protocol")?.textContent
                if (setup?.child(SCHEMA, "Stream")?.textContent != "RTP-Unicast" || transport != "RTSP") {
                    return fault("ter:InvalidArgVal", "Use RTP-Unicast with RTSP transport", subcode = "ter:InvalidStreamSetup")
                }
                "<trt:MediaUri><tt:Uri>${if (tls) "rtsps" else "rtsp"}://${xml(host)}:$port/camera</tt:Uri>" +
                    "<tt:InvalidAfterConnect>false</tt:InvalidAfterConnect><tt:InvalidAfterReboot>false</tt:InvalidAfterReboot>" +
                    "<tt:Timeout>PT0S</tt:Timeout></trt:MediaUri>"
            }
            "GetVideoSources" -> "<trt:VideoSources token=\"camera\"><tt:Framerate>$fps</tt:Framerate>" +
                "<tt:Resolution><tt:Width>$width</tt:Width><tt:Height>$height</tt:Height></tt:Resolution></trt:VideoSources>"
            "GetVideoSourceConfigurations", "GetCompatibleVideoSourceConfigurations" -> videoSource("trt:Configurations")
            "GetVideoEncoderConfigurations", "GetCompatibleVideoEncoderConfigurations" -> videoEncoder("trt:Configurations")
            "GetVideoSourceConfiguration" -> {
                if (operation.child(MEDIA, "ConfigurationToken")?.textContent != "video_source") return noConfiguration()
                videoSource("trt:Configuration")
            }
            "GetVideoEncoderConfiguration" -> {
                if (operation.child(MEDIA, "ConfigurationToken")?.textContent != "video_encoder") return noConfiguration()
                videoEncoder("trt:Configuration")
            }
            "GetAudioSources" -> if (audio) "<trt:AudioSources token=\"microphone\"><tt:Channels>1</tt:Channels></trt:AudioSources>" else ""
            "GetAudioSourceConfigurations", "GetCompatibleAudioSourceConfigurations" -> if (audio) audioSource("trt:Configurations") else ""
            "GetAudioEncoderConfigurations", "GetCompatibleAudioEncoderConfigurations" -> if (audio) audioEncoder("trt:Configurations") else ""
            "GetAudioSourceConfiguration" -> {
                if (!audio || operation.child(MEDIA, "ConfigurationToken")?.textContent != "audio_source") return noConfiguration()
                audioSource("trt:Configuration")
            }
            "GetAudioEncoderConfiguration" -> {
                if (!audio || operation.child(MEDIA, "ConfigurationToken")?.textContent != "audio_encoder") return noConfiguration()
                audioEncoder("trt:Configuration")
            }
            else -> return fault("ter:ActionNotSupported", "Unsupported media operation: ${xml(name)}")
        }
        val prefix = if (namespace == DEVICE) "tds" else "trt"
        return Response("200 OK", envelope("<$prefix:${name}Response>$content</$prefix:${name}Response>"))
    }

    private fun authenticated(envelope: Element): Boolean {
        if (username == null) return true
        val token = envelope.child(SOAP, "Header")?.child(SECURITY, "Security")?.child(SECURITY, "UsernameToken") ?: return false
        if (token.child(SECURITY, "Username")?.textContent != username) return false
        val supplied = token.child(SECURITY, "Password") ?: return false
        if (!supplied.getAttribute("Type").endsWith("#PasswordDigest")) return false
        val nonce = token.child(SECURITY, "Nonce")?.textContent ?: return false
        val created = token.child(UTILITY, "Created")?.textContent ?: return false
        val timestamp = listOf("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", "yyyy-MM-dd'T'HH:mm:ss'Z'").firstNotNullOfOrNull { pattern ->
            try {
                val format = SimpleDateFormat(pattern, Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC"); isLenient = false }
                val position = java.text.ParsePosition(0)
                format.parse(created, position)?.takeIf { position.index == created.length }?.time
            } catch (_: Exception) { null }
        } ?: return false
        val now = System.currentTimeMillis()
        if (kotlin.math.abs(now - timestamp) > 300_000) return false
        val expected = try {
            encodeBase64(MessageDigest.getInstance("SHA-1").digest(decodeBase64(nonce) + created.toByteArray() + password.toByteArray()))
        } catch (_: Exception) { return false }
        if (!MessageDigest.isEqual(expected.toByteArray(), supplied.textContent.toByteArray())) return false
        synchronized(usedTokens) {
            usedTokens.entries.removeAll { it.value < now - 300_000 }
            val key = expected
            if (usedTokens.containsKey(key) || usedTokens.size >= 2048) return false
            usedTokens[key] = timestamp
        }
        return true
    }

    private fun profile(tag: String) = "<trt:$tag token=\"camera\" fixed=\"true\"><tt:Name>${xml(name)}</tt:Name>" +
        videoSource("tt:VideoSourceConfiguration") + (if (audio) audioSource("tt:AudioSourceConfiguration") else "") +
        videoEncoder("tt:VideoEncoderConfiguration") + (if (audio) audioEncoder("tt:AudioEncoderConfiguration") else "") + "</trt:$tag>"

    private fun videoSource(tag: String) = "<$tag token=\"video_source\"><tt:Name>${xml(name)}</tt:Name><tt:UseCount>1</tt:UseCount>" +
        "<tt:SourceToken>camera</tt:SourceToken><tt:Bounds x=\"0\" y=\"0\" width=\"$width\" height=\"$height\"/></$tag>"

    private fun videoEncoder(tag: String) = "<$tag token=\"video_encoder\"><tt:Name>H.264</tt:Name><tt:UseCount>1</tt:UseCount>" +
        "<tt:Encoding>H264</tt:Encoding><tt:Resolution><tt:Width>$width</tt:Width><tt:Height>$height</tt:Height></tt:Resolution>" +
        "<tt:Quality>5</tt:Quality><tt:RateControl><tt:FrameRateLimit>$fps</tt:FrameRateLimit>" +
        "<tt:EncodingInterval>1</tt:EncodingInterval><tt:BitrateLimit>${bitrate / 1000}</tt:BitrateLimit></tt:RateControl>" +
        "<tt:H264><tt:GovLength>$fps</tt:GovLength><tt:H264Profile>Baseline</tt:H264Profile></tt:H264>" +
        multicast() + "<tt:SessionTimeout>PT60S</tt:SessionTimeout></$tag>"

    private fun audioSource(tag: String) = "<$tag token=\"audio_source\"><tt:Name>Microphone</tt:Name><tt:UseCount>1</tt:UseCount>" +
        "<tt:SourceToken>microphone</tt:SourceToken></$tag>"

    private fun audioEncoder(tag: String) = "<$tag token=\"audio_encoder\"><tt:Name>AAC</tt:Name><tt:UseCount>1</tt:UseCount>" +
        "<tt:Encoding>AAC</tt:Encoding><tt:Bitrate>32</tt:Bitrate><tt:SampleRate>16</tt:SampleRate>" +
        multicast() + "<tt:SessionTimeout>PT60S</tt:SessionTimeout></$tag>"

    private fun multicast() = "<tt:Multicast><tt:Address><tt:Type>IPv4</tt:Type><tt:IPv4Address>0.0.0.0</tt:IPv4Address>" +
        "</tt:Address><tt:Port>0</tt:Port><tt:TTL>1</tt:TTL><tt:AutoStart>false</tt:AutoStart></tt:Multicast>"

    private fun service(prefix: String, namespace: String, address: String, request: Element): String =
        "<tds:Service><tds:Namespace>$namespace</tds:Namespace><tds:XAddr>$address</tds:XAddr>" +
            (if (request.child(DEVICE, "IncludeCapability")?.textContent in listOf("true", "1"))
                "<tds:Capabilities>${if (prefix == "tds") deviceCapabilities() else mediaCapabilities()}</tds:Capabilities>" else "") +
            "<tds:Version><tt:Major>2</tt:Major><tt:Minor>0</tt:Minor></tds:Version></tds:Service>"

    private fun deviceCapabilities() = "<tds:Capabilities><tds:Network IPFilter=\"false\" ZeroConfiguration=\"false\" IPVersion6=\"false\" DynDNS=\"false\"/>" +
        "<tds:Security TLS1.2=\"$tls\" UsernameToken=\"true\" HttpDigest=\"false\"/><tds:System DiscoveryResolve=\"false\" DiscoveryBye=\"true\" RemoteDiscovery=\"false\"/>" +
        "</tds:Capabilities>"

    private fun mediaCapabilities() = "<trt:Capabilities SnapshotUri=\"false\"><trt:ProfileCapabilities MaximumNumberOfProfiles=\"1\"/>" +
        "<trt:StreamingCapabilities RTPMulticast=\"false\" RTP_TCP=\"false\" RTP_RTSP_TCP=\"true\"/></trt:Capabilities>"

    private fun dateAndTime(): String {
        val utc = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        return "<tds:SystemDateAndTime><tt:DateTimeType>Manual</tt:DateTimeType><tt:DaylightSavings>false</tt:DaylightSavings>" +
            "<tt:TimeZone><tt:TZ>UTC0</tt:TZ></tt:TimeZone><tt:UTCDateTime><tt:Time>" +
            "<tt:Hour>${utc.get(Calendar.HOUR_OF_DAY)}</tt:Hour><tt:Minute>${utc.get(Calendar.MINUTE)}</tt:Minute>" +
            "<tt:Second>${utc.get(Calendar.SECOND)}</tt:Second></tt:Time><tt:Date><tt:Year>${utc.get(Calendar.YEAR)}</tt:Year>" +
            "<tt:Month>${utc.get(Calendar.MONTH) + 1}</tt:Month><tt:Day>${utc.get(Calendar.DAY_OF_MONTH)}</tt:Day>" +
            "</tt:Date></tt:UTCDateTime></tds:SystemDateAndTime>"
    }

    private fun noConfiguration() = fault("ter:InvalidArgVal", "Unknown configuration token", subcode = "ter:NoConfig")
    private fun fault(code: String, reason: String, status: String = "500 Internal Server Error", subcode: String? = null) =
        Response(status, envelope("<s:Fault><s:Code><s:Value>s:Sender</s:Value><s:Subcode><s:Value>$code</s:Value>" +
            (if (subcode != null) "<s:Subcode><s:Value>$subcode</s:Value></s:Subcode>" else "") +
            "</s:Subcode></s:Code><s:Reason><s:Text xml:lang=\"en\">$reason</s:Text></s:Reason></s:Fault>"))

    companion object {
        const val SOAP = "http://www.w3.org/2003/05/soap-envelope"
        const val DEVICE = "http://www.onvif.org/ver10/device/wsdl"
        const val MEDIA = "http://www.onvif.org/ver10/media/wsdl"
        const val SCHEMA = "http://www.onvif.org/ver10/schema"
        const val SECURITY = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
        const val UTILITY = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
        const val SCOPES = "onvif://www.onvif.org/Profile/Streaming onvif://www.onvif.org/type/video_encoder"

        fun scopes(deviceName: String): String = SCOPES + " onvif://www.onvif.org/name/" +
            java.net.URLEncoder.encode(deviceName.trim().ifEmpty { "Kiosk Satellite" }, "UTF-8").replace("+", "%20")

        private fun networkInfoFor(host: String): NetworkInfo? = try {
            NetworkInterface.getByInetAddress(InetAddress.getByName(host))?.let { network ->
                val mac = try { readableMac(network.hardwareAddress) } catch (_: Exception) { null }
                val mtu = try { network.mtu.takeIf { it > 0 } } catch (_: Exception) { null }
                NetworkInfo(network.name, network.isUp, mac, mtu)
            }
        } catch (_: Exception) { null }

        internal fun readableMac(bytes: ByteArray?): String? {
            if (bytes == null || bytes.size != 6 || bytes[0].toInt() and 1 != 0) return null
            val mac = bytes.joinToString(":") { "%02X".format(it.toInt() and 255) }
            return mac.takeUnless { it == "00:00:00:00:00:00" || it == "02:00:00:00:00:00" }
        }

        fun xml(text: String): String = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            .replace("\"", "&quot;").replace("'", "&apos;")

        fun parse(bytes: ByteArray): org.w3c.dom.Document {
            require(bytes.size <= 65536)
            // Accept UTF-8 only. Reject declarations before parsing on Android's
            // XML implementation, which does not support every JAXP feature.
            val text = bytes.toString(Charsets.UTF_8)
            require(!text.contains('\u0000') && !Regex("<!\\s*(DOCTYPE|ENTITY)", RegexOption.IGNORE_CASE).containsMatchIn(text))
            val factory = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true; isExpandEntityReferences = false }
            val builder = factory.newDocumentBuilder()
            builder.setEntityResolver { _, _ -> throw org.xml.sax.SAXException("External entities are disabled") }
            return builder.parse(ByteArrayInputStream(text.toByteArray(Charsets.UTF_8)))
        }

        fun Element.child(namespace: String, name: String): Element? = (0 until childNodes.length)
            .map { childNodes.item(it) }.filterIsInstance<Element>().firstOrNull { it.namespaceURI == namespace && it.localName == name }

        fun envelope(body: String) = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
            "<s:Envelope xmlns:s=\"$SOAP\" xmlns:tds=\"$DEVICE\" xmlns:trt=\"$MEDIA\" xmlns:tt=\"$SCHEMA\" " +
            "xmlns:ter=\"http://www.onvif.org/ver10/error\"><s:Body>$body</s:Body></s:Envelope>"
    }
}
