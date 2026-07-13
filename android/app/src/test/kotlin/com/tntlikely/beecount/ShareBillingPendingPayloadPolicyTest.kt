package com.tntlikely.beecount

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.json.JSONObject
import org.junit.Test

class ShareBillingPendingPayloadPolicyTest {
    @Test
    fun `legacy payload gets a stable request id across repeated recovery`() {
        val json = "{\"cacheImagePath\":\"/cache/share/legacy.png\",\"screenshotTimeMillis\":42}"
        val first = ShareBillingPendingPayloadPolicy.stableLegacyRequestId(json)
        val second = ShareBillingPendingPayloadPolicy.stableLegacyRequestId(json)

        assertEquals(first, second)
        assertTrue(first.startsWith("legacy-"))
    }

    @Test
    fun `legacy single payload without request id is normalized and remains recoverable`() {
        val normalized = ShareBillingPendingPayloadPolicy.normalizeRoot(
            "{\"cacheImagePath\":\"/cache/share/legacy.png\",\"screenshotTimeMillis\":42}"
        )

        assertTrue(normalized.changed)
        assertEquals(1, normalized.root.length())
        val requestId = normalized.root.keys().next()
        assertTrue(requestId.startsWith("legacy-"))
        assertEquals(requestId, normalized.root.getJSONObject(requestId).getString("requestId"))

        val second = ShareBillingPendingPayloadPolicy.normalizeRoot(normalized.root.toString())
        assertFalse(second.changed)
        assertEquals(requestId, second.root.keys().next())
    }

    @Test
    fun `normalizing a multi request root restores request ids from durable keys`() {
        val normalized = ShareBillingPendingPayloadPolicy.normalizeRoot(
            "{\"request-a\":{\"cacheImagePath\":\"/a.png\"}," +
                "\"request-b\":{\"cacheImagePath\":\"/b.png\"}}"
        )

        assertEquals("request-a", normalized.root.getJSONObject("request-a").getString("requestId"))
        assertEquals("request-b", normalized.root.getJSONObject("request-b").getString("requestId"))
    }

    @Test
    fun `recoverable entries are drained in insertion order after leases expire`() {
        val root = JSONObject()
            .put("first", JSONObject().put("requestId", "first").put("dispatchLeaseUntil", 100))
            .put("active", JSONObject().put("requestId", "active").put("dispatchLeaseUntil", 500))
            .put("second", JSONObject().put("requestId", "second").put("dispatchLeaseUntil", 200))

        assertEquals(listOf("first", "second"), ShareBillingPendingPayloadPolicy.recoverableRequestIds(root, 300))
    }

    @Test
    fun `awaiting payload stays durable but is not reprocessed`() {
        assertFalse(
            ShareBillingPendingPayloadPolicy.isRecoverable(
                jobId = 42,
                dispatchLeaseUntil = 0,
                now = 1_000
            )
        )
    }

    @Test
    fun `active delivery lease prevents main and headless double ownership`() {
        assertFalse(
            ShareBillingPendingPayloadPolicy.isRecoverable(
                jobId = null,
                dispatchLeaseUntil = 2_000,
                now = 1_000
            )
        )
        assertTrue(
            ShareBillingPendingPayloadPolicy.isRecoverable(
                jobId = null,
                dispatchLeaseUntil = 2_000,
                now = 2_001
            )
        )
    }
}
