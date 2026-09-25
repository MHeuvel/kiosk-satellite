package me.jxl.kiosk_satellite

import org.junit.Assert.*
import org.junit.Test
import java.net.Socket
import java.security.cert.X509Certificate
import java.util.Base64
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocket
import javax.net.ssl.X509TrustManager

class TlsMaterialTest {
    private fun material() = TlsMaterial.generate(listOf("tablet.local"), listOf("127.0.0.1", "::1"))

    @Test fun certificateRoundTripAndRenewalPreserveThePublicKey() {
        val original = material()
        original.certificate.verify(original.certificate.publicKey)
        assertEquals(-1, original.certificate.basicConstraints)
        assertTrue(original.certificate.extendedKeyUsage.contains("1.3.6.1.5.5.7.3.1"))
        assertEquals(3, original.certificate.subjectAlternativeNames.size)
        val map = original.toMap()
        val parsed = TlsMaterial.parse(map["certificate"] as String, map["privateKey"] as String)
        parsed.validate()
        val renewed = TlsMaterial.generate(listOf("renamed.local"), listOf("127.0.0.2"), parsed)
        assertArrayEquals(original.certificate.publicKey.encoded, renewed.certificate.publicKey.encoded)
        assertNotEquals(original.certificate.serialNumber, renewed.certificate.serialNumber)
        assertNotEquals(original.certificate.subjectAlternativeNames, renewed.certificate.subjectAlternativeNames)
    }

    @Test fun mismatchedPrivateKeyIsRejected() {
        val a = material().toMap()
        val b = material().toMap()
        assertThrows(Exception::class.java) {
            TlsMaterial.parse(a["certificate"] as String, b["privateKey"] as String).sslContext()
        }
    }

    @Test fun malformedMaterialDoesNotProduceAListener() {
        assertThrows(Exception::class.java) { TlsMaterial.parse("invalid", "invalid").sslContext() }
    }

    private fun clientContext(): SSLContext = SSLContext.getInstance("TLS").apply {
        init(null, arrayOf(object : X509TrustManager {
            override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
            override fun checkClientTrusted(chain: Array<X509Certificate>, auth: String) = Unit
            override fun checkServerTrusted(chain: Array<X509Certificate>, auth: String) = Unit
        }), null)
    }

    private fun server() = CameraRtspServer(0, null, "", { Base64.getEncoder().encodeToString(it) }, {}, {}, onDiagnostic = { event, message, cause ->
        if (cause != null) System.err.println("$event: $message: $cause")
    }, tls = material().sslContext())

    @Test fun silentAndPlaintextClientsDoNotBlockTlsViewersOrShutdown() {
        val server = server()
        val silent = Socket("127.0.0.1", server.localPort)
        try {
            Socket("127.0.0.1", server.localPort).use { plain ->
                plain.soTimeout = 2000
                plain.getOutputStream().write("OPTIONS * RTSP/1.0\r\nCSeq: 1\r\n\r\n".toByteArray())
                // A TLS alert or a closed socket is acceptable. An RTSP reply is not.
                val first = runCatching { plain.getInputStream().read() }.getOrDefault(-1)
                assertNotEquals('R'.code, first)
            }
            (clientContext().socketFactory.createSocket("127.0.0.1", server.localPort) as SSLSocket).use { peer ->
                peer.soTimeout = 2000
                peer.startHandshake()
                peer.getOutputStream().write("OPTIONS * RTSP/1.0\r\nCSeq: 1\r\n\r\n".toByteArray())
                assertEquals("RTSP/1.0 200 OK", peer.inputStream.bufferedReader().readLine())
            }
            assertTrue(server.listening)
            CompletableFuture.runAsync { server.close() }.get(2, TimeUnit.SECONDS)
        } finally { silent.close(); server.close() }
    }

    @Test fun onvifSoapAndRtspShareTlsWithoutPlaintextFallback() {
        val onvif = CameraOnvifService(640, 480, 10, 500_000, true, null, "",
            { Base64.getEncoder().encodeToString(it) }, { Base64.getDecoder().decode(it) },
            "device-id", "test", tls = true)
        val server = CameraRtspServer(0, null, "", { Base64.getEncoder().encodeToString(it) }, {}, {},
            onvif = onvif, tls = material().sslContext())
        val silent = Socket("127.0.0.1", server.localPort)
        try {
            val body = "<s:Envelope xmlns:s=\"${CameraOnvifService.SOAP}\" xmlns:tds=\"${CameraOnvifService.DEVICE}\">" +
                "<s:Body><tds:GetServices/></s:Body></s:Envelope>"
            val request = ("POST /onvif/device_service HTTP/1.1\r\nHost: localhost\r\n" +
                "Content-Length: ${body.toByteArray().size}\r\n\r\n$body").toByteArray()
            Socket("127.0.0.1", server.localPort).use { plain ->
                plain.soTimeout = 2000
                plain.outputStream.write(request)
                assertNotEquals('H'.code, runCatching { plain.inputStream.read() }.getOrDefault(-1))
            }
            clientContext().socketFactory.createSocket("127.0.0.1", server.localPort).use { peer ->
                peer.soTimeout = 2000
                peer.outputStream.write(request)
                val response = peer.inputStream.readBytes().toString(Charsets.UTF_8)
                assertTrue(response.startsWith("HTTP/1.1 200 OK"))
                assertTrue(response.contains("https://127.0.0.1:${server.localPort}/onvif/media_service"))
                assertFalse(server.demand)
            }
            clientContext().socketFactory.createSocket("127.0.0.1", server.localPort).use { peer ->
                peer.soTimeout = 2000
                peer.outputStream.write("OPTIONS * RTSP/1.0\r\nCSeq: 1\r\n\r\n".toByteArray())
                assertEquals("RTSP/1.0 200 OK", peer.inputStream.bufferedReader().readLine())
            }
            CompletableFuture.runAsync { server.close() }.get(2, TimeUnit.SECONDS)
        } finally { silent.close(); server.close() }
    }

    @Test fun acceptingAClientDoesNotObtainStreams() {
        val server = server()
        try {
            val socket = object : Socket() {
                override fun getInputStream(): java.io.InputStream = error("Input obtained before client worker")
                override fun getOutputStream(): java.io.OutputStream = error("Output obtained before client worker")
            }
            val client = CameraRtspServer::class.java.declaredClasses.first { it.simpleName == "Client" }
            client.getDeclaredConstructor(CameraRtspServer::class.java, Socket::class.java)
                .apply { isAccessible = true }.newInstance(server, socket)
        } finally { server.close() }
    }
}
