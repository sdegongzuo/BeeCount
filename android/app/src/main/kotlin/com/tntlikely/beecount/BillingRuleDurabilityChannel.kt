package com.tntlikely.beecount

import android.system.Os
import android.system.OsConstants
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.util.UUID
import java.util.concurrent.CancellationException
import java.util.concurrent.Executors
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicBoolean

/** Android durability and cross-engine lock boundary for public billing rules. */
object BillingRuleDurabilityChannel {
    private const val CHANNEL = "com.tntlikely.beecount/billing_rule_durability"
    private val executor = Executors.newCachedThreadPool { runnable ->
        Thread(runnable, "billing-rule-storage-lock").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    internal fun afterCurrentEngineLifecycleCallback(action: () -> Unit) {
        mainHandler.post(action)
    }

    fun register(messenger: BinaryMessenger): Registration {
        val ownerId = UUID.randomUUID().toString()
        BillingRuleNativeLockManagerHolder.manager.openOwner(ownerId)
        val channel = MethodChannel(messenger, CHANNEL)
        val registration = Registration(channel, ownerId)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "syncFileAndParent" -> registration.runAsync(result) {
                    syncFileAndParent(
                        call.arguments as? String ?: error("file path is required"),
                    )
                    null
                }
                "acquireStorageLock" -> registration.runAsync(result) {
                    val rawPath = call.argument<String>("path")
                        ?: error("lock path is required")
                    val timeout = call.argument<Number>("timeoutMillis")?.toLong()
                        ?: 30_000L
                    BillingRuleNativeLockManagerHolder.manager.acquire(
                        ownerId,
                        File(rawPath).canonicalPath,
                        timeout,
                    )
                }
                "releaseStorageLock" -> registration.runAsync(result) {
                    val token = call.argument<String>("token")
                        ?: error("lock token is required")
                    check(BillingRuleNativeLockManagerHolder.manager.release(ownerId, token)) {
                        "lock token is not owned by this engine"
                    }
                    null
                }
                else -> result.notImplemented()
            }
        }
        return registration
    }

    private fun syncFileAndParent(rawPath: String) {
        val file = File(rawPath).canonicalFile
        check(file.isFile) { "durability target is not a file: $file" }
        RandomAccessFile(file, "r").use { it.fd.sync() }
        val parent = file.parentFile ?: error("file has no parent")
        val directoryFd = Os.open(parent.absolutePath, OsConstants.O_RDONLY, 0)
        try {
            Os.fsync(directoryFd)
        } finally {
            Os.close(directoryFd)
        }
    }

    class Registration internal constructor(
        private val channel: MethodChannel,
        private val ownerId: String,
    ) : AutoCloseable {
        private val closed = AtomicBoolean(false)
        private val accepting = AtomicBoolean(true)

        internal fun runAsync(result: MethodChannel.Result, action: () -> Any?) {
            if (!accepting.get()) {
                result.error("billing_rule_lock_cancelled", "engine is stopping", null)
                return
            }
            executor.execute {
                try {
                    val value = action()
                    if (!accepting.get()) {
                        if (value is String) {
                            BillingRuleNativeLockManagerHolder.manager.release(ownerId, value)
                        }
                        return@execute
                    }
                    mainHandler.post {
                        if (accepting.get()) result.success(value)
                    }
                } catch (error: Throwable) {
                    if (!accepting.get()) return@execute
                    mainHandler.post {
                        if (accepting.get()) {
                            result.error(errorCode(error), error.message, null)
                        }
                    }
                }
            }
        }

        internal fun beginEngineShutdown() {
            if (!accepting.compareAndSet(true, false)) return
            BillingRuleNativeLockManagerHolder.manager.beginOwnerShutdown(ownerId)
        }

        internal fun finishEngineShutdown(clearHandler: Boolean) {
            if (!closed.compareAndSet(false, true)) return
            accepting.set(false)
            if (clearHandler) channel.setMethodCallHandler(null)
            BillingRuleNativeLockManagerHolder.manager.closeOwner(ownerId)
        }

        override fun close() {
            beginEngineShutdown()
            finishEngineShutdown(clearHandler = true)
        }

        private fun errorCode(error: Throwable): String = when (error) {
            is TimeoutException -> "billing_rule_lock_timeout"
            is CancellationException -> "billing_rule_lock_cancelled"
            else -> "billing_rule_storage_failed"
        }
    }
}

/**
 * Couples a channel owner to the FlutterEngine rather than to an Activity.
 *
 * Engine lifecycle callbacks run synchronously inside restart/destroy. Posting
 * the final close to the same main looper guarantees it cannot run until that
 * restart/destroy call returns and the old Dart isolate has stopped.
 */
class BillingRuleEngineStorageBinding private constructor(
    private val engine: FlutterEngine,
) {
    private val messenger = engine.dartExecutor.binaryMessenger
    private var current = BillingRuleDurabilityChannel.register(messenger)
    private var engineDestroying = false
    private val listener = object : FlutterEngine.EngineLifecycleListener {
        override fun onPreEngineRestart() {
            if (engineDestroying) return
            val retired = current
            retired.beginEngineShutdown()
            current = BillingRuleDurabilityChannel.register(messenger)
            BillingRuleDurabilityChannel.afterCurrentEngineLifecycleCallback {
                retired.finishEngineShutdown(clearHandler = false)
            }
        }

        override fun onEngineWillDestroy() {
            if (engineDestroying) return
            engineDestroying = true
            val retired = current
            retired.beginEngineShutdown()
            BillingRuleDurabilityChannel.afterCurrentEngineLifecycleCallback {
                retired.finishEngineShutdown(clearHandler = true)
                engine.removeEngineLifecycleListener(this)
            }
        }
    }

    init {
        engine.addEngineLifecycleListener(listener)
    }

    /** Called only after [FlutterEngine.destroy] has synchronously returned. */
    fun closeAfterEngineDestroyed() {
        engineDestroying = true
        current.beginEngineShutdown()
        current.finishEngineShutdown(clearHandler = true)
        engine.removeEngineLifecycleListener(listener)
    }

    companion object {
        fun attach(engine: FlutterEngine): BillingRuleEngineStorageBinding =
            BillingRuleEngineStorageBinding(engine)
    }
}
