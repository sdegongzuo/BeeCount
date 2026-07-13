package com.tntlikely.beecount

import org.junit.Assert.assertEquals
import org.junit.Test

class ShareBillingNotificationContentTest {
    @Test
    fun formatsCompletedExpenseLikeLegacyImageBillingNotification() {
        val content = ShareBillingNotificationContent.completed(
            amount = 3.75,
            note = "高速通行费"
        )

        assertEquals("记账完成 ¥3.75", content.title)
        assertEquals("备注: 高速通行费", content.text)
    }

    @Test
    fun usesFallbackTextWhenNoteIsBlank() {
        val content = ShareBillingNotificationContent.completed(
            amount = 12.0,
            note = " "
        )

        assertEquals("记账完成 ¥12.00", content.title)
        assertEquals("已自动创建账单记录", content.text)
    }

    @Test
    fun omitsAmountWhenCompletionPayloadHasNoAmount() {
        val content = ShareBillingNotificationContent.completed(
            amount = null,
            note = "午餐"
        )

        assertEquals("记账完成", content.title)
        assertEquals("备注: 午餐", content.text)
    }
}
