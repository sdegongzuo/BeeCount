package com.tntlikely.beecount.regression

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors

class RegressionSampleChannel(
    context: Context,
    messenger: BinaryMessenger,
) : AutoCloseable {
    private val store = EncryptedRegressionSampleStore(context.applicationContext)
    private val executor = Executors.newSingleThreadExecutor()
    private val channel = MethodChannel(messenger, CHANNEL_NAME).apply {
        setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "save" -> executor.execute {
                respond(result) { save(call) }
            }
            "readBatch" -> executor.execute {
                respond(result) { readBatch() }
            }
            "readPage" -> executor.execute {
                respond(result) { readPage(call) }
            }
            "prepareExpectedRevision" -> executor.execute {
                respond(result) { prepareExpectedRevision(call) }
            }
            "activateExpectedRevisions" -> executor.execute {
                respond(result) { activateExpectedRevisions(call) }
            }
            "rollbackExpectedRevisions" -> executor.execute {
                respond(result) { activationToMap(store.rollbackExpectedRevisions()) }
            }
            else -> result.notImplemented()
        }
    }

    private fun prepareExpectedRevision(call: MethodCall): Map<String, Any?> {
        val arguments = requireNotNull(call.arguments as? Map<*, *>)
        val revision = store.prepareExpectedRevision(
            sampleId = arguments.requiredString("sampleId"),
            normalizationVersion = requireNotNull(arguments["normalizationVersion"] as? Int),
            expectedFieldsJson = JSONObject(arguments.requiredMap("expectedFields")).toString(),
            migrationDecisionId = arguments.requiredString("migrationDecisionId"),
            derivedFromRevisionId = arguments["derivedFromRevisionId"] as? String,
        )
        return mapOf(
            "revisionId" to revision.revisionId,
            "sampleId" to revision.sampleId,
            "normalizationVersion" to revision.normalizationVersion,
            "migrationDecisionId" to revision.migrationDecisionId,
            "derivedFromRevisionId" to revision.derivedFromRevisionId,
            "state" to revision.state,
        )
    }

    private fun activateExpectedRevisions(call: MethodCall): Map<String, Any?> {
        val arguments = requireNotNull(call.arguments as? Map<*, *>)
        return activationToMap(
            store.activateExpectedRevisions(
                normalizationVersion =
                    requireNotNull(arguments["normalizationVersion"] as? Int),
                migrationDecisionId = arguments.requiredString("migrationDecisionId"),
            ),
        )
    }

    private fun activationToMap(value: ExpectedActivationResult) = mapOf(
        "activeNormalizationVersion" to value.activeNormalizationVersion,
        "previousNormalizationVersion" to value.previousNormalizationVersion,
        "activatedRevisionCount" to value.activatedRevisionCount,
    )

    private fun save(call: MethodCall): Map<String, Any?> {
        val arguments = requireNotNull(call.arguments as? Map<*, *>)
        val saved = store.save(
            RegressionSampleInput(
                normalizedOcr = arguments.requiredString("normalizedOcr"),
                expectedFieldsJson = JSONObject(arguments.requiredMap("expectedFields")).toString(),
                sensitiveEvidenceJson = JSONObject(arguments.requiredMap("sensitiveEvidence")).toString(),
                structureDescriptor = arguments.requiredString("structureDescriptor"),
                protection = SampleProtection.fromStorage(arguments.requiredString("protection")),
            ),
        )
        return mapOf(
            "inserted" to saved.inserted,
            "sampleId" to saved.sampleId,
            "exactFingerprint" to saved.exactFingerprint,
            "structureFingerprint" to saved.structureFingerprint,
        )
    }

    private fun readBatch(): Map<String, Any> {
        val batch = store.readDecryptableBatch()
        return mapOf(
            "samples" to batch.samples.map { sample ->
                mapOf(
                    "id" to sample.id,
                    "normalizedOcr" to sample.normalizedOcr,
                    "expectedFields" to RegressionSampleChannelJson.toChannelValue(
                        JSONObject(sample.expectedFieldsJson),
                    ),
                    "sensitiveEvidence" to RegressionSampleChannelJson.toChannelValue(
                        JSONObject(sample.sensitiveEvidenceJson),
                    ),
                    "exactFingerprint" to sample.exactFingerprint,
                    "structureFingerprint" to sample.structureFingerprint,
                    "protection" to sample.protection.storageValue,
                    "keyVersion" to sample.keyVersion,
                )
            },
            "unreadableSampleIds" to batch.unreadableSampleIds,
            "keyUnwrapCount" to batch.keyUnwrapCount,
            "timings" to mapOf(
                "keyUnwrapMs" to batch.timings.keyUnwrapMs,
                "sampleReadMs" to batch.timings.sampleReadMs,
                "decryptMs" to batch.timings.decryptMs,
                "decodeMs" to batch.timings.decodeMs,
                "totalMs" to batch.timings.totalMs,
            ),
        )
    }

    private fun readPage(call: MethodCall): Map<String, Any?> {
        val arguments = requireNotNull(call.arguments as? Map<*, *>)
        val limit = requireNotNull(arguments["limit"] as? Int)
        val page = store.readDecryptablePage(limit, arguments["cursor"] as? String)
        return mapOf(
            "samples" to page.samples.map(::sampleToChannelValue),
            "unreadableSampleIds" to page.unreadableSampleIds,
            "nextCursor" to page.nextCursor,
        )
    }

    private fun sampleToChannelValue(sample: DecryptedRegressionSample) = mapOf(
        "id" to sample.id,
        "normalizedOcr" to sample.normalizedOcr,
        "expectedFields" to RegressionSampleChannelJson.toChannelValue(
            JSONObject(sample.expectedFieldsJson),
        ),
        "sensitiveEvidence" to RegressionSampleChannelJson.toChannelValue(
            JSONObject(sample.sensitiveEvidenceJson),
        ),
        "exactFingerprint" to sample.exactFingerprint,
        "structureFingerprint" to sample.structureFingerprint,
        "protection" to sample.protection.storageValue,
        "keyVersion" to sample.keyVersion,
    )

    private fun respond(result: MethodChannel.Result, block: () -> Any) {
        try {
            result.success(block())
        } catch (error: Exception) {
            result.error("regression_sample_store_failed", error.javaClass.simpleName, null)
        }
    }

    override fun close() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
        store.close()
    }

    private fun Map<*, *>.requiredString(key: String): String =
        requireNotNull(this[key] as? String) { "Missing $key" }

    private fun Map<*, *>.requiredMap(key: String): Map<*, *> =
        requireNotNull(this[key] as? Map<*, *>) { "Missing $key" }

    companion object {
        const val CHANNEL_NAME = "com.tntlikely.beecount/regression_samples"
    }
}

internal object RegressionSampleChannelJson {
    fun toChannelValue(value: Any?): Any? = when (value) {
        is JSONObject -> value.keys().asSequence().associateWith { key ->
            toChannelValue(value.get(key))
        }
        is org.json.JSONArray -> (0 until value.length()).map { index ->
            toChannelValue(value.get(index))
        }
        JSONObject.NULL -> null
        else -> value
    }
}
