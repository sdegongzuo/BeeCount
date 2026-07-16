package com.tntlikely.beecount

import java.nio.channels.FileChannel
import java.nio.channels.FileLock
import java.nio.channels.OverlappingFileLockException
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardOpenOption
import java.util.UUID
import java.util.concurrent.CancellationException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.locks.ReentrantLock

/**
 * Process-wide owner-token mutex backed by an OS file lock for other processes.
 *
 * [acquire] is blocking by design and must be called from a worker thread. It uses
 * `tryLock`, so neither the Android platform thread nor the JVM file-lock call is
 * blocked while another process owns the file.
 */
class BillingRuleNativeLockManager {
    private val stateLock = ReentrantLock(true)
    private val ownerChanged = stateLock.newCondition()
    private val openOwners = mutableSetOf<String>()
    private var activeLease: Lease? = null

    fun openOwner(ownerId: String) {
        stateLock.lock()
        try {
            check(openOwners.add(ownerId)) { "lock owner is already open" }
        } finally {
            stateLock.unlock()
        }
    }

    fun acquire(ownerId: String, rawPath: String, timeoutMillis: Long): String {
        require(timeoutMillis in 1..60_000) { "invalid lock timeout" }
        val deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(timeoutMillis)
        val path = Path.of(rawPath).toAbsolutePath().normalize()
        Files.createDirectories(path.parent)

        stateLock.lockInterruptibly()
        try {
            while (true) {
                if (ownerId !in openOwners) {
                    throw CancellationException("lock owner is closed")
                }
                if (activeLease == null) {
                    val fileLease = tryAcquireFile(path)
                    if (fileLease != null) {
                        val token = UUID.randomUUID().toString()
                        activeLease = Lease(ownerId, token, fileLease.first, fileLease.second)
                        return token
                    }
                }

                val remaining = deadline - System.nanoTime()
                if (remaining <= 0L) throw TimeoutException("billing-rule lock timed out")
                ownerChanged.awaitNanos(
                    minOf(remaining, TimeUnit.MILLISECONDS.toNanos(25)),
                )
            }
        } finally {
            stateLock.unlock()
        }
    }

    fun release(ownerId: String, token: String): Boolean {
        stateLock.lock()
        try {
            val lease = activeLease ?: return false
            if (lease.ownerId != ownerId || lease.token != token) return false
            releaseActiveLease()
            return true
        } finally {
            stateLock.unlock()
        }
    }

    fun closeOwner(ownerId: String) {
        stateLock.lock()
        try {
            openOwners -= ownerId
            if (activeLease?.ownerId == ownerId) releaseActiveLease()
            ownerChanged.signalAll()
        } finally {
            stateLock.unlock()
        }
    }

    internal fun currentOwnerForTest(): String? {
        stateLock.lock()
        return try {
            activeLease?.ownerId
        } finally {
            stateLock.unlock()
        }
    }

    private fun tryAcquireFile(path: Path): Pair<FileChannel, FileLock>? {
        val channel = FileChannel.open(
            path,
            StandardOpenOption.CREATE,
            StandardOpenOption.WRITE,
        )
        return try {
            val lock = channel.tryLock()
            if (lock == null) {
                channel.close()
                null
            } else {
                channel to lock
            }
        } catch (_: OverlappingFileLockException) {
            channel.close()
            null
        } catch (error: Throwable) {
            channel.close()
            throw error
        }
    }

    private fun releaseActiveLease() {
        val lease = activeLease ?: return
        activeLease = null
        try {
            lease.fileLock.release()
        } finally {
            lease.channel.close()
            ownerChanged.signalAll()
        }
    }

    private data class Lease(
        val ownerId: String,
        val token: String,
        val channel: FileChannel,
        val fileLock: FileLock,
    )
}

/** Shared by every FlutterEngine and Android service in this app process. */
object BillingRuleNativeLockManagerHolder {
    val manager = BillingRuleNativeLockManager()
}
