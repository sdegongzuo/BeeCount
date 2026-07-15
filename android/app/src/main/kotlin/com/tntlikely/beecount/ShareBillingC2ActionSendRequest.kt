package com.tntlikely.beecount

data class ShareBillingC2ActionSendRequest(
    val fixtureId: String,
    val caseId: String,
    val pngBytes: ByteArray
) {
    val fileName: String get() = "$caseId.png"

    companion object {
        private val validCaseId = Regex("^[a-z0-9][a-z0-9-]{0,63}$")

        fun parse(
            isDebug: Boolean,
            fixtureId: String?,
            caseId: String?,
            pngBytes: ByteArray?
        ): ShareBillingC2ActionSendRequest {
            if (!isDebug) throw SecurityException("Share C2 tracer is debug-only")
            val acceptedFixture = ShareBillingC2RuntimeCorrelation.accept(true, fixtureId)
                ?: throw IllegalArgumentException("Missing share C2 fixture id")
            require(caseId != null && validCaseId.matches(caseId)) {
                "Invalid share C2 case id"
            }
            require(pngBytes != null && pngBytes.isNotEmpty()) {
                "Share C2 image is empty"
            }
            return ShareBillingC2ActionSendRequest(acceptedFixture, caseId, pngBytes)
        }
    }
}
