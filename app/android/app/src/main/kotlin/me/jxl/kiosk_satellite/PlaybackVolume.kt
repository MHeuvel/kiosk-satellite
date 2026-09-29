package me.jxl.kiosk_satellite

/** Maps the app's faders into the available output range. */
internal object PlaybackVolume {
    /**
     * Gain that makes the call stream follow the media stream's level.
     * Each stream is measured against its own maximum because some
     * firmware reports the two volume tables with different reference
     * points. The LG V30 reports media at its maximum about 46 dB below
     * the call stream at its maximum.
     */
    fun compensation(masterDb: Float, masterMaxDb: Float, callDb: Float, callMaxDb: Float): Float =
        Math.pow(10.0, ((masterDb.toDouble() - masterMaxDb) - (callDb.toDouble() - callMaxDb)) / 20.0)
            .coerceAtMost(Float.MAX_VALUE.toDouble()).toFloat()

    fun level(base: Float, assistant: Float, compensation: Float): Float =
        // Compensation can exceed one without amplifying the final signal
        // above one. Clamp after applying the faders to preserve that range.
        (base.toDouble() * assistant * compensation).coerceIn(0.0, 1.0).toFloat()
}
