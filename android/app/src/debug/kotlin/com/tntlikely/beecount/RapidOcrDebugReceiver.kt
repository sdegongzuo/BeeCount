package com.tntlikely.beecount

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.benjaminwan.ocrlibrary.OcrEngine
import java.io.File
import java.util.concurrent.Executors

class RapidOcrDebugReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        val imagePath = intent.getStringExtra("path") ?: "/data/local/tmp/beecount_rapidocr_sample.jpg"
        val maxSideLen = intent.getIntExtra("maxSideLen", 1920)

        executor.execute {
            try {
                val input = BitmapFactory.decodeFile(imagePath)
                    ?: error("Unable to decode image: $imagePath")
                val output = input.copy(Bitmap.Config.ARGB_8888, true)
                val startedAt = System.currentTimeMillis()
                val result = engine(context.applicationContext)
                    .detect(input, output, maxSideLen)
                val elapsedMs = System.currentTimeMillis() - startedAt
                val text = result.strRes.trim()

                Log.i(TAG, "RapidOCR debug path=$imagePath durationMs=$elapsedMs textLength=${text.length}")
                Log.i(TAG, "RapidOCR debug text begin\n$text\nRapidOCR debug text end")

                // Write OCR result to file for easy retrieval
                val outPath = intent.getStringExtra("outPath")
                if (outPath != null) {
                    try {
                        File(outPath).apply {
                            parentFile?.mkdirs()
                            writeText(text, Charsets.UTF_8)
                        }
                        Log.i(TAG, "RapidOCR debug result written to $outPath")
                    } catch (e: Exception) {
                        Log.e(TAG, "RapidOCR debug failed to write $outPath", e)
                    }
                }

                output.recycle()
                input.recycle()
            } catch (e: Throwable) {
                Log.e(TAG, "RapidOCR debug failed", e)
            } finally {
                pendingResult.finish()
            }
        }
    }

    companion object {
        private const val TAG = "RapidOcrDebugReceiver"
        private val executor = Executors.newSingleThreadExecutor()

        @Volatile
        private var ocrEngine: OcrEngine? = null

        private fun engine(context: Context): OcrEngine {
            val current = ocrEngine
            if (current != null) return current

            return synchronized(this) {
                val locked = ocrEngine
                if (locked != null) {
                    locked
                } else {
                    OcrEngine(context).also { ocrEngine = it }
                }
            }
        }
    }
}
