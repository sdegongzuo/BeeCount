package com.tntlikely.beecount.regression

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.os.SystemClock
import org.json.JSONObject
import java.util.UUID

enum class SampleProtection(val storageValue: String) {
    NONE("none"), CORRECTION("correction"), NEGATIVE("negative");

    companion object {
        fun fromStorage(value: String) = entries.first { it.storageValue == value }
    }
}

data class RegressionSampleInput(
    val normalizedOcr: String,
    val expectedFieldsJson: String,
    val sensitiveEvidenceJson: String,
    val structureDescriptor: String,
    val protection: SampleProtection = SampleProtection.NONE,
)

data class DecryptedRegressionSample(
    val id: String,
    val normalizedOcr: String,
    val expectedFieldsJson: String,
    val sensitiveEvidenceJson: String,
    val exactFingerprint: String,
    val structureFingerprint: String,
    val protection: SampleProtection,
    val keyVersion: Int,
)

data class SaveSampleResult(
    val inserted: Boolean,
    val sampleId: String?,
    val exactFingerprint: String,
    val structureFingerprint: String,
)

data class RegressionBatchTimings(
    val keyUnwrapMs: Double,
    val sampleReadMs: Double,
    val decryptMs: Double,
    val decodeMs: Double,
    val totalMs: Double,
)

data class RegressionSampleBatch(
    val samples: List<DecryptedRegressionSample>,
    val unreadableSampleIds: List<String>,
    val keyUnwrapCount: Int,
    val timings: RegressionBatchTimings,
)

data class RegressionSamplePage(
    val samples: List<DecryptedRegressionSample>,
    val unreadableSampleIds: List<String>,
    val nextCursor: String?,
)

data class ExpectedRevisionResult(
    val revisionId: String,
    val sampleId: String,
    val normalizationVersion: Int,
    val migrationDecisionId: String,
    val derivedFromRevisionId: String?,
    val state: String,
)

data class ExpectedActivationResult(
    val activeNormalizationVersion: Int,
    val previousNormalizationVersion: Int?,
    val activatedRevisionCount: Int,
)

class RegressionSampleSnapshotChangedException : IllegalStateException(
    "Regression sample content changed during paged scan",
)

