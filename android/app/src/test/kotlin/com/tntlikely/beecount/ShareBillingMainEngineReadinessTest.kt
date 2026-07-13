package com.tntlikely.beecount

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ShareBillingMainEngineReadinessTest {
    @Test
    fun `attached engine is not dispatchable until Dart handler acknowledges readiness`() {
        val state = ShareBillingMainEngineState()

        assertFalse(state.isReady)
        state.markReady()
        assertFalse(state.isReady)
    }

    @Test
    fun `detaching clears a previously acknowledged readiness state`() {
        val state = ShareBillingMainEngineState()
        state.attach()
        state.markReady()
        assertTrue(state.isReady)

        state.detach()

        assertFalse(state.isReady)
    }
}
