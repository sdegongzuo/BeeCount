package com.tntlikely.beecount

import java.util.Locale

data class ShareBillingNotificationContent(
    val title: String,
    val text: String
) {
    companion object {
        fun created(amount: Double?, note: String?): ShareBillingNotificationContent {
            val title = if (amount == null) {
                "记账已创建"
            } else {
                "记账已创建 ¥${String.format(Locale.US, "%.2f", amount)}"
            }
            val normalizedNote = note?.trim().orEmpty()
            val text = if (normalizedNote.isEmpty()) {
                "正在完善账单信息"
            } else {
                "正在完善信息 · 备注: $normalizedNote"
            }
            return ShareBillingNotificationContent(title, text)
        }

        fun completed(amount: Double?, note: String?): ShareBillingNotificationContent {
            val title = if (amount == null) {
                "记账完成"
            } else {
                "记账完成 ¥${String.format(Locale.US, "%.2f", amount)}"
            }
            val normalizedNote = note?.trim().orEmpty()
            val text = if (normalizedNote.isEmpty()) {
                "已自动创建账单记录"
            } else {
                "备注: $normalizedNote"
            }
            return ShareBillingNotificationContent(title, text)
        }
    }
}
