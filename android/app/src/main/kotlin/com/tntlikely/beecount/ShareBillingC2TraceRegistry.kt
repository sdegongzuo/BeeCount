package com.tntlikely.beecount

import java.util.concurrent.ConcurrentHashMap

/** 精确定位一次 debug C2 ACTION_SEND 的只读键。 */
data class ShareBillingC2TraceKey(
    val fixtureId: String,
    val caseId: String
) {
    companion object {
        private val validCaseId = Regex("^[a-z0-9][a-z0-9-]{0,63}$")

        fun parse(
            isDebug: Boolean,
            fixtureId: String?,
            caseId: String?
        ): ShareBillingC2TraceKey {
            if (!isDebug) throw SecurityException("Share C2 tracer is debug-only")
            val acceptedFixture = ShareBillingC2RuntimeCorrelation.accept(true, fixtureId)
                ?: throw IllegalArgumentException("Missing share C2 fixture id")
            require(caseId != null && validCaseId.matches(caseId)) {
                "Invalid share C2 case id"
            }
            return ShareBillingC2TraceKey(acceptedFixture, caseId)
        }
    }
}

/**
 * 仅记录 ShareBillingActivity 已接受并复制到隔离 cache 的路径。
 *
 * 它不读取或修改 SQLite，也不允许按目录枚举；debug tracer 只能用完整
 * fixture/case 键查询单次 ACTION_SEND 的 production cache 路径。
 */
object ShareBillingC2TraceRegistry {
    private val acceptedPaths = ConcurrentHashMap<ShareBillingC2TraceKey, String>()

    fun recordAccepted(key: ShareBillingC2TraceKey, cacheImagePath: String) {
        require(cacheImagePath.isNotBlank()) { "Share C2 cache path is empty" }
        acceptedPaths[key] = cacheImagePath
    }

    fun locate(key: ShareBillingC2TraceKey): String? = acceptedPaths[key]
}
