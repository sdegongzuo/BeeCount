package com.tntlikely.beecount

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class ShareBillingForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var backgroundEngine: FlutterEngine? = null
    private var backgroundChannel: MethodChannel? = null
    private var pendingBackgroundPayload: Bundle? = null
    private val timeoutRunnable = Runnable {
        LoggerPlugin.warning(TAG, "Share billing foreground service timed out waiting for integration callback")
        stopForegroundService()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()

        when (intent?.action) {
            ACTION_UPDATE -> {
                val status = intent.getStringExtra(EXTRA_STATUS_TEXT) ?: "正在处理账单"
                val notification = buildNotification(status)
                startForegroundCompat(notification)
                publishProgressNotification(notification)
                extendProcessingTimeout()
                return START_NOT_STICKY
            }
            ACTION_COMPLETE -> {
                val content = ShareBillingNotificationContent.completed(
                    amount = intent.getDoubleExtraOrNull(EXTRA_AMOUNT),
                    note = intent.getStringExtra(EXTRA_NOTE)
                )
                val notification = buildNotification(
                    contentText = content.text,
                    title = content.title,
                    ongoing = false
                )
                removeForegroundNotification()
                publishResultNotification(notification)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_FAILED -> {
                val reason = intent.getStringExtra(EXTRA_FAILURE_REASON) ?: "unknown"
                val notification = buildNotification("账单识别失败", ongoing = false)
                removeForegroundNotification()
                publishResultNotification(notification)
                LoggerPlugin.warning(TAG, "Share billing failed: $reason")
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_CREATED -> {
                val content = ShareBillingNotificationContent.created(
                    amount = intent.getDoubleExtraOrNull(EXTRA_AMOUNT),
                    note = intent.getStringExtra(EXTRA_NOTE)
                )
                val notification = buildNotification(
                    contentText = content.text,
                    title = content.title,
                    ongoing = true
                )
                startForegroundCompat(notification)
                publishProgressNotification(notification)
                extendProcessingTimeout()
                LoggerPlugin.info(TAG, "Share billing created notification updated")
                return START_NOT_STICKY
            }
            else -> {
                val notification = buildNotification("正在识别账单")
                startForegroundCompat(notification)
                publishProgressNotification(notification)
                val extras = enrichPayload(intent?.extras ?: Bundle.EMPTY)
                savePendingPayload(extras)
                pendingBackgroundPayload = extras
                if (!dispatchToMainEngine(extras)) {
                    ensureBackgroundEngine()
                }
                extendProcessingTimeout()
                return START_NOT_STICKY
            }
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(timeoutRunnable)
        backgroundChannel?.setMethodCallHandler(null)
        backgroundChannel = null
        pendingBackgroundPayload = null
        backgroundEngine?.destroy()
        backgroundEngine = null
        super.onDestroy()
    }

    private fun ensureBackgroundEngine() {
        if (backgroundEngine != null) return

        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)

        val engine = FlutterEngine(applicationContext)
        RapidOcrBridge(applicationContext).setup(engine.dartExecutor.binaryMessenger)
        val channel = MethodChannel(
            engine.dartExecutor.binaryMessenger,
            BACKGROUND_CHANNEL
        )
        backgroundEngine = engine
        backgroundChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> {
                    LoggerPlugin.info(TAG, "Headless FlutterEngine ready")
                    result.success(null)
                    handler.post { dispatchPendingBackgroundPayload() }
                }
                "updateShareBillingStatus" -> {
                    val status = call.argument<String>("statusText") ?: "姝ｅ湪澶勭悊璐﹀崟"
                    val notification = buildNotification(status)
                    startForegroundCompat(notification)
                    publishProgressNotification(notification)
                    extendProcessingTimeout()
                    result.success(null)
                }
                "completeShareBilling" -> {
                    val amount = call.argument<Number>("amount")?.toDouble()
                    val note = call.argument<String>("note")
                    clearPendingPayload()
                    val content = ShareBillingNotificationContent.completed(
                        amount = amount,
                        note = note
                    )
                    val notification = buildNotification(
                        contentText = content.text,
                        title = content.title,
                        ongoing = false
                    )
                    removeForegroundNotification()
                    publishResultNotification(notification)
                    stopSelf()
                    result.success(null)
                }
                "shareBillingCreated" -> {
                    val amount = call.argument<Number>("amount")?.toDouble()
                    val note = call.argument<String>("note")
                    val content = ShareBillingNotificationContent.created(amount, note)
                    val notification = buildNotification(
                        contentText = content.text,
                        title = content.title,
                        ongoing = true
                    )
                    startForegroundCompat(notification)
                    publishProgressNotification(notification)
                    extendProcessingTimeout()
                    LoggerPlugin.info(TAG, "Share billing created notification updated")
                    result.success(null)
                }
                "failShareBilling" -> {
                    val reason = call.argument<String>("reason") ?: "unknown"
                    clearPendingPayload()
                    val notification = buildNotification("璐﹀崟璇嗗埆澶辫触", ongoing = false)
                    removeForegroundNotification()
                    publishResultNotification(notification)
                    LoggerPlugin.warning(TAG, "Share billing failed: $reason")
                    stopSelf()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        val entrypoint = DartExecutor.DartEntrypoint(
            loader.findAppBundlePath(),
            "shareBillingBackgroundMain"
        )
        engine.dartExecutor.executeDartEntrypoint(entrypoint)
    }

    private fun dispatchToMainEngine(extras: Bundle): Boolean {
        val dispatched = ShareBillingMainEngineBridge.dispatch(bundleToMap(extras))
        if (dispatched) {
            LoggerPlugin.info(
                TAG,
                "Share billing payload dispatched to main FlutterEngine: path=${extras.getString(EXTRA_CACHE_IMAGE_PATH)}"
            )
        }
        return dispatched
    }

    private fun dispatchPendingBackgroundPayload() {
        val payload = pendingBackgroundPayload ?: return
        val channel = backgroundChannel ?: return
        channel.invokeMethod("processShareBilling", bundleToMap(payload))
        LoggerPlugin.info(
            TAG,
            "Share billing payload dispatched to headless engine: path=${payload.getString(EXTRA_CACHE_IMAGE_PATH)}"
        )
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

    private fun clearPendingPayload() {
        pendingBackgroundPayload = null
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .edit()
            .remove(PREF_PENDING_PAYLOAD)
            .apply()
    }

    private fun bundleToMap(bundle: Bundle): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        bundle.keySet().forEach { key ->
            @Suppress("DEPRECATION")
            map[key] = bundle.get(key)
        }
        return map
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "账单识别",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "分享图片后短时识别账单"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
        val created = manager.getNotificationChannel(CHANNEL_ID)
        LoggerPlugin.info(
            TAG,
            "Share billing notification channel ready: id=$CHANNEL_ID, importance=${created?.importance}"
        )
    }

    private fun buildNotification(
        contentText: String,
        title: String = "蜜蜂记账",
        ongoing: Boolean = true
    ): Notification {
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
            .setContentTitle(title)
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_menu_upload)
            .setOngoing(ongoing)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setOnlyAlertOnce(true)
            .setAutoCancel(!ongoing)
            .build()
    }

    private fun startForegroundCompat(notification: Notification) {
        logNotificationState()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        LoggerPlugin.info(TAG, "Share billing foreground notification started: id=$NOTIFICATION_ID")
    }

    private fun logNotificationState() {
        val enabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
        val postGranted = hasPostNotificationPermission()
        LoggerPlugin.info(
            TAG,
            "Share billing notification state: enabled=$enabled, postNotificationsGranted=$postGranted"
        )
    }

    private fun publishResultNotification(notification: Notification) {
        if (!NotificationManagerCompat.from(this).areNotificationsEnabled() || !hasPostNotificationPermission()) {
            LoggerPlugin.warning(TAG, "Skip share billing result notification because notification permission is disabled")
            return
        }
        try {
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, notification)
            LoggerPlugin.info(TAG, "Share billing result notification published: id=$NOTIFICATION_ID")
        } catch (e: SecurityException) {
            LoggerPlugin.warning(TAG, "Share billing result notification blocked: ${e.message}")
        }
    }

    private fun publishProgressNotification(notification: Notification) {
        if (!NotificationManagerCompat.from(this).areNotificationsEnabled() || !hasPostNotificationPermission()) {
            LoggerPlugin.warning(TAG, "Skip share billing progress notification because notification permission is disabled")
            return
        }
        try {
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, notification)
            LoggerPlugin.info(TAG, "Share billing progress notification updated: id=$NOTIFICATION_ID")
        } catch (e: SecurityException) {
            LoggerPlugin.warning(TAG, "Share billing progress notification blocked: ${e.message}")
        }
    }

    private fun hasPostNotificationPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    private fun extendProcessingTimeout() {
        handler.removeCallbacks(timeoutRunnable)
        handler.postDelayed(timeoutRunnable, PROCESSING_TIMEOUT_MS)
    }

    private fun stopForegroundService(removeNotification: Boolean = true) {
        handler.removeCallbacks(timeoutRunnable)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(
                if (removeNotification) {
                    STOP_FOREGROUND_REMOVE
                } else {
                    STOP_FOREGROUND_DETACH
                }
            )
        } else {
            @Suppress("DEPRECATION")
            stopForeground(removeNotification)
        }
        stopSelf()
    }

    private fun removeForegroundNotification() {
        handler.removeCallbacks(timeoutRunnable)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    companion object {
        const val ACTION_START = "com.tntlikely.beecount.action.SHARE_BILLING_START"
        const val ACTION_PAYLOAD_READY = "com.tntlikely.beecount.action.SHARE_BILLING_PAYLOAD_READY"
        const val ACTION_UPDATE = "com.tntlikely.beecount.action.SHARE_BILLING_UPDATE"
        const val ACTION_COMPLETE = "com.tntlikely.beecount.action.SHARE_BILLING_COMPLETE"
        const val ACTION_FAILED = "com.tntlikely.beecount.action.SHARE_BILLING_FAILED"
        const val ACTION_CREATED = "com.tntlikely.beecount.action.SHARE_BILLING_CREATED"

        const val EXTRA_CACHE_IMAGE_PATH = "cacheImagePath"
        const val EXTRA_FAILURE_REASON = "failureReason"
        const val EXTRA_SCREENSHOT_TIME_MILLIS = "screenshotTimeMillis"
        const val EXTRA_STATUS_TEXT = "statusText"
        const val EXTRA_AMOUNT = "amount"
        const val EXTRA_NOTE = "note"

        private const val TAG = "ShareBillingService"
        private const val CHANNEL_ID = "share_billing_processing_v2"
        private const val NOTIFICATION_ID = 2404
        private const val PROCESSING_TIMEOUT_MS = 300_000L
        private const val PREFS_NAME = "share_billing_payloads"
        private const val PREF_PENDING_PAYLOAD = "pending_payload"
        private const val BACKGROUND_CHANNEL =
            "com.tntlikely.beecount/share_background"

        fun createStartIntent(context: Context, payload: ShareBillingPayload): Intent {
            return Intent(context, ShareBillingForegroundService::class.java).apply {
                action = ACTION_START
                putExtras(payload.toBundle())
            }
        }

        fun createCompleteIntent(
            context: Context,
            amount: Double?,
            note: String?
        ): Intent {
            return Intent(context, ShareBillingForegroundService::class.java).apply {
                action = ACTION_COMPLETE
                if (amount != null) putExtra(EXTRA_AMOUNT, amount)
                if (!note.isNullOrBlank()) putExtra(EXTRA_NOTE, note)
            }
        }

        fun createUpdateIntent(context: Context, statusText: String): Intent {
            return Intent(context, ShareBillingForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_STATUS_TEXT, statusText)
            }
        }

        fun createFailedIntent(context: Context, reason: String): Intent {
            return Intent(context, ShareBillingForegroundService::class.java).apply {
                action = ACTION_FAILED
                putExtra(EXTRA_FAILURE_REASON, reason)
            }
        }

        fun createCreatedIntent(
            context: Context,
            amount: Double?,
            note: String?
        ): Intent {
            return Intent(context, ShareBillingForegroundService::class.java).apply {
                action = ACTION_CREATED
                if (amount != null) putExtra(EXTRA_AMOUNT, amount)
                if (!note.isNullOrBlank()) putExtra(EXTRA_NOTE, note)
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

private fun Intent.getDoubleExtraOrNull(key: String): Double? {
    return if (hasExtra(key)) getDoubleExtra(key, 0.0) else null
}
