package com.tntlikely.beecount

import android.content.Context
import android.os.Bundle
import org.json.JSONObject

data class ShareBillingDeliveryClaim(
    val payload: Map<String, Any?>? = null,
    val retryAtMillis: Long? = null
)

/** Shared, process-local atomic boundary for Activity/Service delivery state. */
class ShareBillingPendingPayloadStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun saveAndClaim(extras: Bundle, ownerToken: String, now: Long): Bundle = synchronized(lock) {
        val requestId = requireNotNull(extras.getString(ShareBillingForegroundService.EXTRA_REQUEST_ID))
        val root = readRootLocked()
        val payload = JSONObject()
        extras.keySet().forEach { key ->
            @Suppress("DEPRECATION")
            payload.put(key, extras.get(key))
        }
        root.put(requestId, payload)
        val claimed = requireNotNull(
            ShareBillingPendingPayloadPolicy.claim(root, requestId, ownerToken, now)
        )
        writeRootLocked(root)
        Bundle(extras).apply {
            putString(ShareBillingForegroundService.EXTRA_DELIVERY_OWNER_TOKEN, ownerToken)
            putLong(
                ShareBillingForegroundService.EXTRA_DISPATCH_LEASE_UNTIL,
                claimed.getLong(ShareBillingForegroundService.EXTRA_DISPATCH_LEASE_UNTIL)
            )
        }
    }

    fun claimNext(ownerToken: String, now: Long): ShareBillingDeliveryClaim = synchronized(lock) {
        val root = readRootLocked()
        val requestId = ShareBillingPendingPayloadPolicy.recoverableRequestIds(root, now).firstOrNull()
        if (requestId != null) {
            val payload = ShareBillingPendingPayloadPolicy.claim(root, requestId, ownerToken, now)
            writeRootLocked(root)
            return@synchronized ShareBillingDeliveryClaim(payload = payload?.toMap())
        }
        ShareBillingDeliveryClaim(
            retryAtMillis = ShareBillingPendingPayloadPolicy.nearestRetryAt(root, now)
        )
    }

    fun renew(requestId: String?, ownerToken: String?, now: Long): Boolean = synchronized(lock) {
        if (requestId.isNullOrBlank() || ownerToken.isNullOrBlank()) return@synchronized false
        val root = readRootLocked()
        val renewed = ShareBillingPendingPayloadPolicy.renew(root, requestId, ownerToken, now)
        if (renewed) writeRootLocked(root)
        renewed
    }

    fun markAwaitingConfirmation(requestId: String?, ownerToken: String?, jobId: Long?): Boolean =
        synchronized(lock) {
            if (requestId.isNullOrBlank() || ownerToken.isNullOrBlank() || jobId == null) {
                return@synchronized false
            }
            val root = readRootLocked()
            if (!ShareBillingPendingPayloadPolicy.isCurrentOwner(root, requestId, ownerToken)) {
                return@synchronized false
            }
            root.optJSONObject(requestId)?.apply {
                put(ShareBillingForegroundService.EXTRA_JOB_ID, jobId)
                remove(ShareBillingForegroundService.EXTRA_DISPATCH_LEASE_UNTIL)
            }
            writeRootLocked(root)
            true
        }

    fun removeIfOwner(requestId: String?, ownerToken: String?): Boolean = synchronized(lock) {
        if (requestId.isNullOrBlank() || ownerToken.isNullOrBlank()) return@synchronized false
        val root = readRootLocked()
        val removed = ShareBillingPendingPayloadPolicy.removeIfOwner(root, requestId, ownerToken)
        if (removed) writeRootLocked(root)
        removed
    }

    fun acknowledge(jobId: Long) = synchronized(lock) {
        val root = readRootLocked()
        root.keys().asSequence().toList().forEach { key ->
            if (root.optJSONObject(key)
                    ?.optLong(ShareBillingForegroundService.EXTRA_JOB_ID, -1L) == jobId
            ) root.remove(key)
        }
        writeRootLocked(root)
    }

    private fun readRootLocked(): JSONObject {
        val raw = prefs.getString(PREF_PENDING_PAYLOAD, null) ?: return JSONObject()
        return try {
            val normalized = ShareBillingPendingPayloadPolicy.normalizeRoot(raw)
            if (normalized.changed) writeRootLocked(normalized.root)
            normalized.root
        } catch (_: Exception) {
            JSONObject()
        }
    }

    private fun writeRootLocked(root: JSONObject) {
        val editor = prefs.edit()
        if (root.length() == 0) editor.remove(PREF_PENDING_PAYLOAD)
        else editor.putString(PREF_PENDING_PAYLOAD, root.toString())
        check(editor.commit()) { "Unable to persist share billing delivery state" }
    }

    companion object {
        private val lock = Any()
        const val PREFS_NAME = "share_billing_payloads"
        const val PREF_PENDING_PAYLOAD = "pending_payload"
    }
}

private fun JSONObject.toMap(): Map<String, Any?> {
    val result = linkedMapOf<String, Any?>()
    keys().forEach { key ->
        result[key] = when (val value = opt(key)) {
            JSONObject.NULL -> null
            else -> value
        }
    }
    return result
}
