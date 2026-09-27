package me.jxl.kiosk_satellite

import android.service.notification.NotificationListenerService

/**
 * The component Android's "Notification access" grant names. Android only
 * lists other apps' media sessions to an app whose listener is enabled
 * (MediaSessionManager.getActiveSessions), so this service exists for the
 * grant alone: it reads no notifications. The Media Session player source
 * follows other apps through [MediaSessionBridge].
 */
class MediaSessionListener : NotificationListenerService() {
    // The system binds the listener once the grant lands, which is the
    // moment the sessions become readable.
    override fun onListenerConnected() {
        MediaSessionBridge.accessChanged()
    }
}
