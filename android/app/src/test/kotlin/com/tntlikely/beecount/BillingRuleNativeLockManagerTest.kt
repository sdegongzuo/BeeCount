package com.tntlikely.beecount

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

class BillingRuleNativeLockManagerTest {
    @Test
    fun `engine destroy retains lease until held action stops and destroy returns`() {
        val directory = Files.createTempDirectory("billing-rule-native-lock")
        val lockPath = directory.resolve("billing_rules.lock").toString()
        val manager = BillingRuleNativeLockManager()
        manager.openOwner("main-engine")
        manager.openOwner("headless-engine")
        val executor = Executors.newFixedThreadPool(2)
        val firstAcquired = CountDownLatch(1)
        val allowFirstToFinish = CountDownLatch(1)
        val secondAcquired = CountDownLatch(1)

        val first = executor.submit<String> {
            manager.acquire("main-engine", lockPath, 5_000).also {
                firstAcquired.countDown()
                allowFirstToFinish.await(5, TimeUnit.SECONDS)
            }
        }
        assertTrue(firstAcquired.await(5, TimeUnit.SECONDS))
        val second = executor.submit<String> {
            manager.acquire("headless-engine", lockPath, 5_000).also {
                secondAcquired.countDown()
            }
        }

        assertFalse(secondAcquired.await(150, TimeUnit.MILLISECONDS))
        manager.beginOwnerShutdown("main-engine")
        assertFalse(
            "begin shutdown must retain the lease until the engine stops",
            secondAcquired.await(150, TimeUnit.MILLISECONDS),
        )
        allowFirstToFinish.countDown()
        assertNotNull(first.get(5, TimeUnit.SECONDS))
        assertFalse(
            "finishing Dart work alone must not bypass the engine-stop boundary",
            secondAcquired.await(150, TimeUnit.MILLISECONDS),
        )
        manager.closeOwner("main-engine")
        assertTrue(secondAcquired.await(5, TimeUnit.SECONDS))
        assertNotNull(second.get(5, TimeUnit.SECONDS))

        manager.closeOwner("headless-engine")
        assertNull(manager.currentOwnerForTest())
        executor.shutdownNow()
    }

    @Test
    fun `waiting acquire times out and destroyed owner is cancelled`() {
        val lockPath = Files.createTempDirectory("billing-rule-native-lock-timeout")
            .resolve("billing_rules.lock")
            .toString()
        val manager = BillingRuleNativeLockManager()
        manager.openOwner("holder")
        manager.openOwner("timeout-owner")
        manager.openOwner("destroyed-owner")
        val holderToken = manager.acquire("holder", lockPath, 1_000)

        try {
            manager.acquire("timeout-owner", lockPath, 50)
            throw AssertionError("acquire should time out")
        } catch (_: TimeoutException) {
        }

        val executor = Executors.newSingleThreadExecutor()
        val waiting = executor.submit<String> {
            manager.acquire("destroyed-owner", lockPath, 5_000)
        }
        Thread.sleep(50)
        manager.beginOwnerShutdown("destroyed-owner")
        try {
            waiting.get(5, TimeUnit.SECONDS)
            throw AssertionError("destroyed owner should be cancelled")
        } catch (error: ExecutionException) {
            assertTrue(error.cause is java.util.concurrent.CancellationException)
        }
        manager.closeOwner("destroyed-owner")

        assertTrue(manager.release("holder", holderToken))
        manager.closeOwner("holder")
        manager.closeOwner("timeout-owner")
        executor.shutdownNow()
    }
}
