package com.tntlikely.beecount

data class ShareBillingImageMetadata(
    val dateAddedSeconds: Long?,
    val dateTakenMillis: Long?,
    val exifTimeMillis: Long?
) {
    val screenshotTimeMillis: Long?
        get() = firstPositive(dateTakenMillis, exifTimeMillis, dateAddedSeconds?.times(1000L))

    val canResolveSourceApp: Boolean
        get() = screenshotTimeMillis != null

    fun toPayload(): Map<String, Any?> = mapOf(
        "dateAddedSeconds" to dateAddedSeconds,
        "dateTakenMillis" to dateTakenMillis,
        "exifTimeMillis" to exifTimeMillis,
        "screenshotTimeMillis" to screenshotTimeMillis
    )

    companion object {
        private fun firstPositive(vararg values: Long?): Long? {
            return values.firstOrNull { it != null && it > 0L }
        }
    }
}

data class ShareBillingPayload(
    val cacheImagePath: String,
    val originalUri: String,
    val mimeType: String?,
    val receivedAtMillis: Long,
    val metadata: ShareBillingImageMetadata,
    val sourceInfo: ScreenshotSourceInfo? = null,
    val c2FixtureId: String? = null
) {
    fun toServiceExtras(): Map<String, Any?> {
        val payload = mutableMapOf<String, Any?>(
            "path" to cacheImagePath,
            "cacheImagePath" to cacheImagePath,
            "originalUri" to originalUri,
            "mimeType" to mimeType,
            "receivedAtMillis" to receivedAtMillis
        )
        payload.putAll(metadata.toPayload())
        sourceInfo?.let { payload.putAll(it.toPayload()) }
        c2FixtureId?.let { payload["c2FixtureId"] = it }
        return payload
    }
}
