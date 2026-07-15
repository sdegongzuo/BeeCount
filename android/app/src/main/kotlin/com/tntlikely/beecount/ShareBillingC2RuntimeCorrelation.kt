package com.tntlikely.beecount

object ShareBillingC2RuntimeCorrelation {
    private val validId = Regex("^[a-z0-9][a-z0-9-]{0,63}$")

    fun accept(isDebug: Boolean, runtimeId: String?): String? {
        if (!isDebug || runtimeId.isNullOrEmpty()) return null
        require(validId.matches(runtimeId)) { "Invalid share C2 fixture id" }
        return runtimeId
    }
}
