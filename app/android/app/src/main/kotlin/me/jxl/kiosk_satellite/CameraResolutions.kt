package me.jxl.kiosk_satellite

import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.util.Size
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import kotlin.math.abs

/** Read the same first matching facing used by the app's camera selector. */
internal fun cameraStreamResolutions(context: Context, facing: String): List<String> {
    val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    val cameras = manager.cameraIdList.mapNotNull { id ->
        try {
            manager.getCameraCharacteristics(id).takeIf {
                it.get(CameraCharacteristics.LENS_FACING) in listOf(
                    CameraCharacteristics.LENS_FACING_FRONT,
                    CameraCharacteristics.LENS_FACING_BACK,
                    CameraCharacteristics.LENS_FACING_EXTERNAL,
                )
            }
        } catch (_: Exception) { null }
    }
    val lens = if (facing == "back") CameraCharacteristics.LENS_FACING_BACK
        else CameraCharacteristics.LENS_FACING_FRONT
    val camera = cameras.firstOrNull { it.get(CameraCharacteristics.LENS_FACING) == lens }
        ?: cameras.firstOrNull() ?: return emptyList()
    return camera.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        ?.getOutputSizes(SurfaceTexture::class.java).orEmpty()
        .filter { it.width > 0 && it.height > 0 }
        .distinct()
        .sortedWith(compareBy<Size>({ it.width.toLong() * it.height }, { it.width }, { it.height }))
        .map { "${it.width}x${it.height}" }
}

/** An exact size outranks CameraX's default aspect ratio preference. */
internal fun orderedVideoSizes(
    sizes: List<Pair<Int, Int>>,
    target: Pair<Int, Int>,
): List<Pair<Int, Int>> {
    val area = target.first.toLong() * target.second
    return sizes.sortedWith(compareBy(
        { if (it == target) 0 else 1 },
        { abs(it.first.toLong() * it.second - area) },
        { it.first.toLong() * it.second },
        { it.first },
        { it.second },
    ))
}

internal fun videoResolutionSelector(target: Size, exact: Boolean = false): ResolutionSelector =
    ResolutionSelector.Builder()
        .setResolutionStrategy(ResolutionStrategy(
            target, if (exact) ResolutionStrategy.FALLBACK_RULE_NONE
                else ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER,
        ))
        .setResolutionFilter { sizes, _ ->
            if (exact) sizes.filter { it == target }
            else orderedVideoSizes(sizes.map { it.width to it.height }, target.width to target.height)
                .map { (width, height) -> Size(width, height) }
        }
        .build()
