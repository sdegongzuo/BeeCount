package com.tntlikely.beecount

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ShareBillingRequestTrackerTest {
    @Test
    fun `finishing one concurrent request keeps service alive for the other`() {
        val tracker = ShareBillingRequestTracker()
        tracker.started("share-a")
        tracker.started("share-b")

        assertFalse(tracker.finished("share-a"))
        assertTrue(tracker.contains("share-b"))
    }

    @Test
    fun `service may stop only after the final request finishes`() {
        val tracker = ShareBillingRequestTracker()
        tracker.started("share-a")
        tracker.started("share-b")

        tracker.finished("share-a")

        assertTrue(tracker.finished("share-b"))
        assertTrue(tracker.isEmpty)
    }
}
