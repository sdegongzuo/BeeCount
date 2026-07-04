package com.tntlikely.beecount

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class ShareBillingForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val timeoutRunnable = Runnable {
        LoggerPlugin.warning(TAG, "Share billing foreground service timed out waiting for integration callback")
        stopForegroundService()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()

        when (intent?.action) {
            ACTION_COMPLETE -> {
                startForegroundCompat(buildNotification("账单识别已完成"))
                stopForegroundService()
                return START_NOT_STICKY
            }
            ACTION_FAILED -> {
                val reason = intent.getStringExtra(EXTRA_FAILURE_REASON) ?: "unknown"
                startForegroundCompat(buildNotification("账单识别失败"))
                LoggerPlugin.warning(TAG, "Share billing failed: $reason")
                stopForegroundService()
                return START_NOT_STICKY
            }
            else -> {
                startForegroundCompat(buildNotification("正在识别账单"))
                val extras = enrichPayload(intent?.extras ?: Bundle.EMPTY)
                savePendingPayload(extras)
                sendPayloadReadyBroadcast(extras)
                handler.removeCallbacks(timeoutRunnable)
                handler.postDelayed(timeoutRunnable, PROCESSING_TIMEOUT_MS)
                return START_NOT_STICKY
            }
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(timeoutRunnable)
        super.onDestroy()
    }

    private fun sendPayloadReadyBroadcast(extras: Bundle) {
        sendBroadcast(Intent(ACTION_PAYLOAD_READY).apply {
            setPackage(packageName)
            putExtras(extras)
        })
        LoggerPlugin.info(
            TAG,
            "Share billing payload broadcast sent: path=${extras.getString(EXTRA_CACHE_IMAGE_PATH)}, screenshotTime=${extras.getLongOrNull(EXTRA_SCREENSHOT_TIME_MILLIS)}"
        )
    }

    private fun enrichPayload(extras: Bundle): Bundle {
        val enriched = Bundle(extras)
        val screenshotTimeMillis = enriched.getLongOrNull(EXTRA_SCREENSHOT_TIME_MILLIS)
        if (screenshotTimeMillis != null) {
            val source = ScreenshotSourceResolver(applicationContext).resolve(screenshotTimeMillis)
            source.toPayload().forEach { (key, value) ->
                when (value) {
                    null -> Unit
                    is String -> enriched.putString(key, value)
                    is Long -> enriched.putLong(key, value)
                    is Int -> enriched.putInt(key, value)
                    is Double -> enriched.putDouble(key, value)
                    is Float -> enriched.putFloat(key, value)
                    is Boolean -> enriched.putBoolean(key, value)
                    else -> enriched.putString(key, value.toString())
                }
            }
        }
        return enriched
    }

    private fun savePendingPayload(extras: Bundle) {
        val payload = org.json.JSONObject()
        extras.keySet().forEach { key ->
            @Suppress("DEPRECATION")
            payload.put(key, extras.get(key))
        }
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .edit()
            .putString(PREF_PENDING_PAYLOAD, payload.toString())
            .apply()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "账单识别",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "分享图片后短时识别账单"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(contentText: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("蜜蜂记账")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_menu_upload)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopForegroundService() {
        handler.removeCallbacks(timeoutRunnable)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    companion object {
        const val ACTION_START = "com.tntlikely.beecount.action.SHARE_BILLING_START"
        const val ACTION_PAYLOAD_READY = "com.tntlikely.beecount.action.SHARE_BILLING_PAYLOAD_READY"
        const val ACTION_COMPLETE = "com.tntlikely.beecount.action.SHARE_BILLING_COMPLETE"
        const val ACTION_FAILED = "com.tntlikely.beecount.action.SHARE_BILLING_FAILED"

        const val EXTRA_CACHE_IMAGE_PATH = "cacheImagePath"
        const val EXTRA_FAILURE_REASON = "failureReason"
        const val EXTRA_SCREENSHOT_TIME_MILLIS = "screenshotTimeMillis"

        private const val TAG = "ShareBillingService"
        private const val CHANNEL_ID = "share_billing_processing"
        private const val NOTIFICATION_ID = 2404
        private const val PROCESSING_TIMEOUT_MS = 15_000L
        private const val PREFS_NAME = "share_billing_payloads"
        private const val PREF_PENDING_PAYLOAD = "pending_payload"

        fun createStartIntent(context: Context, payload: ShareBillingPayload): Intent {
            return Intent(context, ShareBillingForegroundService::class.java).apply {
                action = ACTION_START
                putExtras(payload.toBundle())
            }
        }

        fun createCompleteIntent(context: Context): Intent {
            return Intent(context, ShareBillingForegroundService::class.java).apply {
                action = ACTION_COMPLETE
            }
        }

        fun createFailedIntent(context: Context, reason: String): Intent {
            return Intent(context, ShareBillingForegroundService::class.java).apply {
                action = ACTION_FAILED
                putExtra(EXTRA_FAILURE_REASON, reason)
            }
        }
    }
}

private fun ShareBillingPayload.toBundle(): Bundle {
    return Bundle().apply {
        toServiceExtras().forEach { (key, value) ->
            when (value) {
                null -> Unit
                is String -> putString(key, value)
                is Long -> putLong(key, value)
                is Int -> putInt(key, value)
                is Double -> putDouble(key, value)
                is Float -> putFloat(key, value)
                is Boolean -> putBoolean(key, value)
                else -> putString(key, value.toString())
            }
        }
    }
}

private fun Bundle.getLongOrNull(key: String): Long? {
    return if (containsKey(key)) getLong(key) else null
}
