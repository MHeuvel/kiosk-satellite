package me.jxl.kiosk_satellite

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import androidx.camera.core.ImageProxy
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import android.os.SystemClock
import kotlin.math.atan2
import kotlin.math.max
import kotlin.math.sqrt

/**
 * The hands behind the Show fingers gesture, through MediaPipe's own
 * hand landmarker task: palm detection, per-frame tracking, landmark
 * smoothing and the full landmark model in one graph, fed the analyzer's
 * frames in live-stream mode (the graph drops frames while busy). The
 * result listener counts the raised fingers of the largest hand with
 * the one rule every landmark demo uses: a finger is up when its tip is
 * farther from the wrist than its middle knuckle (a curled finger's tip
 * comes back toward the wrist). The thumb has no such joint to read, and
 * a thumb resting slightly out beside two shown fingers read as a third
 * every other look, so it only counts once all four fingers are up: an
 * open hand is five when the thumb leads out from the palm (its tip
 * farther from the pinky knuckle than its own joint), four when it is
 * tucked across the palm, the way a hand shows four. No angle thresholds
 * and no margins: on these landmarks they only ever cost real shows. The
 * rule is orientation and handedness invariant. Detection is not
 * recognition: nothing is identified, stored or compared.
 */
class HandTracker(
    private val context: Context,
    private val onResult: (hands: Int, read: HandRead?, atNs: Long) -> Unit,
) {
    companion object {
        private const val TAG = "HandTracker"
        private const val MODEL = "hand_landmarker.task"
        private const val TRACE_EVERY = 100
    }

    private var landmarker: HandLandmarker? = null
    private var failed = false
    private var bitmap: Bitmap? = null
    private var aspect = 0.75f
    private var fed = 0
    private var empties = 0
    private var results = 0
    private var lastFeedNs = 0L
    private var avgMs = 0f

    /** Running average of the graph's own latency (feed to result),
     *  milliseconds; the caller paces by it. */
    val costMs: Float get() = avgMs

    /** Load the task ahead of the first frame, so a failure is logged
     *  at bind time rather than at the first hand. */
    fun warmUp(): Boolean = (landmarker ?: load()) != null

    /** Feed one analyzed frame, or the square of it centered at
     *  ([cropU], [cropV]) with side [cropSide] (fractions of the
     *  upright frame's width, height and height; 0 for the whole
     *  frame): a hand a few steps from a wide-angle camera is a dozen
     *  pixels to the palm detector's 192-pixel look at the whole frame,
     *  and two or three times that in a crop around where the picture
     *  changed. Returns false when the task is unavailable (logged once). */
    fun feed(
        image: ImageProxy,
        rotation: Int,
        nowNs: Long,
        cropU: Float = 0.5f,
        cropV: Float = 0.5f,
        cropSide: Float = 0f,
    ): Boolean {
        val task = landmarker ?: load() ?: return false
        return try {
            var bmp = image.toBitmap()
            // The bitmap is in sensor orientation; the crop is given in
            // upright terms, so map it back through the rotation.
            if (cropSide > 0f) {
                val turned = rotation == 90 || rotation == 270
                val rw = if (turned) bmp.height else bmp.width
                val rh = if (turned) bmp.width else bmp.height
                val side = (cropSide * rh).toInt().coerceIn(32, minOf(rw, rh))
                val ux = (cropU * rw - side / 2f).toInt().coerceIn(0, rw - side)
                val uy = (cropV * rh - side / 2f).toInt().coerceIn(0, rh - side)
                // Upright (ux, uy, side) -> sensor coordinates.
                val (sx, sy) = when (rotation) {
                    90 -> Pair(uy, rw - side - ux)
                    180 -> Pair(rw - side - ux, rh - side - uy)
                    270 -> Pair(rh - side - uy, ux)
                    else -> Pair(ux, uy)
                }
                bmp = Bitmap.createBitmap(bmp, sx, sy, side, side)
            }
            val turned = rotation == 90 || rotation == 270
            aspect = if (turned) bmp.width.toFloat() / bmp.height else bmp.height.toFloat() / bmp.width
            val options = ImageProcessingOptions.builder().setRotationDegrees(rotation).build()
            lastFeedNs = nowNs
            fed++
            task.detectAsync(BitmapImageBuilder(bmp).build(), options, SystemClock.uptimeMillis())
            true
        } catch (e: Exception) {
            Log.w(TAG, "feed failed: $e")
            false
        }
    }

    private fun onLandmarks(result: HandLandmarkerResult, atNs: Long) {
        results++
        val ms = (System.nanoTime() - atNs) / 1_000_000f
        avgMs += (ms - avgMs) / minOf(results, 20).toFloat()
        if (results == 1) Log.i(TAG, "first result ${"%.0f".format(ms)} ms after its frame")
        else if (results % TRACE_EVERY == 0) Log.d(TAG, "latency avg ${"%.0f".format(avgMs)} ms over $results results")
        val hands = result.landmarks()
        if (hands.isEmpty()) {
            empties++
            if (empties % 8 == 1) Log.d(TAG, "no hand in $empties looks")
            onResult(0, null, atNs)
            return
        }
        empties = 0
        // The largest hand: the widest wrist-to-middle-knuckle span.
        var best = 0
        var bestSpan = -1f
        for ((i, h) in hands.withIndex()) {
            val span = landmarkDist(h[WRIST].x(), h[WRIST].y(), h[MIDDLE_MCP].x(), h[MIDDLE_MCP].y())
            if (span > bestSpan) { bestSpan = span; best = i }
        }
        val h = hands[best]
        // Square units: y is a fraction of the height.
        onResult(hands.size, readHand({ i -> h[i].x() }, { i -> h[i].y() * aspect }), atNs)
    }

    private fun load(): HandLandmarker? {
        if (failed) return null
        return try {
            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(
                    BaseOptions.builder().setModelAssetPath(MODEL).setDelegate(Delegate.CPU).build())
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumHands(1)
                .setMinHandDetectionConfidence(0.3f)
                .setMinHandPresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setResultListener { result, _ -> onLandmarks(result, lastFeedNs) }
                .setErrorListener { e -> Log.w(TAG, "hand landmarker error: $e") }
                .build()
            HandLandmarker.createFromOptions(context, options).also {
                landmarker = it
                Log.i(TAG, "hand landmarker loaded")
            }
        } catch (e: Throwable) {
            failed = true
            Log.e(TAG, "hand landmarker unavailable: $e", e)
            null
        }
    }

    fun close() {
        try { landmarker?.close() } catch (_: Exception) {}
        landmarker = null
    }
}

