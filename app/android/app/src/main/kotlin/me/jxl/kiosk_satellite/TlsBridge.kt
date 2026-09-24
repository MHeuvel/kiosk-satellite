package me.jxl.kiosk_satellite

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.NetworkInterface
import java.security.KeyStore
import java.util.Collections
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONObject

/** Keeps the exportable server key encrypted under a device Keystore key. */
class TlsBridge(context: Context, messenger: BinaryMessenger) {
    private val file = AtomicFile(File(context.noBackupFilesDir, "tls-identity"))
    private val worker = Executors.newSingleThreadExecutor { Thread(it, "ks-tls").apply { isDaemon = true } }
    private val main = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, "kiosk_satellite/tls").setMethodCallHandler { call, result ->
            worker.execute {
                try {
                    val old = if (call.method == "replace" || call.method == "import") null else load()
                    val material = when (call.method) {
                        "load" -> old ?: generate(call.argument<String>("hostname"), null)
                        "renew" -> {
                            require(old?.imported != true) { "Import a renewed certificate from its issuer." }
                            generate(call.argument<String>("hostname"), old)
                        }
                        "replace" -> generate(call.argument<String>("hostname"), null)
                        "import" -> TlsMaterial.parse(call.argument<String>("certificate") ?: "",
                            call.argument<String>("privateKey") ?: "", true).also { it.validate() }
                        else -> { main.post { result.notImplemented() }; return@execute }
                    }
                    if (old == null || call.method != "load") save(material)
                    val map = material.toMap()
                    main.post { result.success(map) }
                } catch (e: Exception) {
                    main.post { result.error("tls", e.message ?: "Certificate operation failed.", null) }
                }
            }
        }
    }

    private fun generate(hostname: String?, old: TlsMaterial?): TlsMaterial {
        val addresses = Collections.list(NetworkInterface.getNetworkInterfaces())
            .flatMap { Collections.list(it.inetAddresses) }
            .filter { !it.isLoopbackAddress && !it.isLinkLocalAddress }
            .mapNotNull { it.hostAddress?.substringBefore('%') }
        return TlsMaterial.generate(listOf("localhost") +
            listOfNotNull(hostname?.takeIf { it.isNotBlank() }?.let { "$it.local" }),
            addresses + listOf("127.0.0.1", "::1"), old)
    }

    private fun storageKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("ks-tls-storage", null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder("ks-tls-storage", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }

    private fun load(): TlsMaterial? {
        if (!file.baseFile.exists() && !File(file.baseFile.path + ".bak").exists()) return null
        val bytes = file.readFully()
        require(bytes.size > 28) { "Stored TLS identity is damaged." }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
            init(Cipher.DECRYPT_MODE, storageKey(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        }
        val json = JSONObject(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8))
        return TlsMaterial.parse(json.getString("certificate"), json.getString("privateKey"), json.optBoolean("imported"))
    }

    private fun save(material: TlsMaterial) {
        material.validate()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, storageKey()) }
        val bytes = cipher.iv + cipher.doFinal(JSONObject(material.toMap()).toString().toByteArray(Charsets.UTF_8))
        val stream = file.startWrite()
        try { stream.write(bytes); file.finishWrite(stream) }
        catch (e: Exception) { file.failWrite(stream); throw e }
    }
}
