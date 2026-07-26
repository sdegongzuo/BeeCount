package com.tntlikely.beecount

object ShareBillingBootstrapPolicy {
    fun shouldStartMainActivity(mainActivityRunning: Boolean): Boolean {
        return !mainActivityRunning
    }

    fun shouldMoveTaskToBack(
        backgroundBootstrapRequested: Boolean,
        userLaunchReceived: Boolean,
        processingComplete: Boolean
    ): Boolean {
        return backgroundBootstrapRequested && !userLaunchReceived && processingComplete
    }
}
