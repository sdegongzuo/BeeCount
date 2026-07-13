package com.tntlikely.beecount

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ShareBillingPendingPayloadPolicyTest {
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
