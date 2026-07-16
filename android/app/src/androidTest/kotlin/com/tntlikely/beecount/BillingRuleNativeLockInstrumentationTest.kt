package com.tntlikely.beecount

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class BillingRuleNativeLockInstrumentationTest {
    @Test
    fun twoEngineOwnersSerializeAndEngineDestroyReleases() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val lockFile = File(context.cacheDir, "billing-rule-${UUID.randomUUID()}.lock")
        val manager = BillingRuleNativeLockManager()
        manager.openOwner("instrumented-main-engine")
        manager.openOwner("instrumented-headless-engine")
        val executor = Executors.newSingleThreadExecutor()
        val secondEntered = CountDownLatch(1)

        manager.acquire("instrumented-main-engine", lockFile.path, 5_000)
        val second = executor.submit<String> {
            manager.acquire("instrumented-headless-engine", lockFile.path, 5_000).also {
                secondEntered.countDown()
            }
        }
        assertFalse(secondEntered.await(150, TimeUnit.MILLISECONDS))

        manager.closeOwner("instrumented-main-engine")
        assertTrue(secondEntered.await(5, TimeUnit.SECONDS))
        manager.release("instrumented-headless-engine", second.get(5, TimeUnit.SECONDS))
        manager.closeOwner("instrumented-headless-engine")
        executor.shutdownNow()
    }
}
