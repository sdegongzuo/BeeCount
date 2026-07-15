package com.tntlikely.beecount

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ShareBillingC2ChannelRegistrationTest {
    @Test
    fun registersOnlyForDebuggableBuilds() {
        assertTrue(ShareBillingC2ChannelRegistration.shouldRegister(isDebug = true))
        assertFalse(ShareBillingC2ChannelRegistration.shouldRegister(isDebug = false))
    }
}
