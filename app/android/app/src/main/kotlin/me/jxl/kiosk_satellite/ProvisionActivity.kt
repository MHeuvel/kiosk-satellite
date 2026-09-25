package me.jxl.kiosk_satellite

import android.app.Activity
import android.os.Bundle

/**
 * The only door for a provisioning payload (the `ks.provision` extra):
 *
 *   adb shell am start -n me.jxl.kiosk_satellite/.ProvisionActivity \
 *     --es ks.provision '{"remote.enabled":true,"remote.password":"..."}'
 *
 * The payload is a settings import, admin password included, so it must not
 * be open to every app on the device (issue #695). MainActivity has to stay
 * exported as the launcher, so it no longer reads the extra at all. This
 * Activity is exported behind android.permission.DUMP instead, which the adb
 * shell holds and a regular app cannot get, so the system refuses anyone
 * else before this code runs.
 *
 * It hands the payload to [ProvisionInbox], brings the kiosk up the way any
 * internal launch does and finishes without drawing.
 */
class ProvisionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.getStringExtra(ProvisionInbox.EXTRA)?.let { ProvisionInbox.post(it) }
        HomeRole.launchIntent(this)?.let { startActivity(it) }
        finish()
    }
}

/**
 * Holds a provisioning payload from [ProvisionActivity] until MainActivity's
 * provisioning channel takes it: pushed on attach or on a new intent, or
 * pulled by Dart at startup. Taking clears it, so a payload applies once.
 * Every caller is on the main thread.
 */
object ProvisionInbox {
    const val EXTRA = "ks.provision"

    private var pending: String? = null

    fun post(json: String) {
        pending = json
    }

    fun take(): String? = pending.also { pending = null }
}
