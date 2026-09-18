package me.jxl.kiosk_satellite

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/** Uses the same saved preference as Flutter, including before Flutter starts. */
internal object NativeMessages {
    fun forKiosk(context: Context): Context {
        val saved = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.ks.ui.language", "en")
        val available = context.resources.getStringArray(R.array.ks_message_languages)
        val language = saved?.takeIf { it in available } ?: "en"
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocale(Locale.forLanguageTag(language))
        return context.createConfigurationContext(configuration)
    }
}
