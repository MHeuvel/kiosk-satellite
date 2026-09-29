package me.jxl.kiosk_satellite

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * The Media Session player source: another app's media session on this
 * device (a Spotify Connect receiver, a podcast app) followed by the Now
 * Playing surfaces.
 *
 * Dart names the app to follow, or "*" for whichever app plays, and gets a
 * snapshot pushed on every metadata or playback change, in the map shape
 * every player source publishes. Transport commands go back through the
 * session's own controls. Reading other apps' sessions needs the
 * "Notification access" grant for [MediaSessionListener]; without it the
 * bridge keeps the pick and starts following the moment the grant lands.
 *
 * Cover art stays here: a snapshot names it by a mediasession:// URL and
 * Dart asks for the bytes once per track.
 */
class MediaSessionBridge(
    context: Context,
    messenger: BinaryMessenger,
) {
    companion object {
        private const val TAG = "MediaSessionBridge"
        private const val ART_MAX_PX = 512
        private const val ACCESS_POLL_MS = 5_000L

        @Volatile
        private var instance: MediaSessionBridge? = null

        /** The listener connected: the sessions may be readable now. */
        fun accessChanged() {
            val bridge = instance ?: return
            bridge.main.post { bridge.rewire() }
        }

        /** The transport commands a session's actions allow. A session
         *  that reports no actions at all gets the basics, the same
         *  leniency the system media controls show it. */
        internal fun commandsFor(actions: Long, durationMs: Long): List<String> {
            if (actions == 0L) return listOf("play", "pause", "next", "previous")
            fun has(bit: Long) = actions and bit != 0L
            return buildList {
                if (has(PlaybackState.ACTION_PLAY) || has(PlaybackState.ACTION_PLAY_PAUSE)) add("play")
                if (has(PlaybackState.ACTION_PAUSE) || has(PlaybackState.ACTION_PLAY_PAUSE)) add("pause")
                if (has(PlaybackState.ACTION_STOP)) add("stop")
                if (has(PlaybackState.ACTION_SKIP_TO_NEXT)) add("next")
                if (has(PlaybackState.ACTION_SKIP_TO_PREVIOUS)) add("previous")
                if (has(PlaybackState.ACTION_SEEK_TO) && durationMs > 0) add("seek")
            }
        }

        internal fun isPlaying(state: Int) =
            state == PlaybackState.STATE_PLAYING ||
                state == PlaybackState.STATE_BUFFERING ||
                state == PlaybackState.STATE_CONNECTING ||
                state == PlaybackState.STATE_FAST_FORWARDING ||
                state == PlaybackState.STATE_REWINDING ||
                state == PlaybackState.STATE_SKIPPING_TO_NEXT ||
                state == PlaybackState.STATE_SKIPPING_TO_PREVIOUS ||
                state == PlaybackState.STATE_SKIPPING_TO_QUEUE_ITEM

        /** Playing or paused: what the surfaces show. A stopped or failed
         *  session has nothing to say. */
        internal fun isShowable(state: Int) =
            isPlaying(state) || state == PlaybackState.STATE_PAUSED
    }

    private val context = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "kiosk_satellite/media_sessions")
    private val worker = MethodWorker("ks-mediaSessionArt")
    private val manager =
        this.context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
    private val component = ComponentName(this.context, MediaSessionListener::class.java)

    // Main thread only.
    private var target: String? = null
    private var sessionsListener: MediaSessionManager.OnActiveSessionsChangedListener? = null
    private val watched = mutableListOf<Pair<MediaController, MediaController.Callback>>()
    private var followed: MediaController? = null
    private var pushedNull = false
    private var polling = false

    // Read on the art worker too.
    private val arts = object : LinkedHashMap<String, Any>(8, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Any>?) = size > 4
    }

    private val accessPoll = object : Runnable {
        override fun run() {
            polling = false
            if (target != null) rewire()
        }
    }

    init {
        instance = this
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAccess" -> result.success(hasAccess())
                "requestAccess" -> {
                    try {
                        requestAccess()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("access", e.message, null)
                    }
                }
                "follow" -> {
                    target = call.argument<String>("package")?.ifEmpty { null }
                    pushedNull = false
                    rewire()
                    result.success(true)
                }
                "unfollow" -> {
                    target = null
                    unwire()
                    result.success(true)
                }
                "refresh" -> {
                    pushedNull = false
                    select()
                    result.success(true)
                }
                "control" -> result.success(control(call.argument<String>("command") ?: ""))
                "seek" -> {
                    val controls = followed?.transportControls
                    controls?.seekTo((call.argument<Number>("positionMs") ?: 0).toLong())
                    result.success(controls != null)
                }
                "artwork" -> {
                    val url = call.argument<String>("url") ?: ""
                    worker.read(result) { artwork(url) }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAccess(): Boolean = try {
        NotificationManagerCompat.getEnabledListenerPackages(context)
            .contains(context.packageName)
    } catch (_: Exception) {
        false
    }

    /** Open Android's Notification access screen: this app's own row where
     *  the release has one (11+), the list otherwise. */
    private fun requestAccess() {
        val intents = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                add(
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                        .putExtra(
                            Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                            component.flattenToString(),
                        ),
                )
            }
            add(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
        for (intent in intents) {
            try {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (_: Exception) {
                // Some builds drop the detail screen; the list is one tap higher.
            }
        }
        throw IllegalStateException("No Notification access screen on this device")
    }

    private fun sessions(): List<MediaController> =
        manager.getActiveSessions(component).filter { it.packageName != context.packageName }

    private fun appName(pkg: String): String = try {
        val pm = context.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (_: Exception) {
        pkg
    }

    private fun unwire() {
        main.removeCallbacks(accessPoll)
        polling = false
        for ((controller, callback) in watched) {
            try {
                controller.unregisterCallback(callback)
            } catch (_: Exception) {
            }
        }
        watched.clear()
        followed = null
        sessionsListener?.let {
            try {
                manager.removeOnActiveSessionsChangedListener(it)
            } catch (_: Exception) {
            }
        }
        sessionsListener = null
    }

    /** Watch every session but our own and pick the one to show. Rerun
     *  whenever the set of sessions changes. */
    private fun rewire() {
        val wanted = target
        unwire()
        if (wanted == null) return
        if (!hasAccess()) {
            push(null)
            pollForAccess()
            return
        }
        val controllers = try {
            val listener = MediaSessionManager.OnActiveSessionsChangedListener { main.post { rewire() } }
            manager.addOnActiveSessionsChangedListener(listener, component, main)
            sessionsListener = listener
            sessions()
        } catch (e: SecurityException) {
            Log.w(TAG, "sessions not readable yet: ${e.message}")
            push(null)
            pollForAccess()
            return
        }
        for (controller in controllers) {
            val callback = object : MediaController.Callback() {
                override fun onPlaybackStateChanged(state: PlaybackState?) = select()
                override fun onMetadataChanged(metadata: MediaMetadata?) = select()
                override fun onSessionDestroyed() {
                    main.post { rewire() }
                }
            }
            try {
                controller.registerCallback(callback, main)
                watched.add(controller to callback)
            } catch (e: Exception) {
                Log.w(TAG, "cannot watch ${controller.packageName}: ${e.message}")
            }
        }
        select()
    }

    /** The grant landed without the listener telling us (some builds
     *  bind it late): look again every few seconds while following. */
    private fun pollForAccess() {
        if (polling) return
        polling = true
        main.postDelayed(accessPoll, ACCESS_POLL_MS)
    }

    /** The session the surfaces follow: the picked app's, or with "*" the
     *  one playing, keeping the current one while nothing else plays. */
    private fun select() {
        val wanted = target ?: return
        val candidates = watched.map { it.first }
            .filter { wanted == "*" || it.packageName == wanted }
        fun state(c: MediaController) = c.playbackState?.state ?: PlaybackState.STATE_NONE
        val current = followed?.let { f -> candidates.firstOrNull { it.sessionToken == f.sessionToken } }
        val chosen = current?.takeIf { isPlaying(state(it)) }
            ?: candidates.firstOrNull { isPlaying(state(it)) }
            ?: current?.takeIf { isShowable(state(it)) }
            ?: candidates.firstOrNull { isShowable(state(it)) }
        followed = chosen
        push(chosen?.let { snapshot(it) })
    }

    private fun snapshot(c: MediaController): Map<String, Any?>? {
        val metadata = c.metadata ?: return null
        val state = c.playbackState
        val code = state?.state ?: PlaybackState.STATE_NONE
        if (!isShowable(code)) return null
        val title = metadata.getString(MediaMetadata.METADATA_KEY_TITLE)
            ?.takeIf { it.isNotBlank() }
            ?: metadata.description?.title?.toString().orEmpty()
        if (title.isBlank()) return null
        val artist = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?.takeIf { it.isNotBlank() }
            ?: metadata.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)?.takeIf { it.isNotBlank() }
            ?: metadata.description?.subtitle?.toString().orEmpty()
        val album = metadata.getString(MediaMetadata.METADATA_KEY_ALBUM).orEmpty()
        val durationMs = metadata.getLong(MediaMetadata.METADATA_KEY_DURATION)
        val playing = isPlaying(code)
        var positionMs = state?.position?.coerceAtLeast(0L) ?: 0L
        if (playing && state != null && state.lastPositionUpdateTime > 0) {
            val elapsed = SystemClock.elapsedRealtime() - state.lastPositionUpdateTime
            if (elapsed > 0) positionMs += (elapsed * state.playbackSpeed).toLong()
        }
        if (durationMs > 0) positionMs = positionMs.coerceAtMost(durationMs)
        return buildMap {
            put("title", title.trim())
            if (artist.isNotBlank()) put("artist", artist.trim())
            if (album.isNotBlank()) put("album", album.trim())
            if (durationMs > 0) put("durationMs", durationMs)
            put("positionMs", positionMs)
            put("receivedAt", System.currentTimeMillis())
            put("playing", playing)
            put("supportedCommands", commandsFor(state?.actions ?: 0L, durationMs))
            put("package", c.packageName)
            put("appName", appName(c.packageName))
            artworkUrl(c.packageName, metadata, title, artist, album)?.let { put("artworkUrl", it) }
        }
    }

    /** The cover's URL: a plain web address as the app gave it, or a
     *  mediasession:// name for a bitmap or a local URI kept here. The
     *  name follows the track, not the bitmap object, so an app that
     *  republishes the same metadata does not make the cover reload. */
    private fun artworkUrl(
        pkg: String,
        metadata: MediaMetadata,
        title: String,
        artist: String,
        album: String,
    ): String? {
        val bitmap = metadata.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: metadata.getBitmap(MediaMetadata.METADATA_KEY_ART)
            ?: metadata.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON)
        val uri = metadata.getString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI)
            ?: metadata.getString(MediaMetadata.METADATA_KEY_ART_URI)
            ?: metadata.getString(MediaMetadata.METADATA_KEY_DISPLAY_ICON_URI)
        if (bitmap == null && uri.isNullOrBlank()) return null
        if (bitmap == null && (uri!!.startsWith("http://") || uri.startsWith("https://"))) return uri
        val shape = if (bitmap != null) "${bitmap.width}x${bitmap.height}" else uri
        val key = Integer.toHexString("$pkg|$title|$artist|$album|$shape".hashCode())
        synchronized(arts) { arts[key] = bitmap ?: Uri.parse(uri) }
        return "mediasession://art/$key"
    }

    /** JPEG bytes for a mediasession:// cover, downsampled. On the art
     *  worker. */
    private fun artwork(url: String): ByteArray? {
        val key = url.substringAfterLast('/')
        val source = synchronized(arts) { arts[key] } ?: return null
        val bitmap = when (source) {
            is Bitmap -> source
            is Uri -> try {
                context.contentResolver.openInputStream(source)?.use { BitmapFactory.decodeStream(it) }
            } catch (e: Exception) {
                Log.w(TAG, "cover $source: ${e.message}")
                null
            }
            else -> null
        } ?: return null
        val scale = minOf(1f, ART_MAX_PX.toFloat() / maxOf(bitmap.width, bitmap.height))
        val scaled = if (scale < 1f) {
            Bitmap.createScaledBitmap(
                bitmap,
                (bitmap.width * scale).toInt().coerceAtLeast(1),
                (bitmap.height * scale).toInt().coerceAtLeast(1),
                true,
            )
        } else {
            bitmap
        }
        return ByteArrayOutputStream().use { out ->
            scaled.compress(Bitmap.CompressFormat.JPEG, 90, out)
            out.toByteArray()
        }
    }

    private fun control(command: String): Boolean {
        val controls = followed?.transportControls ?: return false
        when (command) {
            "play" -> controls.play()
            "pause" -> controls.pause()
            "stop" -> controls.stop()
            "next" -> controls.skipToNext()
            "previous" -> controls.skipToPrevious()
            else -> return false
        }
        return true
    }

    private fun push(snapshot: Map<String, Any?>?) {
        // Nothing to show twice in a row is one message.
        if (snapshot == null) {
            if (pushedNull) return
            pushedNull = true
        } else {
            pushedNull = false
        }
        try {
            channel.invokeMethod("snapshot", snapshot)
        } catch (e: Exception) {
            Log.w(TAG, "snapshot push failed: ${e.message}")
        }
    }
}
