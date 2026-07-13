package com.tntlikely.beecount

object ShareBillingPendingPayloadPolicy {
    fun isRecoverable(
        jobId: Long?,
        dispatchLeaseUntil: Long?,
        now: Long
    ): Boolean {
        if (jobId != null && jobId > 0) return false
        return dispatchLeaseUntil == null || dispatchLeaseUntil <= now
    }
}
