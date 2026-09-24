package me.jxl.kiosk_satellite

import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.os.Looper
import org.robolectric.Robolectric
import org.robolectric.Shadows.shadowOf
import android.content.Context
import android.content.res.Configuration
import java.util.Locale
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 33], application = Application::class)
class NativeMessagesTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private fun save(language: String?) {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit().putString("flutter.ks.ui.language", language).commit()
    }
    private fun device(language: String): Context {
        val config = Configuration(context.resources.configuration)
        config.setLocale(Locale.forLanguageTag(language))
        return context.createConfigurationContext(config)
    }

    @Test fun savedKioskLanguageWinsOverSystemAndSurvivesNewContexts() {
        save("es")
        val first = NativeMessages.forKiosk(device("en"))
        assertEquals("es", first.resources.configuration.locales[0].language)
        assertEquals("Servicio de Kiosk Satellite", first.getString(R.string.ks_service_title))
        val recreated = NativeMessages.forKiosk(device("de"))
        assertEquals(first.getString(R.string.ks_service_title), recreated.getString(R.string.ks_service_title))
        save("en")
        val changed = NativeMessages.forKiosk(device("es"))
        assertEquals("Kiosk Satellite Service", changed.getString(R.string.ks_service_title))
        assertEquals("es", device("es").resources.configuration.locales[0].language)
    }

    @Test fun missingAndUnsupportedPreferencesUseEnglish() {
        for (language in listOf(null, "system", "xx", "es-MX")) {
            save(language)
            val strings = NativeMessages.forKiosk(device("es"))
            assertEquals("en", strings.resources.configuration.locales[0].language)
            assertEquals("Kiosk Satellite Service", strings.getString(R.string.ks_service_title))
        }
    }

    @Test fun liveNotificationAndChannelChangeLanguageWithoutRestartingService() {
        save("en")
        val controller = Robolectric.buildService(KioskSatelliteService::class.java).create()
        val service = controller.get()
        val manager = context.getSystemService(NotificationManager::class.java)
        try {
            assertEquals("Kiosk Satellite Service", shadowOf(service).lastForegroundNotification.extras.getString(Notification.EXTRA_TITLE))
            val before = manager.getNotificationChannel("kiosk_satellite_service")
            save("es")
            KioskSatelliteService.apply(context, setOf("remote"), true)
            shadowOf(Looper.getMainLooper()).idle()
            assertTrue(KioskSatelliteService.isRunning)
            assertTrue(KioskSatelliteService.isForeground)
            assertEquals("Servicio de Kiosk Satellite", shadowOf(service).lastForegroundNotification.extras.getString(Notification.EXTRA_TITLE))
            val after = manager.getNotificationChannel("kiosk_satellite_service")
            assertEquals("Servicio de Kiosk Satellite", after.name.toString())
            assertEquals(before.importance, after.importance)
            assertEquals(setOf("remote", "sessions"), (KioskSatelliteService.status(context)["reasons"] as List<*>).toSet())
        } finally { controller.destroy() }
        val restarted = Robolectric.buildService(KioskSatelliteService::class.java).create()
        try {
            assertEquals("Servicio de Kiosk Satellite", shadowOf(restarted.get()).lastForegroundNotification.extras.getString(Notification.EXTRA_TITLE))
            assertEquals(setOf("remote", "sessions"), (KioskSatelliteService.status(context)["reasons"] as List<*>).toSet())
        } finally { restarted.destroy() }
    }

    @Test fun serviceSummaryPreservesReasonOrderAndBaseConnection() {
        save("en")
        val strings = NativeMessages.forKiosk(context)
        val service = KioskSatelliteService()
        assertEquals("Keeping Home Assistant connected.", service.summary(emptySet(), strings))
        assertEquals(
            "Listening for a wake word, RTSP microphone audio enabled, serving ESPHome, relaying Bluetooth devices, watching the camera, reporting the location, serving the remote admin, guarding kiosk mode, keeping Home Assistant connected.",
            service.summary(setOf("remote", "camera", "listening", "rtsp_audio", "esphome", "bluetooth", "location", "kiosk", "unknown"), strings),
        )
        assertEquals("Serving the remote admin, keeping Home Assistant connected.", service.summary(setOf("remote", "unknown"), strings))
    }
}
