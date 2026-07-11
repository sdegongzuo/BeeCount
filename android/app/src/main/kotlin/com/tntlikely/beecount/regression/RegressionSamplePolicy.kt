package com.tntlikely.beecount.regression

import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.security.MessageDigest

object RegressionSampleFingerprint {
    fun exact(
        normalizedOcr: String,
        expectedFieldsJson: String,
        sensitiveEvidenceJson: String,
    ): String = sha256(
        listOf(
            normalizeOcr(normalizedOcr),
            canonicalJson(expectedFieldsJson),
            canonicalJson(sensitiveEvidenceJson),
        ).joinToString("\u001f"),
    )

    fun structure(descriptor: String): String = sha256(
        descriptor.trim().lowercase().replace(Regex("\\s+"), " "),
    )

    private fun normalizeOcr(value: String): String = value
        .replace("\r\n", "\n")
        .replace('\r', '\n')
        .lineSequence()
        .map { it.trim().replace(Regex("[ \\t]+"), " ") }
        .filter { it.isNotEmpty() }
        .joinToString("\n")

    private fun canonicalJson(value: String): String = canonicalize(JSONTokener(value).nextValue())

    private fun canonicalize(value: Any?): String = when (value) {
        null, JSONObject.NULL -> "null"
        is JSONObject -> value.keys().asSequence().toList().sorted()
            .joinToString(prefix = "{", postfix = "}") { key ->
                "${JSONObject.quote(key)}:${canonicalize(value.get(key))}"
            }
        is JSONArray -> (0 until value.length())
            .joinToString(prefix = "[", postfix = "]") { canonicalize(value.get(it)) }
        is String -> JSONObject.quote(value)
        is Number, is Boolean -> value.toString()
        else -> JSONObject.quote(value.toString())
    }

    private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) }
}

data class RetentionSample(
    val id: String,
    val structureFingerprint: String,
    val protected: Boolean,
    val createdAt: Long,
)

object RegressionSampleRetention {
    fun selectOrdinaryIdsToEvict(
        samples: List<RetentionSample>,
        ordinaryLimit: Int,
    ): List<String> {
        val ordinary = samples.filterNot { it.protected }
        val excess = (ordinary.size - ordinaryLimit).coerceAtLeast(0)
        if (excess == 0) return emptyList()

        val coverageCounts = samples.groupingBy { it.structureFingerprint }.eachCount().toMutableMap()
        val candidates = ordinary.sortedWith(
            compareByDescending<RetentionSample> { coverageCounts.getValue(it.structureFingerprint) > 1 }
                .thenBy { it.createdAt },
        )
        val selected = mutableListOf<String>()
        for (candidate in candidates) {
            if (selected.size == excess) break
            selected += candidate.id
            coverageCounts[candidate.structureFingerprint] =
                coverageCounts.getValue(candidate.structureFingerprint) - 1
        }
        return selected
    }
}
