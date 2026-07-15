package com.tntlikely.beecount

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ShareBillingC2ActionSendRequestTest {
    @Test
    fun acceptsAValidPngRequest() {
        val request = ShareBillingC2ActionSendRequest.parse(
            isDebug = true,
            fixtureId = "issue6-c2-20260716",
            caseId = "reliable-1",
            pngBytes = byteArrayOf(1, 2, 3)
        )

        assertEquals("issue6-c2-20260716", request.fixtureId)
        assertEquals("reliable-1.png", request.fileName)
        assertArrayEquals(byteArrayOf(1, 2, 3), request.pngBytes)
    }

    @Test
    fun rejectsRequestsOutsideDebugBuilds() {
        assertThrows(SecurityException::class.java) {
            ShareBillingC2ActionSendRequest.parse(
                isDebug = false,
                fixtureId = "issue6-c2-20260716",
                caseId = "reliable-1",
                pngBytes = byteArrayOf(1)
            )
        }
    }

    @Test
    fun rejectsUnsafeCaseIdsAndEmptyImages() {
        assertThrows(IllegalArgumentException::class.java) {
            ShareBillingC2ActionSendRequest.parse(
                isDebug = true,
                fixtureId = "issue6-c2-20260716",
                caseId = "../reliable",
                pngBytes = byteArrayOf()
            )
        }
    }
}
