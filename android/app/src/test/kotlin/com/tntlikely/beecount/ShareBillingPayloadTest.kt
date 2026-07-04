package com.tntlikely.beecount

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ShareBillingPayloadTest {
    @Test
    fun prefersDateTakenMillisForScreenshotTime() {
        val metadata = ShareBillingImageMetadata(
            dateAddedSeconds = 100L,
            dateTakenMillis = 200_000L,
            exifTimeMillis = 150_000L
        )

        assertEquals(200_000L, metadata.screenshotTimeMillis)
        assertTrue(metadata.canResolveSourceApp)
    }

    @Test
    fun fallsBackToExifBeforeDateAdded() {
        val metadata = ShareBillingImageMetadata(
            dateAddedSeconds = 100L,
            dateTakenMillis = null,
            exifTimeMillis = 150_000L
        )

        assertEquals(150_000L, metadata.screenshotTimeMillis)
        assertTrue(metadata.canResolveSourceApp)
    }

    @Test
    fun doesNotResolveSourceAppWithoutOriginalImageTime() {
        val metadata = ShareBillingImageMetadata(
            dateAddedSeconds = null,
            dateTakenMillis = null,
            exifTimeMillis = null
        )

        assertEquals(null, metadata.screenshotTimeMillis)
        assertFalse(metadata.canResolveSourceApp)
    }

    @Test
    fun serviceExtrasUseOriginalImageTimeNotShareOrCacheTime() {
        val metadata = ShareBillingImageMetadata(
            dateAddedSeconds = 100L,
            dateTakenMillis = null,
            exifTimeMillis = 150_000L
        )
        val payload = ShareBillingPayload(
            cacheImagePath = "/cache/share_billing/shared_1.jpg",
            originalUri = "content://media/external/images/media/42",
            mimeType = "image/jpeg",
            receivedAtMillis = 999_000L,
            metadata = metadata
        )

        val extras = payload.toServiceExtras()

        assertEquals("/cache/share_billing/shared_1.jpg", extras["cacheImagePath"])
        assertEquals("content://media/external/images/media/42", extras["originalUri"])
        assertEquals("image/jpeg", extras["mimeType"])
        assertEquals(999_000L, extras["receivedAtMillis"])
        assertEquals(100L, extras["dateAddedSeconds"])
        assertEquals(150_000L, extras["exifTimeMillis"])
        assertEquals(150_000L, extras["screenshotTimeMillis"])
        assertFalse(extras.containsKey("cacheFileTimeMillis"))
    }
}
