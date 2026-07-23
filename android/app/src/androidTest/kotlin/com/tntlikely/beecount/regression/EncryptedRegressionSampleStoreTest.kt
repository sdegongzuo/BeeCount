package com.tntlikely.beecount.regression

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
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
    fun expectedRevisionRoundTripsWithSameAesGcmStoreWithoutPlaintext() {
        val sampleId = store.save(
            sample("中国银行银联信用卡[2853]", "unionpay-card", SampleProtection.CORRECTION),
        ).sampleId!!

        val revision = store.prepareExpectedRevision(
            sampleId = sampleId,
            normalizationVersion = 2,
            expectedFieldsJson = """{"paymentMethod":"中国银行信用卡(2853)"}""",
            migrationDecisionId = "decision-v2",
            derivedFromRevisionId = null,
        )

        val payload = org.json.JSONObject(
            store.expectedRevisionPayloadForTesting(revision.revisionId),
        )
        assertEquals(
            """{"paymentMethod":"中国银行信用卡(2853)"}""",
            payload.getJSONObject("expectedFields").toString(),
        )
        assertEquals(revision.revisionId, payload.getString("revisionId"))
        assertEquals(sampleId, payload.getString("sampleId"))
        assertEquals(2, payload.getInt("normalizationVersion"))
        assertEquals("decision-v2", payload.getString("migrationDecisionId"))
        assertEquals("prepared", payload.getString("state"))
        val visibleStorage =
            store.visibleExpectedRevisionStorageForTesting(revision.revisionId)
        assertFalse(visibleStorage.contains("中国银行"))
        assertFalse(visibleStorage.contains("paymentMethod"))
        assertTrue(visibleStorage.contains("decision-v2"))
    }

    @Test
    fun activationIsAtomicWhenAnyReadableSampleLacksPreparedRevision() {
        val first = store.save(
            sample("first", "first", SampleProtection.CORRECTION),
        ).sampleId!!
        val second = store.save(
            sample("second", "second", SampleProtection.CORRECTION),
        ).sampleId!!
        val firstV1 = prepare(first, 1, "decision-v1")
        val secondV1 = prepare(second, 1, "decision-v1")
        store.activateExpectedRevisions(1, "decision-v1")
        val firstV2 = prepare(first, 2, "decision-v2")

        assertThrows(IllegalStateException::class.java) {
            store.activateExpectedRevisions(2, "decision-v2")
        }

        assertEquals(1 to null, store.normalizationVersionsForTesting())
        assertEquals(firstV1.revisionId, store.activeExpectedRevisionIdForTesting(first))
        assertEquals(secondV1.revisionId, store.activeExpectedRevisionIdForTesting(second))

        val secondV2 = prepare(second, 2, "decision-v2")
        val activated = store.activateExpectedRevisions(2, "decision-v2")
        assertEquals(2, activated.activeNormalizationVersion)
        assertEquals(1, activated.previousNormalizationVersion)
        assertEquals(2, activated.activatedRevisionCount)
        assertEquals(firstV2.revisionId, store.activeExpectedRevisionIdForTesting(first))
        assertEquals(secondV2.revisionId, store.activeExpectedRevisionIdForTesting(second))
    }

    @Test
    fun rollbackRestoresAllPreviousExpectedRevisionsAtomically() {
        val first = store.save(
            sample("rollback-first", "rollback-first", SampleProtection.CORRECTION),
        ).sampleId!!
        val second = store.save(
            sample("rollback-second", "rollback-second", SampleProtection.CORRECTION),
        ).sampleId!!
        val firstV1 = prepare(first, 1, "decision-v1")
        val secondV1 = prepare(second, 1, "decision-v1")
        store.activateExpectedRevisions(1, "decision-v1")
        val firstV2 = prepare(first, 2, "decision-v2")
        val secondV2 = prepare(second, 2, "decision-v2")
        store.activateExpectedRevisions(2, "decision-v2")

        val rolledBack = store.rollbackExpectedRevisions()

        assertEquals(1, rolledBack.activeNormalizationVersion)
        assertEquals(2, rolledBack.previousNormalizationVersion)
        assertEquals(2, rolledBack.activatedRevisionCount)
        assertEquals(1 to 2, store.normalizationVersionsForTesting())
        assertEquals(firstV1.revisionId, store.activeExpectedRevisionIdForTesting(first))
        assertEquals(secondV1.revisionId, store.activeExpectedRevisionIdForTesting(second))
        assertTrue(firstV2.revisionId != firstV1.revisionId)
        assertTrue(secondV2.revisionId != secondV1.revisionId)
    }

    @Test
    fun databaseVersionTwoMigratesExpectedRevisionSchemaWithoutDroppingSamples() {
        val databaseName = "regression-v2-migration-${System.nanoTime()}.db"
        LegacyVersionTwoStore(context, databaseName).use { legacy ->
            legacy.writableDatabase.execSQL(
                """INSERT INTO regression_samples(
                   id, exact_fingerprint, structure_fingerprint, protection,
                   nonce, ciphertext, key_version, unreadable, created_at, last_used_at
                   ) VALUES ('legacy', 'exact', 'structure', 'correction',
                     X'01', X'02', 1, 0, 1, 1)""".trimIndent(),
            )
        }

        EncryptedRegressionSampleStore(
            context,
            databaseName,
            "beecount-regression-test-${System.nanoTime()}",
        ).use { migrated ->
            assertEquals(1, migrated.countAll())
            assertTrue(migrated.hasExpectedRevisionSchemaForTesting())
            assertEquals(null to null, migrated.normalizationVersionsForTesting())
        }
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

    private fun prepare(
        sampleId: String,
        normalizationVersion: Int,
        decisionId: String,
    ) = store.prepareExpectedRevision(
        sampleId = sampleId,
        normalizationVersion = normalizationVersion,
        expectedFieldsJson = """{"paymentMethod":"card-$normalizationVersion"}""",
        migrationDecisionId = decisionId,
        derivedFromRevisionId = null,
    )

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

    private class LegacyVersionTwoStore(context: Context, databaseName: String) :
        SQLiteOpenHelper(context, databaseName, null, 2) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                """CREATE TABLE regression_samples (
                    id TEXT NOT NULL PRIMARY KEY,
                    exact_fingerprint TEXT NOT NULL UNIQUE,
                    structure_fingerprint TEXT NOT NULL,
                    protection TEXT NOT NULL,
                    nonce BLOB NOT NULL,
                    ciphertext BLOB NOT NULL,
                    key_version INTEGER NOT NULL,
                    unreadable INTEGER NOT NULL DEFAULT 0,
                    unreadable_reason TEXT,
                    created_at INTEGER NOT NULL,
                    last_used_at INTEGER NOT NULL
                )""".trimIndent(),
            )
            db.execSQL(
                """CREATE TABLE regression_sample_metadata (
                    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
                    content_generation INTEGER NOT NULL
                )""".trimIndent(),
            )
            db.execSQL(
                """INSERT INTO regression_sample_metadata(singleton, content_generation)
                   VALUES (1, 0)""".trimIndent(),
            )
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
    }
}
