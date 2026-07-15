package com.tntlikely.beecount

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class ShareBillingC2RuntimeCorrelationTest {
    @Test
    fun releaseBuildIgnoresRuntimeFixtureExtra() {
        assertNull(
            ShareBillingC2RuntimeCorrelation.accept(
                isDebug = false,
                runtimeId = "issue6-c2-20260716"
            )
        )
    }

    @Test
    fun debugBuildCarriesValidRuntimeFixtureForDartCorrelation() {
        assertEquals(
            "issue6-c2-20260716",
            ShareBillingC2RuntimeCorrelation.accept(
                isDebug = true,
                runtimeId = "issue6-c2-20260716"
            )
        )
    }

    @Test
    fun debugBuildRejectsUnsafeRuntimeFixtureBeforePayloadCreation() {
        assertThrows(IllegalArgumentException::class.java) {
            ShareBillingC2RuntimeCorrelation.accept(
                isDebug = true,
                runtimeId = "../beecount"
            )
        }
    }
}
