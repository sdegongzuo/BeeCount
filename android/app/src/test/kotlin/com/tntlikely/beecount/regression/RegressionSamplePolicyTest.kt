package com.tntlikely.beecount.regression

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import org.json.JSONObject

class RegressionSamplePolicyTest {
    @Test
    fun `channel JSON conversion recursively supports arrays`() {
        val converted = RegressionSampleChannelJson.toChannelValue(
            JSONObject("{\"evidence\":[\"金额\",{\"values\":[12,null]}]}")
        ) as Map<*, *>

        assertEquals(listOf("金额", mapOf("values" to listOf(12, null))), converted["evidence"])
    }

    @Test
    fun `exact fingerprint ignores harmless OCR whitespace differences`() {
        val first = RegressionSampleFingerprint.exact(
            normalizedOcr = " 支付成功\r\n  金额  12.00 ",
            expectedFieldsJson = "{\"amount\":12,\"merchant\":\"蜂店\"}",
            sensitiveEvidenceJson = "{\"order\":\"A1\"}",
        )
        val equivalent = RegressionSampleFingerprint.exact(
            normalizedOcr = "支付成功\n金额 12.00",
            expectedFieldsJson = "{\"merchant\":\"蜂店\",\"amount\":12}",
            sensitiveEvidenceJson = "{\"order\":\"A1\"}",
        )

        assertEquals(first, equivalent)
    }

    @Test
    fun `exact fingerprint changes when expected behaviour changes`() {
        val expense = RegressionSampleFingerprint.exact("金额 12", "{\"type\":\"expense\"}", "{}")
        val income = RegressionSampleFingerprint.exact("金额 12", "{\"type\":\"income\"}", "{}")

        assertNotEquals(expense, income)
    }

    @Test
    fun `retention evicts oldest duplicate coverage before unique or protected samples`() {
        val samples = listOf(
            retentionSample("duplicate-old", "wechat-payment", protected = false, createdAt = 1),
            retentionSample("unique", "alipay-transfer", protected = false, createdAt = 2),
            retentionSample("protected", "wechat-payment", protected = true, createdAt = 0),
            retentionSample("duplicate-new", "wechat-payment", protected = false, createdAt = 3),
        )

        assertEquals(
            listOf("duplicate-old"),
            RegressionSampleRetention.selectOrdinaryIdsToEvict(samples, ordinaryLimit = 2),
        )
    }

    private fun retentionSample(
        id: String,
        structure: String,
        protected: Boolean,
        createdAt: Long,
    ) = RetentionSample(id, structure, protected, createdAt)
}
