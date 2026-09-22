package me.jxl.kiosk_satellite

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class CpuThermalZoneTest {
    /** The Fire HD 8 2018 (karnak) thermal directory of issue #654, with
     *  the CPU zone at the given raw value. mtkts_bts1 is an unwired board
     *  sensor that parks at 125000. */
    private fun karnak(cpu: Long?, bts1: Long = 125000) = listOf(
        ThermalZone("mtktscpu", cpu),
        ThermalZone("mtkts_bts0", 63000),
        ThermalZone("mtkts_bts1", bts1),
        ThermalZone("mtkts_bts2", 64000),
        ThermalZone("mtktsbattery", 30000),
    )

    @Test
    fun followsTheCpuZoneWhileItReads() {
        assertEquals(36.6, pickCpuTemp(karnak(36600)))
        assertEquals(56.1, pickCpuTemp(karnak(56100)))
    }

    @Test
    fun aCpuZoneReadingZeroYieldsNoValueInsteadOfABoardSensor() {
        // Before the fix this poll fell through to the MediaTek hints and
        // reported the parked 125 °C board sensor.
        assertNull(pickCpuTemp(karnak(0)))
        // The same read while bts1 happened to show a plausible number.
        assertNull(pickCpuTemp(karnak(0, bts1 = 87000)))
        // An unreadable temp file is the same gap.
        assertNull(pickCpuTemp(karnak(null)))
    }

    @Test
    fun socHintsOnlyApplyWhereNoCpuZoneExists() {
        val exynos = listOf(
            ThermalZone("big", 41000),
            ThermalZone("little", 38000),
            ThermalZone("gpu", 55000),
            ThermalZone("battery", 31000),
        )
        assertEquals(41.0, pickCpuTemp(exynos))
        // Every hinted zone parked or blank: still nothing, not the gpu.
        assertNull(pickCpuTemp(listOf(ThermalZone("big", 125000), ThermalZone("gpu", 55000))))
    }

    @Test
    fun acceptsPlainDegreesAndDropsThresholdsAndLookalikes() {
        assertEquals(47.0, pickCpuTemp(listOf(ThermalZone("cpu-0-0", 47))))
        val snapdragon = listOf(
            ThermalZone("cpuss-0", 52000),
            ThermalZone("cpuss-1", 49000),
            ThermalZone("cpu-limit", 105000),
            ThermalZone("skin-therm", 40000),
        )
        assertEquals(52.0, pickCpuTemp(snapdragon))
        assertNull(pickCpuTemp(emptyList()))
    }
}
