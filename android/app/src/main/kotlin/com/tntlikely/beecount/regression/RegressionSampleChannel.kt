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
            else -> result.notImplemented()
        }
    }

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
