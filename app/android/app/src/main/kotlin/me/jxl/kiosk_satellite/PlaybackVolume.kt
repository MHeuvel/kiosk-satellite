package me.jxl.kiosk_satellite

/** Maps the app's faders into the available output range. */
internal object PlaybackVolume {
    fun level(base: Float, assistant: Float, master: Float): Float =
        (base.toDouble() * assistant * master).coerceIn(0.0, 1.0).toFloat()
}
