package com.tntlikely.beecount

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import android.widget.Toast
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.UUID

class ShareBillingActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
        finish()
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("image/") != true) {
            LoggerPlugin.warning(TAG, "Unsupported share intent: action=${intent?.action}, type=${intent?.type}")
            return
        }

        val imageUri = readSharedImageUri(intent)
        if (imageUri == null) {
            LoggerPlugin.warning(TAG, "Image share intent did not contain EXTRA_STREAM")
            Toast.makeText(this, "无法读取分享图片", Toast.LENGTH_SHORT).show()
            return
        }

        val receivedAtMillis = System.currentTimeMillis()
        try {
            val cacheFile = copySharedImageToCache(imageUri, intent.type, receivedAtMillis)
            val metadata = readOriginalImageMetadata(imageUri)
            val payload = ShareBillingPayload(
                cacheImagePath = cacheFile.absolutePath,
                originalUri = imageUri.toString(),
                mimeType = intent.type,
                receivedAtMillis = receivedAtMillis,
                metadata = metadata
            )

            startBillingForegroundService(payload)
            Toast.makeText(this, "正在识别账单", Toast.LENGTH_SHORT).show()
            LoggerPlugin.info(
                TAG,
                "Share payload ready: cache=${cacheFile.name}, screenshotTime=${metadata.screenshotTimeMillis}"
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle image share", e)
            LoggerPlugin.error(TAG, "处理分享图片失败: ${e.message}")
            Toast.makeText(this, "处理分享图片失败", Toast.LENGTH_SHORT).show()
            startBillingFailureService(e.message ?: "share_failed")
        }
    }

    private fun readSharedImageUri(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    private fun copySharedImageToCache(uri: Uri, mimeType: String?, receivedAtMillis: Long): File {
        val cacheDir = File(cacheDir, CACHE_DIR_NAME).apply { mkdirs() }
        val extension = extensionFor(uri, mimeType)
        val cacheFile = File(cacheDir, "shared_${receivedAtMillis}_${UUID.randomUUID()}.$extension")

        contentResolver.openInputStream(uri).use { input ->
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

    private fun startBillingForegroundService(payload: ShareBillingPayload) {
        val serviceIntent = ShareBillingForegroundService.createStartIntent(this, payload)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
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
        private const val TAG = "ShareBillingActivity"
        private const val CACHE_DIR_NAME = "share_billing"

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