/**
 * What one hand's landmarks show: the finger count, which digits are up
 * (thumb, index, middle, ring, pinky, the thumb only when it counts), the
 * tilt and the leads behind the count.
 */
class HandRead(val fingers: Int, val up: List<Boolean>, val tilt: Float, val detail: String)

private const val WRIST = 0
private const val THUMB_IP = 3
private const val THUMB_TIP = 4
private const val MIDDLE_MCP = 9
private const val PINKY_MCP = 17
private val FINGERS = arrayOf(
    intArrayOf(5, 6, 8), intArrayOf(9, 10, 12), intArrayOf(13, 14, 16), intArrayOf(17, 18, 20),
)

/**
 * Counts the fingers a hand shows from its 21 MediaPipe landmarks, given
 * in square units (the same scale on both axes). A finger is up when its
 * tip leads its middle knuckle away from the wrist. The thumb counts only
 * on a hand with all four fingers up, when its tip leads its joint away
 * from the pinky knuckle: an open hand reads five, four fingers with the
 * thumb tucked across the palm read four. Zero margins throughout. The
 * tilt is degrees off fingers-up, from the wrist-to-middle-knuckle line.
 */
fun readHand(px: (Int) -> Float, py: (Int) -> Float): HandRead {
    fun d(a: Int, b: Int) = landmarkDist(px(a), py(a), px(b), py(b))
    val palm = max(d(WRIST, MIDDLE_MCP), 1e-3f)
    val fingersUp = ArrayList<Boolean>(5)
    val detail = StringBuilder()
    for (f in FINGERS) {
        val lead = (d(WRIST, f[2]) - d(WRIST, f[1])) / palm
        fingersUp.add(lead > 0f)
        detail.append("%+.2f ".format(lead))
    }
    var n = fingersUp.count { it }
    val thumb = (d(THUMB_TIP, PINKY_MCP) - d(THUMB_IP, PINKY_MCP)) / palm
    val thumbCounts = n == 4 && thumb > 0f
    if (thumbCounts) n++
    detail.append("thumb %+.2f (%s)".format(thumb, if (thumbCounts) "counted" else "not counted"))
    val tilt = Math.toDegrees(
        atan2((px(MIDDLE_MCP) - px(WRIST)).toDouble(), -(py(MIDDLE_MCP) - py(WRIST)).toDouble())
    ).toFloat()
    return HandRead(n, listOf(thumbCounts) + fingersUp, tilt, detail.toString())
}

internal fun landmarkDist(x0: Float, y0: Float, x1: Float, y1: Float): Float {
    val dx = x1 - x0; val dy = y1 - y0
    return sqrt(dx * dx + dy * dy)
}
