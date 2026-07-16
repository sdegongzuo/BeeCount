package com.tntlikely.beecount.regression

import android.content.Context
import android.os.SystemClock
import android.util.Log
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.tntlikely.beecount.R
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class EncryptedRegressionSampleStoreTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val keyAlias = "beecount-regression-test-${System.nanoTime()}"
    private val store = EncryptedRegressionSampleStore(context, null, keyAlias)

    @After
    fun closeStore() {
        store.close()
        AndroidRegressionSampleCrypto.deleteTestKey(keyAlias)
    }

    @Test
    fun encryptedSampleRoundTripsWithoutPlaintextInDatabase() {
        val saved = store.save(
            RegressionSampleInput(
                normalizedOcr = "微信支付成功 金额 12.00",
                expectedFieldsJson = "{\"amount\":12}",
                sensitiveEvidenceJson = "{\"orderId\":\"SECRET-42\"}",
                structureDescriptor = "wechat|payment-success|amount-label",
                protection = SampleProtection.CORRECTION,
            ),
        )

        val batch = store.readDecryptableBatch()
        val visibleStorage = store.visibleStorageForTesting(saved.sampleId!!)

        assertTrue(saved.inserted)
        assertEquals("微信支付成功 金额 12.00", batch.samples.single().normalizedOcr)
        assertEquals(1, batch.keyUnwrapCount)
        assertFalse(visibleStorage.contains("SECRET-42"))
        assertFalse(visibleStorage.contains("微信支付成功"))
        assertFalse(visibleStorage.contains("amount"))
    }

    @Test
    fun exactDuplicateIsNotInsertedAndProtectedSampleSurvivesRetention() {
        val protected = sample("protected", "same", SampleProtection.NEGATIVE)
        assertTrue(store.save(protected).inserted)
        assertFalse(store.save(protected).inserted)

        repeat(501) { index ->
            store.save(sample("ordinary-$index", "structure-$index", SampleProtection.NONE))
        }

        val batch = store.readDecryptableBatch()
        assertEquals(501, batch.samples.size)
        assertTrue(batch.samples.any { it.protection == SampleProtection.NEGATIVE })
        assertEquals(500, batch.samples.count { it.protection == SampleProtection.NONE })
    }

    @Test
    fun equivalentOrdinaryStructureMergesCoverageButProtectedSamplesRemainIndependent() {
        assertTrue(store.save(sample("ordinary-old", "same-structure", SampleProtection.NONE)).inserted)
        assertFalse(store.save(sample("ordinary-new", "same-structure", SampleProtection.NONE)).inserted)
        assertTrue(store.save(sample("correction", "same-structure", SampleProtection.CORRECTION)).inserted)
        assertTrue(store.save(sample("negative", "same-structure", SampleProtection.NEGATIVE)).inserted)

        val batch = store.readDecryptableBatch()
        assertEquals(3, batch.samples.size)
        assertTrue(batch.samples.any { it.normalizedOcr == "ordinary-new" })
        assertFalse(batch.samples.any { it.normalizedOcr == "ordinary-old" })
    }

    @Test
    fun unreadableCiphertextIsMarkedAndNeverSilentlyRemoved() {
        val result = store.save(sample("will-corrupt", "corrupt", SampleProtection.NONE))
        store.corruptCiphertextForTesting(result.sampleId!!)

        val batch = store.readDecryptableBatch()

        assertTrue(batch.samples.isEmpty())
        assertEquals(1, batch.unreadableSampleIds.size)
        assertEquals(1, store.countAll())
    }

    @Test
    fun pagedSnapshotReadsEverySameMillisecondRowOnceAndReusesDataKey() {
        val ids = (0 until 120).map { index ->
            store.save(sample("paged-$index", "paged-$index", SampleProtection.CORRECTION)).sampleId!!
        }
        ids.forEach { store.setCreatedAtForTesting(it, 1_000L) }

        val samples = readAllPages(limit = 17)

        assertEquals(120, samples.size)
        assertEquals(120, samples.map { it.id }.toSet().size)
        assertEquals(1, store.readKeyUnwrapCountForTesting())
    }

    @Test
    fun insertOrEquivalentOverwriteDuringPagedSnapshotFailsClosed() {
        repeat(4) { index ->
            store.save(sample("base-$index", "base-$index", SampleProtection.CORRECTION))
        }
        val first = store.readDecryptablePage(2, null)
        store.save(sample("inserted", "inserted", SampleProtection.CORRECTION))
        assertThrows(RegressionSampleSnapshotChangedException::class.java) {
            store.readDecryptablePage(2, first.nextCursor)
        }

        val restart = store.readDecryptablePage(2, null)
        store.save(sample("replacement-old", "same-structure", SampleProtection.NONE))
        val replacementScan = store.readDecryptablePage(2, null)
        store.save(sample("replacement-new", "same-structure", SampleProtection.NONE))
        assertThrows(RegressionSampleSnapshotChangedException::class.java) {
            store.readDecryptablePage(2, replacementScan.nextCursor)
        }
        assertTrue(restart.samples.isNotEmpty())
    }

    @Test
    fun corruptionIsReportedAndMidScanCorruptionInvalidatesSnapshot() {
        val corrupt = store.save(sample("corrupt-first", "corrupt-first", SampleProtection.CORRECTION))
        store.corruptCiphertextForTesting(corrupt.sampleId!!)
        val unreadable = store.readDecryptablePage(10, null)
        assertEquals(listOf(corrupt.sampleId), unreadable.unreadableSampleIds)

        repeat(4) { index ->
            store.save(sample("later-$index", "later-$index", SampleProtection.CORRECTION))
        }
        val first = store.readDecryptablePage(2, null)
        val target = store.readDecryptableBatch().samples.last().id
        store.corruptCiphertextForTesting(target)
        assertThrows(RegressionSampleSnapshotChangedException::class.java) {
            store.readDecryptablePage(2, first.nextCursor)
        }
    }

    @Test
    fun regressionCiphertextAndWrappedKeyHaveExplicitBackupExclusions() {
        val legacy = readXml(R.xml.backup_rules)
        val modern = readXml(R.xml.data_extraction_rules)

        assertTrue(legacy.contains("regression_samples.db"))
        assertTrue(legacy.contains("regression_keys/"))
        assertTrue(modern.contains("regression_samples.db"))
        assertTrue(modern.contains("regression_keys/"))
    }

    @Test
    fun fiveHundredSampleReadAndDecryptP95StaysWithinBudget() {
        repeat(500) { index ->
            store.save(sample("performance-$index", "performance-$index", SampleProtection.NONE))
        }
        repeat(3) { store.readDecryptableBatch() }

        val measurements = List(20) { store.readDecryptableBatch() }
        val sortedTotals = measurements.map { it.timings.totalMs }.sorted()
        val p95 = sortedTotals[((sortedTotals.size * 0.95).toInt() - 1).coerceAtLeast(0)]
        val median = measurements[measurements.size / 2].timings
        Log.i(
            "RegressionSamplePerf",
            "count=500 p95TotalMs=$p95 keyUnwrapMs=${median.keyUnwrapMs} " +
                "sampleReadMs=${median.sampleReadMs} decryptMs=${median.decryptMs} " +
                "decodeMs=${median.decodeMs}",
        )

        assertEquals(500, measurements.first().samples.size)
        assertEquals(1, measurements.first().keyUnwrapCount)
        assertTrue("500-sample P95 was ${p95}ms", p95 <= 200.0)
    }

    @Test
    fun fiveHundredSamplePagedProductionScanMeetsBudget() {
        repeat(500) { index ->
            store.save(sample("paged-performance-$index", "paged-performance-$index", SampleProtection.NONE))
        }
        repeat(3) { readAllPages() }

        val totals = List(20) {
            val started = SystemClock.elapsedRealtimeNanos()
            assertEquals(500, readAllPages().size)
            (SystemClock.elapsedRealtimeNanos() - started) / 1_000_000.0
        }
        val sorted = totals.sorted()
        val p95 = sorted[((sorted.size * 0.95).toInt() - 1).coerceAtLeast(0)]
        val worst = sorted.last()
        Log.i(
            "RegressionSamplePerf",
            "pagedCount=500 p95TotalMs=$p95 worstTotalMs=$worst keyUnwrapCount=${store.readKeyUnwrapCountForTesting()}",
        )

        assertTrue("500-sample paged P95 was ${p95}ms", p95 <= 500.0)
        assertTrue("500-sample paged worst was ${worst}ms", worst <= 1_000.0)
        assertEquals(1, store.readKeyUnwrapCountForTesting())
    }

    private fun readAllPages(limit: Int = 50): List<DecryptedRegressionSample> {
        val samples = mutableListOf<DecryptedRegressionSample>()
        var cursor: String? = null
        do {
            val page = store.readDecryptablePage(limit, cursor)
            assertTrue(page.unreadableSampleIds.isEmpty())
            samples += page.samples
            cursor = page.nextCursor
        } while (cursor != null)
        return samples
    }

    private fun sample(text: String, structure: String, protection: SampleProtection) =
        RegressionSampleInput(text, "{\"amount\":1}", "{}", structure, protection)

    private fun readXml(resourceId: Int): String {
        val parser = context.resources.getXml(resourceId)
        return buildString {
            while (parser.eventType != org.xmlpull.v1.XmlPullParser.END_DOCUMENT) {
                if (parser.eventType == org.xmlpull.v1.XmlPullParser.START_TAG) {
                    append(parser.name)
                    repeat(parser.attributeCount) { index ->
                        append('|').append(parser.getAttributeValue(index))
                    }
                }
                parser.next()
            }
        }
    }
}
