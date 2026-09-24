package me.jxl.kiosk_satellite

import java.io.StringReader
import java.io.StringWriter
import java.math.BigInteger
import java.security.KeyPairGenerator
import java.security.KeyFactory
import java.security.spec.PKCS8EncodedKeySpec
import java.security.KeyStore
import java.security.PrivateKey
import java.security.SecureRandom
import java.security.Signature
import java.security.cert.X509Certificate
import java.security.spec.ECGenParameterSpec
import java.util.Date
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.asn1.x509.*
import org.bouncycastle.cert.X509CertificateHolder
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.openssl.PEMKeyPair
import org.bouncycastle.openssl.PEMParser
import org.bouncycastle.openssl.jcajce.JcaPEMWriter
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import org.bouncycastle.asn1.pkcs.PrivateKeyInfo

/** Certificate operations shared by the Android bridge and JVM tests. */
class TlsMaterial(val certificates: List<X509Certificate>, val key: PrivateKey, val imported: Boolean = false) {
    val certificate get() = certificates.first()
    private fun pem(value: Any): String = StringWriter().also { out ->
        JcaPEMWriter(out).use { it.writeObject(value) }
    }.toString()

    fun toMap(): Map<String, Any> = mapOf(
        "certificate" to certificates.joinToString("") { pem(it) },
        "privateKey" to pem(org.bouncycastle.util.io.pem.PemObject("PRIVATE KEY", key.encoded)),
        "notAfter" to certificate.notAfter.time,
        "imported" to imported,
    )

    fun validate() {
        certificates.forEach { it.checkValidity() }
        require(certificate.basicConstraints < 0) { "Use a server certificate, not a CA certificate." }
        require(certificate.extendedKeyUsage?.contains("1.3.6.1.5.5.7.3.1") != false) { "Certificate does not allow server authentication." }
        val algorithm = when (key.algorithm) {
            "EC" -> "SHA256withECDSA"
            "RSA" -> "SHA256withRSA"
            else -> error("Use an EC or RSA private key.")
        }
        val challenge = ByteArray(32).also { SecureRandom().nextBytes(it) }
        val signature = Signature.getInstance(algorithm).run { initSign(key); update(challenge); sign() }
        require(Signature.getInstance(algorithm).run {
            initVerify(certificate.publicKey); update(challenge); verify(signature)
        }) { "Certificate and private key do not match." }
    }

    fun sslContext(): SSLContext {
        validate()
        val password = CharArray(32) { SecureRandom().nextInt(94).plus(33).toChar() }
        val store = KeyStore.getInstance(KeyStore.getDefaultType()).apply {
            load(null); setKeyEntry("server", key, password, certificates.toTypedArray())
        }
        val managers = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm()).apply { init(store, password) }
        return SSLContext.getInstance("TLS").apply { init(managers.keyManagers, null, null) }
    }

    companion object {
        fun parse(certificate: String, privateKey: String, imported: Boolean = false): TlsMaterial {
            require(certificate.length <= 65536 && privateKey.length <= 32768) { "Certificate or key is too large." }
            val chain = mutableListOf<X509Certificate>()
            PEMParser(StringReader(certificate)).use { reader ->
                while (true) {
                    val item = reader.readObject() ?: break
                    require(item is X509CertificateHolder) { "Expected PEM certificates." }
                    chain.add(JcaX509CertificateConverter().getCertificate(item))
                }
            }
            require(chain.isNotEmpty()) { "No certificate found." }
            val value = PEMParser(StringReader(privateKey)).use { it.readObject() }
            val info = when (value) {
                is PrivateKeyInfo -> value
                is PEMKeyPair -> value.privateKeyInfo
                else -> error("Use an unencrypted PEM private key.")
            }
            val algorithm = when (info.privateKeyAlgorithm.algorithm.id) {
                "1.2.840.10045.2.1" -> "EC"
                "1.2.840.113549.1.1.1" -> "RSA"
                else -> error("Use an EC or RSA private key.")
            }
            val key = KeyFactory.getInstance(algorithm).generatePrivate(PKCS8EncodedKeySpec(info.encoded))
            return TlsMaterial(chain, key, imported)
        }

        fun generate(names: List<String>, addresses: List<String>, previous: TlsMaterial? = null): TlsMaterial {
            val pair = if (previous == null) KeyPairGenerator.getInstance("EC").apply {
                initialize(ECGenParameterSpec("secp256r1"))
            }.generateKeyPair() else java.security.KeyPair(previous.certificate.publicKey, previous.key)
            val subject = X500Name("CN=Kiosk Satellite")
            val now = System.currentTimeMillis()
            val builder = JcaX509v3CertificateBuilder(subject, BigInteger(159, SecureRandom()),
                Date(now - 300_000), Date(now + 365L * 86_400_000), subject, pair.public)
            builder.addExtension(Extension.basicConstraints, true, BasicConstraints(false))
            builder.addExtension(Extension.keyUsage, true, KeyUsage(KeyUsage.digitalSignature))
            builder.addExtension(Extension.extendedKeyUsage, false, ExtendedKeyUsage(KeyPurposeId.id_kp_serverAuth))
            val sans = names.distinct().map { GeneralName(GeneralName.dNSName, it) } +
                addresses.distinct().map { GeneralName(GeneralName.iPAddress, it) }
            require(sans.isNotEmpty()) { "A hostname or IP address is required." }
            builder.addExtension(Extension.subjectAlternativeName, false, GeneralNames(sans.toTypedArray()))
            val signer = JcaContentSignerBuilder("SHA256withECDSA").build(pair.private)
            return TlsMaterial(listOf(JcaX509CertificateConverter().getCertificate(builder.build(signer))), pair.private)
                .also { it.validate() }
        }
    }
}
