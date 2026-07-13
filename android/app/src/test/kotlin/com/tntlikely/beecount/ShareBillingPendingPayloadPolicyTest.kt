package com.tntlikely.beecount

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.json.JSONObject
import org.junit.Test

class ShareBillingPendingPayloadPolicyTest {
    @Test
    fun `delivery lease exceeds job deadline plus heartbeat and safety margin`() {
        val billingJobDeadlineMs = 90_000L
        val heartbeatIntervalMs = 30_000L
        val safetyMarginMs = 15_000L

        assertTrue(
            ShareBillingPendingPayloadPolicy.DELIVERY_LEASE_MS >
                billingJobDeadlineMs + heartbeatIntervalMs + safetyMarginMs
        )
    }

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
    fun `nearest active lease expiry is exposed for recovery scheduling`() {
        val root = JSONObject()
            .put("later", JSONObject().put("requestId", "later").put("dispatchLeaseUntil", 900))
            .put("awaiting", JSONObject().put("requestId", "awaiting").put("jobId", 42).put("dispatchLeaseUntil", 600))
            .put("nearer", JSONObject().put("requestId", "nearer").put("dispatchLeaseUntil", 700))

        assertEquals(700L, ShareBillingPendingPayloadPolicy.nearestRetryAt(root, 500))
    }

    @Test
    fun `owner token fences renewal and terminal removal`() {
        val root = JSONObject().put(
            "request-1",
            JSONObject().put("requestId", "request-1")
        )
        val claimed = ShareBillingPendingPayloadPolicy.claim(
            root = root,
            requestId = "request-1",
            ownerToken = "owner-a",
            now = 1_000
        )
        assertEquals("owner-a", claimed?.getString("deliveryOwnerToken"))
        assertTrue(ShareBillingPendingPayloadPolicy.renew(root, "request-1", "owner-a", 2_000))
        assertFalse(ShareBillingPendingPayloadPolicy.renew(root, "request-1", "owner-b", 3_000))
        assertFalse(ShareBillingPendingPayloadPolicy.removeIfOwner(root, "request-1", "owner-b"))
        assertTrue(root.has("request-1"))
        assertTrue(ShareBillingPendingPayloadPolicy.removeIfOwner(root, "request-1", "owner-a"))
        assertFalse(root.has("request-1"))
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
