package me.jxl.kiosk_satellite

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * The proximity sensor as a stream of near/far transitions, so the
 * screensaver can wake (or hold off) when something comes close to the
 * panel without running the camera.
 *
 * `support` says whether the device has one at all and what it is called:
 * the name matters more here than for any other sensor. Kiosk-class
 * tablets mostly have none, and modern phones tend to expose a virtual
 * "palm" proximity sensor that only reacts to a hand on the screen during
 * a call, which never notices someone walking up. Both settings surfaces
 * show the name next to the switch so a person can tell the two apart.
 *
 * Android reports proximity as a distance in cm, but nearly every sensor
 * is binary: 0 for near and a positive value for far. Some drivers report
 * 1 for far even though their advertised maximum range is larger. When
 * the resolution spans the whole range, treat the readings as flags.
 * Sensors with finer resolution keep their distance-based near test.
 * The first sample after registering is the resting state (flagged
 * `initial`), not an approach: something resting on the sensor must not
 * wake the screensaver every time it starts.
 *
 * TYPE_PROXIMITY needs no permission on any Android version.
 */
class ProximitySensor(context: Context, messenger: BinaryMessenger) {
    private val sensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    private val methods = MethodChannel(messenger, "kiosk_satellite/proximity_sensor")
    private val events = EventChannel(messenger, "kiosk_satellite/proximity_sensor_stream")

    private var listener: SensorEventListener? = null

    /** The default TYPE_PROXIMITY sensor, else the first dynamic one. */
    private fun findSensor(): Sensor? =
        sensorManager.getDefaultSensor(Sensor.TYPE_PROXIMITY)
            ?: sensorManager.getDynamicSensorList(Sensor.TYPE_PROXIMITY).firstOrNull()

    private fun support(): Map<String, Any?> {
        val s = findSensor()
            ?: return mapOf(
                "supported" to false,
                "hint" to "Not available on this device: it has no proximity sensor.",
            )
        return mapOf(
            "supported" to true,
            "name" to s.name,
            "vendor" to s.vendor,
            "maximumRange" to s.maximumRange,
            "resolution" to s.resolution,
        )
    }

    init {
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "support" -> result.success(support())
                else -> result.notImplemented()
            }
        }
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                val s = findSensor()
                if (s == null) {
                    sink.error("absent", "no proximity sensor", null)
                    return
                }
                detach()
                val nearBelow = proximityNearThreshold(s.maximumRange, s.resolution)
                var last: Boolean? = null
                val l = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        val distance = event.values.firstOrNull() ?: return
                        val near = distance < nearBelow
                        val initial = last == null
                        if (!initial && near == last) return
                        last = near
                        sink.success(mapOf("near" to near, "initial" to initial))
                    }

                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                }
                listener = l
                sensorManager.registerListener(l, s, SensorManager.SENSOR_DELAY_NORMAL)
            }

            override fun onCancel(args: Any?) = detach()
        })
    }

    private fun detach() {
        listener?.let { sensorManager.unregisterListener(it) }
        listener = null
    }

    fun dispose() {
        detach()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
}

internal fun proximityNearThreshold(maximumRange: Float, resolution: Float): Float = when {
    maximumRange <= 0f -> 0.5f
    // A binary driver's far flag need not match its advertised range (#579).
    resolution >= maximumRange -> minOf(maximumRange, 1f) / 2f
    else -> maximumRange
}
