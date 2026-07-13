package com.tntlikely.beecount

import io.flutter.plugin.common.MethodChannel

object ShareBillingMainEngineBridge {
    private var channel: MethodChannel? = null
    private val state = ShareBillingMainEngineState()

    fun attach(channel: MethodChannel) {
        this.channel = channel
        state.attach()
    }

    fun markReady() {
        state.markReady()
    }

    fun detach() {
        channel = null
        state.detach()
    }

    fun dispatch(payload: Map<String, Any?>): Boolean {
        if (!state.isReady) return false
        val activeChannel = channel ?: return false
        return try {
            activeChannel.invokeMethod("onImageShared", payload)
            true
        } catch (e: Exception) {
            LoggerPlugin.warning(
                "ShareBillingMainBridge",
                "Dispatch share billing payload to main engine failed: ${e.message}"
            )
            false
        }
    }
}

class ShareBillingMainEngineState {
    private var attached = false
    private var ready = false

    val isReady: Boolean
        @Synchronized get() = attached && ready

    @Synchronized
    fun attach() {
        attached = true
        ready = false
    }

    @Synchronized
    fun markReady() {
        if (attached) ready = true
    }

    @Synchronized
    fun detach() {
        attached = false
        ready = false
    }
}