class EncryptedRegressionSampleStore(
    context: Context,
    databaseName: String? = DATABASE_NAME,
    keyAlias: String = AndroidRegressionSampleCrypto.DEFAULT_KEY_ALIAS,
    private val ordinaryLimit: Int = DEFAULT_ORDINARY_LIMIT,
) : SQLiteOpenHelper(context, databaseName, null, DATABASE_VERSION), AutoCloseable {
    private val crypto = AndroidRegressionSampleCrypto(context, keyAlias)
    private var saveDataKey: UnwrappedDataKey? = null
    private var readDataKey: UnwrappedDataKey? = null
    private var readKeyUnwrapCount = 0

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
        db.execSQL("CREATE INDEX regression_samples_structure ON regression_samples(structure_fingerprint)")
        createMetadataSchema(db)
        createExpectedRevisionSchema(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) createMetadataSchema(db)
        if (oldVersion < 3) createExpectedRevisionSchema(db)
    }

    fun prepareExpectedRevision(
        sampleId: String,
        normalizationVersion: Int,
        expectedFieldsJson: String,
        migrationDecisionId: String,
        derivedFromRevisionId: String?,
    ): ExpectedRevisionResult {
        require(normalizationVersion >= 0)
        check(readableDatabase.rawQuery(
            "SELECT 1 FROM regression_samples WHERE id = ?",
            arrayOf(sampleId),
        ).use { it.moveToFirst() }) { "Unknown regression sample" }
        val revisionId = UUID.randomUUID().toString()
        val createdAt = System.currentTimeMillis()
        val dataKey = saveDataKey ?: crypto.loadDataKey().also { saveDataKey = it }
        val encrypted = crypto.encrypt(
            dataKey.key,
            JSONObject()
                .put("revisionId", revisionId)
                .put("sampleId", sampleId)
                .put("normalizationVersion", normalizationVersion)
                .put("expectedFields", JSONObject(expectedFieldsJson))
                .put("derivedFromRevisionId", derivedFromRevisionId)
                .put("migrationDecisionId", migrationDecisionId)
                .put("state", "prepared")
                .put("createdAt", createdAt)
                .toString().toByteArray(Charsets.UTF_8),
        )
        writableDatabase.insertOrThrow(
            "regression_expected_revisions",
            null,
            ContentValues().apply {
                put("revision_id", revisionId)
                put("sample_id", sampleId)
                put("normalization_version", normalizationVersion)
                put("nonce", encrypted.nonce)
                put("ciphertext", encrypted.ciphertext)
                put("key_version", dataKey.version)
                put("derived_from_revision_id", derivedFromRevisionId)
                put("migration_decision_id", migrationDecisionId)
                put("state", "prepared")
                put("created_at", createdAt)
            },
        )
        return ExpectedRevisionResult(
            revisionId, sampleId, normalizationVersion, migrationDecisionId,
            derivedFromRevisionId, "prepared",
        )
    }

    fun activateExpectedRevisions(
        normalizationVersion: Int,
        migrationDecisionId: String,
    ): ExpectedActivationResult {
        val db = writableDatabase
        var activated = 0
        var previous: Int? = null
        db.transaction {
            previous = rawQuery(
                "SELECT active_version FROM regression_normalization_state WHERE singleton = 1",
                emptyArray(),
            ).use { cursor ->
                cursor.moveToFirst()
                if (cursor.isNull(0)) null else cursor.getInt(0)
            }
            val relevantSamples = rawQuery(
                "SELECT id FROM regression_samples WHERE unreadable = 0",
                emptyArray(),
            ).use { cursor -> buildList { while (cursor.moveToNext()) add(cursor.getString(0)) } }
            for (sampleId in relevantSamples) {
                val revisionId = rawQuery(
                    """SELECT revision_id FROM regression_expected_revisions
                       WHERE sample_id = ? AND normalization_version = ?
                         AND migration_decision_id = ? AND state = 'prepared'
                       ORDER BY created_at DESC LIMIT 1""".trimIndent(),
                    arrayOf(sampleId, normalizationVersion.toString(), migrationDecisionId),
                ).use { cursor ->
                    check(cursor.moveToFirst()) { "Missing prepared expected revision for $sampleId" }
                    cursor.getString(0)
                }
                val oldActive = rawQuery(
                    "SELECT active_revision_id FROM regression_expected_state WHERE sample_id = ?",
                    arrayOf(sampleId),
                ).use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
                execSQL(
                    """INSERT OR REPLACE INTO regression_expected_state(
                       sample_id, active_revision_id, previous_revision_id
                       ) VALUES (?, ?, ?)""".trimIndent(),
                    arrayOf(sampleId, revisionId, oldActive),
                )
                execSQL(
                    "UPDATE regression_expected_revisions SET state = 'active' WHERE revision_id = ?",
                    arrayOf(revisionId),
                )
                activated++
            }
            execSQL(
                """UPDATE regression_normalization_state
                   SET previous_version = active_version, active_version = ?,
                       migration_decision_id = ?, updated_at = ?
                   WHERE singleton = 1""".trimIndent(),
                arrayOf(normalizationVersion, migrationDecisionId, System.currentTimeMillis()),
            )
        }
        return ExpectedActivationResult(normalizationVersion, previous, activated)
    }

    fun rollbackExpectedRevisions(): ExpectedActivationResult {
        val db = writableDatabase
        var active = 0
        var previous: Int? = null
        var count = 0
        db.transaction {
            val versions = rawQuery(
                "SELECT active_version, previous_version FROM regression_normalization_state WHERE singleton = 1",
                emptyArray(),
            ).use { cursor ->
                check(cursor.moveToFirst() && !cursor.isNull(1)) { "No normalization rollback available" }
                cursor.getInt(0) to cursor.getInt(1)
            }
            active = versions.second
            previous = versions.first
            val states = rawQuery(
                "SELECT sample_id, active_revision_id, previous_revision_id FROM regression_expected_state",
                emptyArray(),
            ).use { cursor ->
                buildList {
                    while (cursor.moveToNext()) {
                        add(Triple(cursor.getString(0), cursor.getString(1), cursor.getString(2)))
                    }
                }
            }
            for ((sampleId, currentId, previousId) in states) {
                check(previousId != null) { "Sample $sampleId has no rollback revision" }
                execSQL(
                    "UPDATE regression_expected_state SET active_revision_id = ?, previous_revision_id = ? WHERE sample_id = ?",
                    arrayOf(previousId, currentId, sampleId),
                )
                count++
            }
            execSQL(
                "UPDATE regression_normalization_state SET active_version = ?, previous_version = ?, updated_at = ? WHERE singleton = 1",
                arrayOf(active, previous, System.currentTimeMillis()),
            )
        }
        return ExpectedActivationResult(active, previous, count)
    }

    fun save(input: RegressionSampleInput): SaveSampleResult {
        val exact = RegressionSampleFingerprint.exact(
            input.normalizedOcr,
            input.expectedFieldsJson,
            input.sensitiveEvidenceJson,
        )
        val structure = RegressionSampleFingerprint.structure(input.structureDescriptor)
        val existingId = readableDatabase.rawQuery(
            "SELECT id FROM regression_samples WHERE exact_fingerprint = ?",
            arrayOf(exact),
        ).use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
        if (existingId != null) {
            readableDatabase.execSQL(
                "UPDATE regression_samples SET last_used_at = ? WHERE id = ?",
                arrayOf<Any>(System.currentTimeMillis(), existingId),
            )
            return SaveSampleResult(false, existingId, exact, structure)
        }

        val dataKey = saveDataKey ?: crypto.loadDataKey().also { saveDataKey = it }
        val payload = JSONObject()
            .put("normalizedOcr", input.normalizedOcr)
            .put("expectedFields", JSONObject(input.expectedFieldsJson))
            .put("sensitiveEvidence", JSONObject(input.sensitiveEvidenceJson))
            .toString()
            .toByteArray(Charsets.UTF_8)
        val encrypted = crypto.encrypt(dataKey.key, payload)
        val equivalentStructureId = if (input.protection == SampleProtection.NONE) {
            readableDatabase.rawQuery(
                "SELECT id FROM regression_samples WHERE structure_fingerprint = ? AND protection = ? LIMIT 1",
                arrayOf(structure, SampleProtection.NONE.storageValue),
            ).use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
        } else {
            null
        }
        val id = equivalentStructureId ?: UUID.randomUUID().toString()
        val now = System.currentTimeMillis()
        writableDatabase.transaction {
            val values = ContentValues().apply {
                put("exact_fingerprint", exact)
                put("structure_fingerprint", structure)
                put("protection", input.protection.storageValue)
                put("nonce", encrypted.nonce)
                put("ciphertext", encrypted.ciphertext)
                put("key_version", dataKey.version)
                put("unreadable", 0)
                putNull("unreadable_reason")
                put("last_used_at", now)
            }
            if (equivalentStructureId == null) {
                values.put("id", id)
                values.put("created_at", now)
                insertOrThrow("regression_samples", null, values)
            } else {
                update("regression_samples", values, "id = ?", arrayOf(id))
            }
            enforceOrdinaryLimit(this)
            incrementContentGeneration(this)
        }
        return SaveSampleResult(equivalentStructureId == null, id, exact, structure)
    }

    fun readDecryptableBatch(): RegressionSampleBatch {
        val totalStart = SystemClock.elapsedRealtimeNanos()
        val unwrapStart = SystemClock.elapsedRealtimeNanos()
        val dataKey = try {
            crypto.loadDataKey()
        } catch (error: Exception) {
            return markAllUnreadableAfterKeyFailure(totalStart, unwrapStart, error)
        }
        val unwrapEnd = SystemClock.elapsedRealtimeNanos()

        val readStart = unwrapEnd
        val rows = readableDatabase.rawQuery(
            """SELECT id, exact_fingerprint, structure_fingerprint, protection,
                      nonce, ciphertext, key_version
               FROM regression_samples ORDER BY created_at""".trimIndent(),
            emptyArray(),
        ).use { cursor ->
            buildList {
                while (cursor.moveToNext()) {
                    add(
                        StoredRow(
                            cursor.getString(0), cursor.getString(1), cursor.getString(2),
                            SampleProtection.fromStorage(cursor.getString(3)),
                            cursor.getBlob(4), cursor.getBlob(5), cursor.getInt(6),
                        ),
                    )
                }
            }
        }
        val readEnd = SystemClock.elapsedRealtimeNanos()
        var decryptNanos = 0L
        var decodeNanos = 0L
        val unreadable = mutableListOf<String>()
        val samples = rows.mapNotNull { row ->
            try {
                check(row.keyVersion == dataKey.version) { "Unsupported key version" }
                val decryptStart = SystemClock.elapsedRealtimeNanos()
                val plaintext = crypto.decrypt(dataKey.key, row.nonce, row.ciphertext)
                val decryptEnd = SystemClock.elapsedRealtimeNanos()
                decryptNanos += decryptEnd - decryptStart
                val json = JSONObject(plaintext.toString(Charsets.UTF_8))
                val sample = DecryptedRegressionSample(
                    row.id,
                    json.getString("normalizedOcr"),
                    json.getJSONObject("expectedFields").toString(),
                    json.getJSONObject("sensitiveEvidence").toString(),
                    row.exactFingerprint,
                    row.structureFingerprint,
                    row.protection,
                    row.keyVersion,
                )
                decodeNanos += SystemClock.elapsedRealtimeNanos() - decryptEnd
                sample
            } catch (error: Exception) {
                unreadable += row.id
                writableDatabase.execSQL(
                    "UPDATE regression_samples SET unreadable = 1, unreadable_reason = ? WHERE id = ?",
                    arrayOf(error.javaClass.simpleName, row.id),
                )
                null
            }
        }
        val totalEnd = SystemClock.elapsedRealtimeNanos()
        return RegressionSampleBatch(
            samples,
            unreadable,
            keyUnwrapCount = 1,
            timings = RegressionBatchTimings(
                nanosToMs(unwrapEnd - unwrapStart),
                nanosToMs(readEnd - readStart),
                nanosToMs(decryptNanos),
                nanosToMs(decodeNanos),
                nanosToMs(totalEnd - totalStart),
            ),
        )
    }

    fun readDecryptablePage(limit: Int, cursor: String?): RegressionSamplePage {
        require(limit in 1..100) { "Page limit must be between 1 and 100" }
        val db = readableDatabase
        val parsedCursor = cursor?.let(::parseCursor)
        val generation = currentContentGeneration(db)
        if (parsedCursor != null && parsedCursor.generation != generation) {
            throw RegressionSampleSnapshotChangedException()
        }
        val upperBound = parsedCursor?.upperBound ?: newestPosition(db)
            ?: return RegressionSamplePage(emptyList(), emptyList(), null)
        val lastPosition = parsedCursor?.lastPosition
        val selection = if (lastPosition == null) {
            "WHERE (created_at < ? OR (created_at = ? AND id <= ?))"
        } else {
            """WHERE (created_at > ? OR (created_at = ? AND id > ?))
               AND (created_at < ? OR (created_at = ? AND id <= ?))""".trimIndent()
        }
        val args = if (lastPosition == null) {
            arrayOf(
                upperBound.createdAt.toString(), upperBound.createdAt.toString(), upperBound.id,
            )
        } else {
            arrayOf(
                lastPosition.createdAt.toString(), lastPosition.createdAt.toString(), lastPosition.id,
                upperBound.createdAt.toString(), upperBound.createdAt.toString(), upperBound.id,
            )
        }
        val rows = db.rawQuery(
            """SELECT id, exact_fingerprint, structure_fingerprint, protection,
                      nonce, ciphertext, key_version, created_at
               FROM regression_samples $selection
               ORDER BY created_at, id LIMIT ${limit + 1}""".trimIndent(),
            args,
        ).use { query ->
            buildList {
                while (query.moveToNext()) {
                    add(
                        StoredRow(
                            query.getString(0), query.getString(1), query.getString(2),
                            SampleProtection.fromStorage(query.getString(3)),
                            query.getBlob(4), query.getBlob(5), query.getInt(6), query.getLong(7),
                        ),
                    )
                }
            }
        }
        val pageRows = rows.take(limit)
        if (pageRows.isEmpty()) return RegressionSamplePage(emptyList(), emptyList(), null)
        val dataKey = try {
            readDataKey ?: crypto.loadDataKey().also {
                readDataKey = it
                readKeyUnwrapCount++
            }
        } catch (error: Exception) {
            pageRows.forEach { markUnreadable(it.id, error) }
            return RegressionSamplePage(
                emptyList(), pageRows.map { it.id },
                if (rows.size > limit) cursorFor(
                    generation, upperBound, positionOf(pageRows.last()),
                ) else null,
            )
        }
        val unreadable = mutableListOf<String>()
        val samples = pageRows.mapNotNull { row ->
            try {
                check(row.keyVersion == dataKey.version) { "Unsupported key version" }
                val plaintext = crypto.decrypt(dataKey.key, row.nonce, row.ciphertext)
                val json = JSONObject(plaintext.toString(Charsets.UTF_8))
                DecryptedRegressionSample(
                    row.id,
                    json.getString("normalizedOcr"),
                    json.getJSONObject("expectedFields").toString(),
                    json.getJSONObject("sensitiveEvidence").toString(),
                    row.exactFingerprint,
                    row.structureFingerprint,
                    row.protection,
                    row.keyVersion,
                )
            } catch (error: Exception) {
                unreadable += row.id
                markUnreadable(row.id, error)
                null
            }
        }
        if (currentContentGeneration(db) != generation) {
            throw RegressionSampleSnapshotChangedException()
        }
        return RegressionSamplePage(
            samples,
            unreadable,
            if (rows.size > limit) cursorFor(
                generation, upperBound, positionOf(pageRows.last()),
            ) else null,
        )
    }

    fun countAll(): Int = readableDatabase.rawQuery(
        "SELECT COUNT(*) FROM regression_samples",
        emptyArray(),
    ).use { cursor -> cursor.moveToFirst(); cursor.getInt(0) }

    fun visibleStorageForTesting(id: String): String = readableDatabase.rawQuery(
        """SELECT exact_fingerprint, structure_fingerprint, protection, nonce,
                  ciphertext, key_version, unreadable, unreadable_reason
           FROM regression_samples WHERE id = ?""".trimIndent(),
        arrayOf(id),
    ).use { cursor ->
        check(cursor.moveToFirst())
        buildString {
            for (index in 0 until cursor.columnCount) {
                when (cursor.getType(index)) {
                    android.database.Cursor.FIELD_TYPE_BLOB ->
                        append(cursor.getBlob(index).toString(Charsets.ISO_8859_1))
                    android.database.Cursor.FIELD_TYPE_NULL -> Unit
                    else -> append(cursor.getString(index))
                }
                append('|')
            }
        }
    }

    fun visibleExpectedRevisionStorageForTesting(revisionId: String): String =
        readableDatabase.rawQuery(
            """SELECT normalization_version, nonce, ciphertext, key_version,
                      derived_from_revision_id, migration_decision_id, state
               FROM regression_expected_revisions WHERE revision_id = ?""".trimIndent(),
            arrayOf(revisionId),
        ).use { cursor ->
            check(cursor.moveToFirst())
            buildString {
                for (index in 0 until cursor.columnCount) {
                    when (cursor.getType(index)) {
                        android.database.Cursor.FIELD_TYPE_BLOB ->
                            append(cursor.getBlob(index).toString(Charsets.ISO_8859_1))
                        android.database.Cursor.FIELD_TYPE_NULL -> Unit
                        else -> append(cursor.getString(index))
                    }
                    append('|')
                }
            }
        }

    fun expectedRevisionPayloadForTesting(revisionId: String): String {
        val row = readableDatabase.rawQuery(
            """SELECT nonce, ciphertext, key_version
               FROM regression_expected_revisions WHERE revision_id = ?""".trimIndent(),
            arrayOf(revisionId),
        ).use { cursor ->
            check(cursor.moveToFirst())
            Triple(cursor.getBlob(0), cursor.getBlob(1), cursor.getInt(2))
        }
        val dataKey = crypto.loadDataKey()
        check(row.third == dataKey.version) { "Unsupported key version" }
        return crypto.decrypt(
            dataKey.key,
            row.first,
            row.second,
        ).toString(Charsets.UTF_8)
    }

    fun activeExpectedRevisionIdForTesting(sampleId: String): String? =
        readableDatabase.rawQuery(
            "SELECT active_revision_id FROM regression_expected_state WHERE sample_id = ?",
            arrayOf(sampleId),
        ).use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }

    fun normalizationVersionsForTesting(): Pair<Int?, Int?> =
        readableDatabase.rawQuery(
            """SELECT active_version, previous_version
               FROM regression_normalization_state WHERE singleton = 1""".trimIndent(),
            emptyArray(),
        ).use { cursor ->
            check(cursor.moveToFirst())
            (if (cursor.isNull(0)) null else cursor.getInt(0)) to
                (if (cursor.isNull(1)) null else cursor.getInt(1))
        }

    fun hasExpectedRevisionSchemaForTesting(): Boolean =
        readableDatabase.rawQuery(
            """SELECT COUNT(*) FROM sqlite_master
               WHERE type = 'table' AND name IN (
                 'regression_expected_revisions',
                 'regression_expected_state',
                 'regression_expected_audits',
                 'regression_normalization_state'
               )""".trimIndent(),
            emptyArray(),
        ).use { cursor -> cursor.moveToFirst(); cursor.getInt(0) == 4 }

    fun corruptCiphertextForTesting(id: String) {
        writableDatabase.transaction {
            execSQL(
                "UPDATE regression_samples SET ciphertext = ? WHERE id = ?",
                arrayOf(byteArrayOf(1, 2, 3), id),
            )
            incrementContentGeneration(this)
        }
    }

    fun setCreatedAtForTesting(id: String, createdAt: Long) {
        writableDatabase.execSQL(
            "UPDATE regression_samples SET created_at = ? WHERE id = ?",
            arrayOf<Any>(createdAt, id),
        )
    }

    fun readKeyUnwrapCountForTesting(): Int = readKeyUnwrapCount

    private fun markAllUnreadableAfterKeyFailure(
        totalStart: Long,
        unwrapStart: Long,
        error: Exception,
    ): RegressionSampleBatch {
        val markedAt = SystemClock.elapsedRealtimeNanos()
        val ids = readableDatabase.rawQuery(
            "SELECT id FROM regression_samples",
            emptyArray(),
        ).use { cursor -> buildList { while (cursor.moveToNext()) add(cursor.getString(0)) } }
        writableDatabase.execSQL(
            "UPDATE regression_samples SET unreadable = 1, unreadable_reason = ?",
            arrayOf(error.javaClass.simpleName),
        )
        val finishedAt = SystemClock.elapsedRealtimeNanos()
        return RegressionSampleBatch(
            samples = emptyList(),
            unreadableSampleIds = ids,
            keyUnwrapCount = 1,
            timings = RegressionBatchTimings(
                keyUnwrapMs = nanosToMs(markedAt - unwrapStart),
                sampleReadMs = nanosToMs(finishedAt - markedAt),
                decryptMs = 0.0,
                decodeMs = 0.0,
                totalMs = nanosToMs(finishedAt - totalStart),
            ),
        )
    }

    private fun enforceOrdinaryLimit(db: SQLiteDatabase) {
        val ordinaryCount = db.rawQuery(
            "SELECT COUNT(*) FROM regression_samples WHERE protection = ?",
            arrayOf(SampleProtection.NONE.storageValue),
        ).use { cursor -> cursor.moveToFirst(); cursor.getInt(0) }
        if (ordinaryCount <= ordinaryLimit) return

        val samples = db.rawQuery(
            "SELECT id, structure_fingerprint, protection, created_at FROM regression_samples",
            emptyArray(),
        ).use { cursor ->
            buildList {
                while (cursor.moveToNext()) {
                    add(
                        RetentionSample(
                            cursor.getString(0), cursor.getString(1),
                            cursor.getString(2) != SampleProtection.NONE.storageValue,
                            cursor.getLong(3),
                        ),
                    )
                }
            }
        }
        RegressionSampleRetention.selectOrdinaryIdsToEvict(samples, ordinaryLimit).forEach { id ->
            db.delete("regression_samples", "id = ?", arrayOf(id))
        }
    }

    private data class StoredRow(
        val id: String,
        val exactFingerprint: String,
        val structureFingerprint: String,
        val protection: SampleProtection,
        val nonce: ByteArray,
        val ciphertext: ByteArray,
        val keyVersion: Int,
        val createdAt: Long = 0,
    )

    private data class RowPosition(val createdAt: Long, val id: String)

    private data class PageCursor(
        val generation: Long,
        val upperBound: RowPosition,
        val lastPosition: RowPosition,
    )

    private fun markUnreadable(id: String, error: Exception) {
        writableDatabase.execSQL(
            "UPDATE regression_samples SET unreadable = 1, unreadable_reason = ? WHERE id = ?",
            arrayOf(error.javaClass.simpleName, id),
        )
    }

    private fun positionOf(row: StoredRow) = RowPosition(row.createdAt, row.id)

    private fun cursorFor(
        generation: Long,
        upperBound: RowPosition,
        lastPosition: RowPosition,
    ) = listOf(
        generation,
        upperBound.createdAt,
        upperBound.id,
        lastPosition.createdAt,
        lastPosition.id,
    ).joinToString("|")

    private fun parseCursor(cursor: String): PageCursor {
        val parts = cursor.split('|')
        require(parts.size == 5 && parts[2].isNotEmpty() && parts[4].isNotEmpty()) {
            "Invalid page cursor"
        }
        return PageCursor(
            generation = parts[0].toLong(),
            upperBound = RowPosition(parts[1].toLong(), parts[2]),
            lastPosition = RowPosition(parts[3].toLong(), parts[4]),
        )
    }

    private fun newestPosition(db: SQLiteDatabase): RowPosition? = db.rawQuery(
        "SELECT created_at, id FROM regression_samples ORDER BY created_at DESC, id DESC LIMIT 1",
        emptyArray(),
    ).use { cursor ->
        if (cursor.moveToFirst()) RowPosition(cursor.getLong(0), cursor.getString(1)) else null
    }

    private fun currentContentGeneration(db: SQLiteDatabase): Long {
        createMetadataSchema(db)
        return db.rawQuery(
            "SELECT content_generation FROM regression_sample_metadata WHERE singleton = 1",
            emptyArray(),
        ).use { cursor -> cursor.moveToFirst(); cursor.getLong(0) }
    }

    private fun incrementContentGeneration(db: SQLiteDatabase) {
        createMetadataSchema(db)
        db.execSQL(
            "UPDATE regression_sample_metadata SET content_generation = content_generation + 1 WHERE singleton = 1",
        )
    }

    private fun createMetadataSchema(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS regression_sample_metadata (
                singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
                content_generation INTEGER NOT NULL
            )""".trimIndent(),
        )
        db.execSQL(
            "INSERT OR IGNORE INTO regression_sample_metadata(singleton, content_generation) VALUES (1, 0)",
        )
    }

    private fun createExpectedRevisionSchema(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS regression_expected_revisions (
                revision_id TEXT PRIMARY KEY,
                sample_id TEXT NOT NULL,
                normalization_version INTEGER NOT NULL,
                nonce BLOB NOT NULL,
                ciphertext BLOB NOT NULL,
                key_version INTEGER NOT NULL,
                derived_from_revision_id TEXT,
                migration_decision_id TEXT NOT NULL,
                state TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                FOREIGN KEY(sample_id) REFERENCES regression_samples(id)
            )""".trimIndent(),
        )
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS regression_expected_state (
                sample_id TEXT PRIMARY KEY,
                active_revision_id TEXT NOT NULL,
                previous_revision_id TEXT
            )""".trimIndent(),
        )
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS regression_expected_audits (
                revision_id TEXT PRIMARY KEY,
                sample_id TEXT NOT NULL,
                normalization_version INTEGER NOT NULL,
                encrypted_digest BLOB NOT NULL,
                decision TEXT NOT NULL,
                result TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )""".trimIndent(),
        )
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS regression_normalization_state (
                singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
                active_version INTEGER,
                previous_version INTEGER,
                migration_decision_id TEXT,
                updated_at INTEGER NOT NULL
            )""".trimIndent(),
        )
        db.execSQL(
            """INSERT OR IGNORE INTO regression_normalization_state(
               singleton, active_version, previous_version, updated_at
               ) VALUES (1, NULL, NULL, 0)""".trimIndent(),
        )
    }

    private inline fun <T> SQLiteDatabase.transaction(block: SQLiteDatabase.() -> T): T {
        beginTransaction()
        return try {
            block().also { setTransactionSuccessful() }
        } finally {
            endTransaction()
        }
    }

    companion object {
        const val DATABASE_NAME = "regression_samples.db"
        const val DEFAULT_ORDINARY_LIMIT = 500
        private const val DATABASE_VERSION = 3
        private fun nanosToMs(nanos: Long) = nanos / 1_000_000.0
    }
}
