package com.tntlikely.beecount

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class ShareBillingC2TraceRegistryTest {
    @Test
    fun exposesOnlyAnExactValidatedDebugTrace() {
        val key = ShareBillingC2TraceKey.parse(
            isDebug = true,
            fixtureId = "issue7-c2-20260717",
            caseId = "unknown-first"
        )

        ShareBillingC2TraceRegistry.recordAccepted(
            key,
            cacheImagePath = "/isolated/cache/share-first.png"
        )

        assertEquals(
            "/isolated/cache/share-first.png",
            ShareBillingC2TraceRegistry.locate(key)
        )
        assertNull(
            ShareBillingC2TraceRegistry.locate(
                ShareBillingC2TraceKey.parse(
                    isDebug = true,
                    fixtureId = "issue7-c2-20260717",
                    caseId = "unknown-second"
                )
            )
        )
    }

    @Test
    fun rejectsReleaseAndUnsafeLookupKeys() {
        assertThrows(SecurityException::class.java) {
            ShareBillingC2TraceKey.parse(
                isDebug = false,
                fixtureId = "issue7-c2-20260717",
                caseId = "unknown-first"
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            ShareBillingC2TraceKey.parse(
                isDebug = true,
                fixtureId = "issue7-c2-20260717",
                caseId = "../production-db"
            )
        }
    }
}
