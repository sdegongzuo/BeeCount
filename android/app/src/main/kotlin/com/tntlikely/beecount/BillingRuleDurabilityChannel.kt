package com.tntlikely.beecount

import android.system.Os
import android.system.OsConstants
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile

/** Android fsync boundary for the public billing-rule activation journal. */
object BillingRuleDurabilityChannel {
    private const val CHANNEL = "com.tntlikely.beecount/billing_rule_durability"

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "syncFileAndParent") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val rawPath = call.arguments as? String
                    ?: error("file path is required")
                val file = File(rawPath).canonicalFile
                check(file.isFile) { "durability target is not a file: $file" }
                RandomAccessFile(file, "r").use { it.fd.sync() }
                val parent = file.parentFile ?: error("file has no parent")
                val directoryFd = Os.open(
                    parent.absolutePath,
                    OsConstants.O_RDONLY,
                    0,
                )
                try {
                    Os.fsync(directoryFd)
                } finally {
                    Os.close(directoryFd)
                }
                result.success(null)
            } catch (error: Throwable) {
                result.error("billing_rule_fsync_failed", error.message, null)
            }
        }
    }
}
