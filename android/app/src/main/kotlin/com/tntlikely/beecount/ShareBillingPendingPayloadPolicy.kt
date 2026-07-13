package com.tntlikely.beecount

import org.json.JSONObject
import java.nio.charset.StandardCharsets
import java.security.MessageDigest

object ShareBillingPendingPayloadPolicy {
    const val DELIVERY_LEASE_MS = 150_000L

    data class NormalizedRoot(val root: JSONObject, val changed: Boolean)

    fun isRecoverable(
        jobId: Long?,
        dispatchLeaseUntil: Long?,
        now: Long
    ): Boolean {
        if (jobId != null && jobId > 0) return false
        return dispatchLeaseUntil == null || dispatchLeaseUntil <= now
    }

    /**
     * Migrates both historical single-payload shapes and current keyed roots.
     * The generated legacy id is content-derived so a crash before persistence
     * cannot turn one share into multiple requests.
     */
    fun normalizeRoot(raw: String): NormalizedRoot {
        val parsed = JSONObject(raw)
        if (looksLikeSinglePayload(parsed)) {
            val payload = JSONObject(parsed.toString())
            val requestId = payload.optString(ShareBillingForegroundService.EXTRA_REQUEST_ID)
                .takeIf(String::isNotBlank)
                ?: stableLegacyRequestId(parsed.toString())
            val changed = !payload.has(ShareBillingForegroundService.EXTRA_REQUEST_ID) ||
                parsed.length() != 1 || !parsed.has(requestId)
            payload.put(ShareBillingForegroundService.EXTRA_REQUEST_ID, requestId)
            return NormalizedRoot(JSONObject().put(requestId, payload), changed = changed)
        }

        var changed = false
        val normalized = JSONObject()
        parsed.keys().forEach { key ->
            val payload = parsed.optJSONObject(key) ?: return@forEach
            val copy = JSONObject(payload.toString())
            if (copy.optString(ShareBillingForegroundService.EXTRA_REQUEST_ID).isBlank()) {
                copy.put(ShareBillingForegroundService.EXTRA_REQUEST_ID, key)
                changed = true
            }
            normalized.put(key, copy)
        }
        if (normalized.length() != parsed.length()) changed = true
        return NormalizedRoot(normalized, changed)
    }

    fun stableLegacyRequestId(payloadJson: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(payloadJson.toByteArray(StandardCharsets.UTF_8))
        return "legacy-" + digest.take(16).joinToString("") { "%02x".format(it) }
    }

    fun recoverableRequestIds(root: JSONObject, now: Long): List<String> {
        val ids = mutableListOf<String>()
        root.keys().forEach { key ->
            val payload = root.optJSONObject(key) ?: return@forEach
            val jobId = payload.optLong(ShareBillingForegroundService.EXTRA_JOB_ID, -1L)
                .takeIf { it > 0L }
            val leaseUntil = payload.optLong(
                ShareBillingForegroundService.EXTRA_DISPATCH_LEASE_UNTIL,
                0L
            ).takeIf { it > 0L }
            if (isRecoverable(jobId, leaseUntil, now)) ids += key
        }
        return ids
    }

    fun nearestRetryAt(root: JSONObject, now: Long): Long? {
        var nearest: Long? = null
        root.keys().forEach { key ->
            val payload = root.optJSONObject(key) ?: return@forEach
            val jobId = payload.optLong(ShareBillingForegroundService.EXTRA_JOB_ID, -1L)
            if (jobId > 0L) return@forEach
            val leaseUntil = payload.optLong(
                ShareBillingForegroundService.EXTRA_DISPATCH_LEASE_UNTIL,
                0L
            )
            if (leaseUntil > now && (nearest == null || leaseUntil < nearest!!)) {
                nearest = leaseUntil
            }
        }
        return nearest
    }

    fun claim(
        root: JSONObject,
        requestId: String,
        ownerToken: String,
        now: Long
    ): JSONObject? {
        val payload = root.optJSONObject(requestId) ?: return null
        val jobId = payload.optLong(ShareBillingForegroundService.EXTRA_JOB_ID, -1L)
            .takeIf { it > 0L }
        val leaseUntil = payload.optLong(
            ShareBillingForegroundService.EXTRA_DISPATCH_LEASE_UNTIL,
            0L
        ).takeIf { it > 0L }
        if (!isRecoverable(jobId, leaseUntil, now)) return null
        payload.put(ShareBillingForegroundService.EXTRA_DELIVERY_OWNER_TOKEN, ownerToken)
        payload.put(
            ShareBillingForegroundService.EXTRA_DISPATCH_LEASE_UNTIL,
            now + DELIVERY_LEASE_MS
        )
        return payload
    }

    fun renew(
        root: JSONObject,
        requestId: String,
        ownerToken: String,
        now: Long
    ): Boolean {
        val payload = root.optJSONObject(requestId) ?: return false
        if (payload.optString(ShareBillingForegroundService.EXTRA_DELIVERY_OWNER_TOKEN) != ownerToken) {
            return false
        }
        payload.put(
            ShareBillingForegroundService.EXTRA_DISPATCH_LEASE_UNTIL,
            now + DELIVERY_LEASE_MS
        )
        return true
    }

    fun isCurrentOwner(root: JSONObject, requestId: String, ownerToken: String): Boolean =
        root.optJSONObject(requestId)
            ?.optString(ShareBillingForegroundService.EXTRA_DELIVERY_OWNER_TOKEN) == ownerToken

    fun removeIfOwner(root: JSONObject, requestId: String, ownerToken: String): Boolean {
        if (!isCurrentOwner(root, requestId, ownerToken)) return false
        root.remove(requestId)
        return true
    }

    private fun looksLikeSinglePayload(value: JSONObject): Boolean =
        value.has(ShareBillingForegroundService.EXTRA_REQUEST_ID) ||
            value.has(ShareBillingForegroundService.EXTRA_CACHE_IMAGE_PATH) ||
            value.has("path")
}
