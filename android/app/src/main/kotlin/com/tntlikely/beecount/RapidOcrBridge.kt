package com.tntlikely.beecount

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import androidx.exifinterface.media.ExifInterface
import com.benjaminwan.ocrlibrary.OcrEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class RapidOcrBridge(private val context: Context) {
    companion object {
        const val CHANNEL = "com.tntlikely.beecount/rapid_ocr"
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var ocrEngine: OcrEngine? = null

    fun setup(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(true)
                "recognizeImage" -> {
                    val path = call.argument<String>("path")
                    val maxSideLen = call.argument<Int>("maxSideLen") ?: 1920
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENT", "Image path is required.", null)
                        return@setMethodCallHandler
                    }

                    executor.execute {
                        try {
                            val data = recognizeImage(path, maxSideLen)
                            mainHandler.post { result.success(data) }
                        } catch (e: Throwable) {
                            LoggerPlugin.error("RapidOCR", "recognizeImage failed: ${e.message}")
                            mainHandler.post {
                                result.error(
                                    "RAPID_OCR_FAILED",
                                    e.message ?: "RapidOCR failed.",
                                    null
                                )
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun engine(): OcrEngine {
        val current = ocrEngine
        if (current != null) return current

        return synchronized(this) {
            val locked = ocrEngine
            if (locked != null) {
                locked
            } else {
                OcrEngine(context.applicationContext).also {
                    ocrEngine = it
                    LoggerPlugin.info("RapidOCR", "OcrEngine initialized")
                }
            }
        }
    }

    private fun recognizeImage(path: String, maxSideLen: Int): Map<String, Any?> {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("Image file does not exist: $path")
        }

        val decoded = BitmapFactory.decodeFile(
            file.absolutePath,
            BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
        ) ?: throw IllegalArgumentException("Unable to decode image: $path")

        var input: Bitmap? = null
        var output: Bitmap? = null
        try {
            input = rotateByExif(decoded, file.absolutePath)
            if (input !== decoded) {
                decoded.recycle()
            }
            output = input.copy(Bitmap.Config.ARGB_8888, true)

            val startedAt = System.currentTimeMillis()
            val ocrResult = engine().detect(input, output, maxSideLen.coerceIn(320, 4096))
            val durationMs = System.currentTimeMillis() - startedAt
            val rawText = ocrResult.strRes.ifBlank {
                ocrResult.textBlocks.joinToString(separator = "\n") { it.text }
            }

            return mapOf(
                "rawText" to rawText,
                "durationMs" to durationMs,
                "dbNetTime" to ocrResult.dbNetTime,
                "detectTime" to ocrResult.detectTime,
                "blocks" to ocrResult.textBlocks.map { block ->
                    mapOf(
                        "text" to block.text,
                        "boxScore" to block.boxScore,
                        "angleIndex" to block.angleIndex,
                        "angleScore" to block.angleScore,
                        "points" to block.boxPoint.map { point ->
                            mapOf("x" to point.x, "y" to point.y)
                        }
                    )
                }
            )
        } finally {
            output?.recycle()
            input?.recycle()
        }
    }

    private fun rotateByExif(bitmap: Bitmap, path: String): Bitmap {
        val rotation = try {
            when (ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } catch (_: Throwable) {
            0f
        }

        if (rotation == 0f) return bitmap
        val matrix = Matrix().apply { postRotate(rotation) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
}
