package me.jxl.kiosk_satellite

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.os.Handler
import android.os.Looper
import android.util.Size
import android.view.WindowManager
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.Preview
import androidx.camera.core.UseCase
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry

/** Checks CameraX's actual size negotiation without starting another camera session. */
internal class CameraStreamCapabilities(
    private val context: Context,
    private val snapshot: (Size) -> ImageCapture,
) {
    private val main = Handler(Looper.getMainLooper())
    private val cache = mutableMapOf<List<Any>, Map<String, List<String>>>()
    private val pending = mutableMapOf<List<Any>, MutableList<(Map<String, List<String>>?, Exception?) -> Unit>>()

    @OptIn(ExperimentalCamera2Interop::class)
    fun read(facing: String, fps: Int, bitrate: Int, snapshotSize: Size,
             done: (Map<String, List<String>>?, Exception?) -> Unit) {
        @Suppress("DEPRECATION")
        val rotation = (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.rotation
        val key = listOf(facing, fps, bitrate, snapshotSize, rotation)
        cache[key]?.let { done(it, null); return }
        pending[key]?.let { it.add(done); return }
        pending[key] = mutableListOf(done)
        fun finish(value: Map<String, List<String>>?, error: Exception?) {
            val callbacks = pending.remove(key) ?: return
            if (value != null) {
                if (cache.size >= 8) cache.remove(cache.keys.first())
                cache[key] = value
            }
            callbacks.forEach { it(value, error) }
        }
        val timeout = Runnable { finish(null, IllegalStateException("Camera capabilities timed out")) }
        main.postDelayed(timeout, 15_000)
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            if (!pending.containsKey(key)) return@addListener
            try {
                val provider = future.get()
                val requested = if (facing == "back") CameraSelector.DEFAULT_BACK_CAMERA else CameraSelector.DEFAULT_FRONT_CAMERA
                val selector = resolveCameraSelector(provider, requested)
                    ?: throw IllegalStateException("No usable camera is available")
                val info = selector.filter(provider.availableCameraInfos).first()
                val camera2 = Camera2CameraInfo.from(info)
                val sizes = camera2.getCameraCharacteristic(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                    ?.getOutputSizes(android.graphics.SurfaceTexture::class.java).orEmpty()
                    .filter { it.width > 0 && it.height > 0 }.distinct()
                    .sortedWith(compareBy({ it.width.toLong() * it.height }, { it.width }, { it.height }))
                val rotate = info.getSensorRotationDegrees(rotation) % 180 != 0
                val rejected = mutableListOf<String>()
                val candidates = sizes.filter { size ->
                    val output = if (rotate) Size(size.height, size.width) else size
                    h264SurfaceEncoders(h264SurfaceFormat(output, fps, bitrate)).isNotEmpty().also {
                        if (!it) rejected.add(size.toString())
                    }
                }
                val withAnalysis = mutableListOf<String>()
                val withoutAnalysis = mutableListOf<String>()
                var index = 0
                fun step() {
                    if (!pending.containsKey(key)) return
                    try {
                        if (index == candidates.size) {
                            main.removeCallbacks(timeout)
                            finish(mapOf("withAnalysis" to withAnalysis, "withoutAnalysis" to withoutAnalysis,
                                "encoderRejected" to rejected,
                                "captureRejected" to candidates.map { it.toString() }.filter {
                                    it !in withAnalysis && it !in withoutAnalysis
                                }), null)
                            return
                        }
                        val size = candidates[index++]
                        for (analysis in listOf(true, false)) {
                            if (accepts(provider, selector, size, snapshotSize, rotation, analysis)) {
                                (if (analysis) withAnalysis else withoutAnalysis).add(size.toString())
                            }
                        }
                        // Yield between sizes so a live stream and the UI keep running.
                        main.post { step() }
                    } catch (e: Exception) {
                        main.removeCallbacks(timeout)
                        finish(null, e)
                    }
                }
                step()
            } catch (e: Exception) {
                main.removeCallbacks(timeout)
                finish(null, e)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun accepts(provider: ProcessCameraProvider, selector: CameraSelector, size: Size,
                        snapshotSize: Size, rotation: Int, analysis: Boolean): Boolean {
        val owner = object : LifecycleOwner {
            val registry = LifecycleRegistry(this).apply { currentState = Lifecycle.State.CREATED }
            override val lifecycle: Lifecycle get() = registry
        }
        val preview = Preview.Builder().setTargetRotation(rotation)
            .setResolutionSelector(videoResolutionSelector(size, exact = true)).build()
        val uses = mutableListOf<UseCase>(preview)
        if (analysis) {
            uses.add(snapshot(snapshotSize))
            uses.add(ImageAnalysis.Builder()
                .setResolutionSelector(streamAnalysisResolutionSelector(Size(640, 480)))
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build())
        }
        return try {
            // CREATED never opens the sensor or suspends the active streaming owner.
            provider.bindToLifecycle(owner, selector, *uses.toTypedArray())
            preview.resolutionInfo?.resolution == size
        } catch (_: IllegalArgumentException) {
            false
        } finally {
            provider.unbind(*uses.toTypedArray())
            owner.registry.currentState = Lifecycle.State.DESTROYED
        }
    }
}

internal fun streamAnalysisResolutionSelector(size: Size): ResolutionSelector =
    ResolutionSelector.Builder().setResolutionStrategy(ResolutionStrategy(
        size, ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER,
    )).build()
