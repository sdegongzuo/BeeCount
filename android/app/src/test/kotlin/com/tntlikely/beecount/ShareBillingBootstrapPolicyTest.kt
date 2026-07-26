package com.tntlikely.beecount

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ShareBillingBootstrapPolicyTest {
    @Test
    fun startsBackgroundBootstrapWhenMainActivityIsNotRunning() {
        assertTrue(ShareBillingBootstrapPolicy.shouldStartMainActivity(false))
    }

    @Test
    fun doesNotBootstrapWhenMainActivityAlreadyExists() {
        assertFalse(ShareBillingBootstrapPolicy.shouldStartMainActivity(true))
    }

    @Test
    fun userLaunchCancelsPendingBackgroundMove() {
        assertFalse(
            ShareBillingBootstrapPolicy.shouldMoveTaskToBack(
                backgroundBootstrapRequested = true,
                userLaunchReceived = true,
                processingComplete = true
            )
        )
    }

    @Test
    fun bootstrapStaysResumedWhileProcessing() {
        assertFalse(
            ShareBillingBootstrapPolicy.shouldMoveTaskToBack(
                backgroundBootstrapRequested = true,
                userLaunchReceived = false,
                processingComplete = false
            )
        )
    }

    @Test
    fun completedBackgroundBootstrapMovesTaskOutOfForeground() {
        assertTrue(
            ShareBillingBootstrapPolicy.shouldMoveTaskToBack(
                backgroundBootstrapRequested = true,
                userLaunchReceived = false,
                processingComplete = true
            )
        )
    }
}
