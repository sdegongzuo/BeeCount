package com.tntlikely.beecount

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.FileNotFoundException
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.UUID

class ShareBillingActivity : Activity() {
    private var pendingStartPayload: ShareBillingPayload? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (handleShareIntent(intent)) {
            finish()
        }
    }

    private fun handleShareIntent(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("image/") != true) {
            LoggerPlugin.warning(TAG, "Unsupported share intent: action=${intent?.action}, type=${intent?.type}")
            return true
        }

        val imageUri = readSharedImageUri(intent)
        if (imageUri == null) {
            LoggerPlugin.warning(
                TAG,
                "Image share intent did not contain a readable image uri: " +
                    "flags=${intent.flags}, clipDataCount=${intent.clipData?.itemCount ?: 0}, data=${intent.data}"
            )
            Toast.makeText(this, "无法读取分享图片", Toast.LENGTH_SHORT).show()
            return true
        }

        val receivedAtMillis = System.currentTimeMillis()
        publishImmediateProgressNotification()
        try {
            val cacheFile = copySharedImageToCache(imageUri, intent.type, receivedAtMillis)
            val metadata = readOriginalImageMetadata(imageUri)
            val payload = ShareBillingPayload(
                cacheImagePath = cacheFile.absolutePath,
                originalUri = imageUri.toString(),
                mimeType = intent.type,
                receivedAtMillis = receivedAtMillis,
                metadata = metadata,
                c2FixtureId = ShareBillingC2RuntimeCorrelation.accept(
                    applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0,
                    intent.getStringExtra(EXTRA_C2_FIXTURE_ID)
                )
            )

            val started = startBillingForegroundService(payload)
            Toast.makeText(this, "正在识别账单", Toast.LENGTH_SHORT).show()
            LoggerPlugin.info(
                TAG,
                "Share payload ready: cache=${cacheFile.name}, screenshotTime=${metadata.screenshotTimeMillis}"
            )
            return started
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle image share", e)
            LoggerPlugin.error(
                TAG,
                "处理分享图片失败: uri=$imageUri, scheme=${imageUri.scheme}, " +
                    "flags=${intent.flags}, error=${e.javaClass.simpleName}: ${e.message}"
            )
            Toast.makeText(this, "处理分享图片失败", Toast.LENGTH_SHORT).show()
            startBillingFailureService(e.message ?: "share_failed")
            return true
        }
    }

    private fun readSharedImageUri(intent: Intent): Uri? {
        val extraStream = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        if (extraStream != null) return extraStream

        val clipData = intent.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) {
                clipData.getItemAt(index).uri?.let { return it }
            }
        }

        return intent.data
    }

    private fun copySharedImageToCache(uri: Uri, mimeType: String?, receivedAtMillis: Long): File {
        val cacheDir = File(cacheDir, CACHE_DIR_NAME).apply { mkdirs() }
        val extension = extensionFor(uri, mimeType)
        val cacheFile = File(cacheDir, "shared_${receivedAtMillis}_${UUID.randomUUID()}.$extension")

        val inputStream = try {
            contentResolver.openInputStream(uri)
        } catch (e: FileNotFoundException) {
            LoggerPlugin.error(
                TAG,
                "Unable to open shared image stream: uri=$uri, scheme=${uri.scheme}, " +
                    "error=${e.javaClass.simpleName}: ${e.message}"
            )
            throw e
        } catch (e: SecurityException) {
            LoggerPlugin.error(
                TAG,
                "No permission to open shared image stream: uri=$uri, scheme=${uri.scheme}, " +
                    "error=${e.javaClass.simpleName}: ${e.message}"
            )
            throw e
        }

        inputStream.use { input ->
            requireNotNull(input) { "Unable to open shared image stream." }
            cacheFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        return cacheFile
    }

    private fun extensionFor(uri: Uri, mimeType: String?): String {
        val fromMime = mimeType
            ?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
            ?.takeIf { it.isNotBlank() }
        if (fromMime != null) return fromMime

        return uri.lastPathSegment
            ?.substringAfterLast('.', missingDelimiterValue = "")
            ?.lowercase(Locale.US)
            ?.takeIf { it.matches(Regex("[a-z0-9]{1,5}")) }
            ?: "jpg"
    }

    private fun readOriginalImageMetadata(uri: Uri): ShareBillingImageMetadata {
        val mediaStoreMetadata = queryMediaStoreMetadata(uri)
        val exifTimeMillis = readExifTimeMillis(uri)
        return ShareBillingImageMetadata(
            dateAddedSeconds = mediaStoreMetadata.dateAddedSeconds,
            dateTakenMillis = mediaStoreMetadata.dateTakenMillis,
            exifTimeMillis = exifTimeMillis
        )
    }

    private fun queryMediaStoreMetadata(uri: Uri): MediaStoreMetadata {
        val projection = arrayOf(
            MediaStore.Images.Media.DATE_ADDED,
            MediaStore.Images.Media.DATE_TAKEN
        )

        return try {
            contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (!cursor.moveToFirst()) return MediaStoreMetadata()

                MediaStoreMetadata(
                    dateAddedSeconds = cursor.longOrNull(MediaStore.Images.Media.DATE_ADDED),
                    dateTakenMillis = cursor.longOrNull(MediaStore.Images.Media.DATE_TAKEN)
                )
            } ?: MediaStoreMetadata()
        } catch (e: Exception) {
            LoggerPlugin.warning(TAG, "读取MediaStore时间失败: ${e.message}")
            MediaStoreMetadata()
        }
    }

    private fun readExifTimeMillis(uri: Uri): Long? {
        return try {
            contentResolver.openInputStream(uri)?.use { input ->
                val exif = ExifInterface(input)
                listOf(
                    ExifInterface.TAG_DATETIME_ORIGINAL,
                    ExifInterface.TAG_DATETIME_DIGITIZED,
                    ExifInterface.TAG_DATETIME
                ).firstNotNullOfOrNull { tag ->
                    parseExifDateTime(exif.getAttribute(tag))
                }
            }
        } catch (e: Exception) {
            LoggerPlugin.warning(TAG, "读取EXIF时间失败: ${e.message}")
            null
        }
    }

    private fun parseExifDateTime(value: String?): Long? {
        if (value.isNullOrBlank()) return null
        return try {
            EXIF_DATE_FORMAT.get()?.parse(value)?.time
        } catch (_: Exception) {
            null
        }
    }

    private fun startBillingForegroundService(payload: ShareBillingPayload): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingStartPayload = payload
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_POST_NOTIFICATIONS
            )
            LoggerPlugin.info(TAG, "Requesting notification permission before share billing service")
            return false
        }
        startBillingForegroundServiceUnchecked(payload)
        return true
    }

    private fun startBillingForegroundServiceUnchecked(payload: ShareBillingPayload) {
        val serviceIntent = ShareBillingForegroundService.createStartIntent(this, payload)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun publishImmediateProgressNotification() {
        if (!canPostNotification()) return
        createNotificationChannel()
        try {
            NotificationManagerCompat.from(this).notify(
                NOTIFICATION_ID,
                buildProgressNotification("正在读取分享图片")
            )
            LoggerPlugin.info(TAG, "Immediate share billing notification published: id=$NOTIFICATION_ID")
        } catch (e: SecurityException) {
            LoggerPlugin.warning(TAG, "Immediate share billing notification blocked: ${e.message}")
        }
    }

    private fun canPostNotification(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
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
    }

    private fun buildProgressNotification(contentText: String): Notification {
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
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setOnlyAlertOnce(true)
            .build()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_POST_NOTIFICATIONS) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        LoggerPlugin.info(TAG, "Notification permission result before share billing: granted=$granted")
        pendingStartPayload?.let { startBillingForegroundServiceUnchecked(it) }
        pendingStartPayload = null
        finish()
    }

    private fun startBillingFailureService(reason: String) {
        val serviceIntent = ShareBillingForegroundService.createFailedIntent(this, reason)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private data class MediaStoreMetadata(
        val dateAddedSeconds: Long? = null,
        val dateTakenMillis: Long? = null
    )

    companion object {
        const val EXTRA_C2_FIXTURE_ID = "com.tntlikely.beecount.extra.SHARE_C2_FIXTURE_ID"
        private const val TAG = "ShareBillingActivity"
        private const val CACHE_DIR_NAME = "share_billing"
        private const val REQUEST_POST_NOTIFICATIONS = 2404
        private const val CHANNEL_ID = "share_billing_processing_v2"
        private const val NOTIFICATION_ID = 2404

        private val EXIF_DATE_FORMAT = object : ThreadLocal<SimpleDateFormat>() {
            override fun initialValue(): SimpleDateFormat {
                return SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US)
            }
        }
    }
}

private fun android.database.Cursor.longOrNull(columnName: String): Long? {
    val index = getColumnIndex(columnName)
    if (index < 0 || isNull(index)) return null
    return getLong(index).takeIf { it > 0L }
}
