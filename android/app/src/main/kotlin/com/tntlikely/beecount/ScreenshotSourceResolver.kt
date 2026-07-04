package com.tntlikely.beecount

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Process
import android.util.Log

data class ScreenshotSourceInfo(
    val packageName: String?,
    val appName: String?,
    val paymentChannel: String?,
    val confidence: Double,
    val method: String,
    val eventTimeMillis: Long? = null,
    val queryStartMillis: Long? = null,
    val queryEndMillis: Long? = null,
    val eventCount: Int = 0,
    val foregroundEventCount: Int = 0,
    val ignoredEventCount: Int = 0
) {
    fun toPayload(): Map<String, Any?> = mapOf(
        "sourceAppPackage" to packageName,
        "sourceAppName" to appName,
        "sourcePaymentChannel" to paymentChannel,
        "sourceConfidence" to confidence,
        "sourceMethod" to method,
        "sourceEventTimeMillis" to eventTimeMillis,
        "sourceQueryStartMillis" to queryStartMillis,
        "sourceQueryEndMillis" to queryEndMillis,
        "sourceEventCount" to eventCount,
        "sourceForegroundEventCount" to foregroundEventCount,
        "sourceIgnoredEventCount" to ignoredEventCount
    )
}

class ScreenshotSourceResolver(private val context: Context) {
    companion object {
        private const val TAG = "ScreenshotSource"
        private const val LOOKBACK_MS = 10_000L
        private const val LOOKAHEAD_MS = 2_000L

        private val PAYMENT_CHANNEL_BY_PACKAGE = mapOf(
            // 支付/钱包
            "com.tencent.mm" to "微信支付",
            "com.eg.android.AlipayGphone" to "支付宝",
            "com.unionpay" to "云闪付",
            "cn.gov.pbc.dcep" to "数字人民币",
            "com.paypal.android.p2pmobile" to "PayPal",

            // 本地生活/外卖
            "com.sankuai.meituan" to "美团",
            "com.sankuai.meituan.takeoutnew" to "美团外卖",
            "com.dianping.v1" to "大众点评",
            "me.ele" to "饿了么",

            // 电商/内容平台
            "com.jingdong.app.mall" to "京东",
            "com.jd.jrapp" to "京东金融",
            "com.xunmeng.pinduoduo" to "拼多多",
            "com.taobao.taobao" to "淘宝",
            "com.tmall.wireless" to "天猫",
            "com.taobao.idlefish" to "闲鱼",
            "com.suning.mobile.ebuy" to "苏宁易购",
            "com.achievo.vipshop" to "唯品会",
            "com.ss.android.ugc.aweme" to "抖音",
            "com.ss.android.ugc.aweme.lite" to "抖音",
            "com.smile.gifmaker" to "快手",
            "com.kuaishou.nebula" to "快手",
            "com.xingin.xhs" to "小红书",
            "tv.danmaku.bili" to "哔哩哔哩",

            // 出行/票务
            "com.sdu.didi.psnger" to "滴滴出行",
            "ctrip.android.view" to "携程",
            "com.Qunar" to "去哪儿",
            "com.MobileTicket" to "铁路12306",

            // 银行
            "cmb.pb" to "招商银行",
            "com.icbc" to "工商银行",
            "com.chinamworld.main" to "建设银行",
            "com.android.bankabc" to "农业银行",
            "com.chinamworld.bocmbci" to "中国银行",
            "com.bankcomm.Bankcomm" to "交通银行",
            "com.yitong.mbank.psbc" to "邮储银行",
            "com.pingan.paces.ccms" to "平安银行",
            "cn.com.spdb.mobilebank.per" to "浦发银行",
            "com.ecitic.bank.mobile" to "中信银行",
            "com.cebbank.mobile.cemb" to "光大银行",
            "cn.com.cmbc.newmbank" to "民生银行",
            "com.cgbchina.xpt" to "广发银行",
            "com.cib.cibmb" to "兴业银行",
            "com.hxb.mobile.client" to "华夏银行"
        )

        private val PAYMENT_CHANNEL_BY_APP_LABEL = listOf(
            "微信" to "微信支付",
            "支付宝" to "支付宝",
            "云闪付" to "云闪付",
            "银联" to "云闪付",
            "数字人民币" to "数字人民币",
            "美团外卖" to "美团外卖",
            "美团" to "美团",
            "大众点评" to "大众点评",
            "饿了么" to "饿了么",
            "京东金融" to "京东金融",
            "京东" to "京东",
            "拼多多" to "拼多多",
            "淘宝" to "淘宝",
            "天猫" to "天猫",
            "闲鱼" to "闲鱼",
            "苏宁" to "苏宁易购",
            "唯品会" to "唯品会",
            "抖音" to "抖音",
            "快手" to "快手",
            "小红书" to "小红书",
            "哔哩哔哩" to "哔哩哔哩",
            "Bilibili" to "哔哩哔哩",
            "滴滴" to "滴滴出行",
            "携程" to "携程",
            "去哪儿" to "去哪儿",
            "铁路12306" to "铁路12306",
            "12306" to "铁路12306",
            "招商银行" to "招商银行",
            "掌上生活" to "招商银行",
            "工商银行" to "工商银行",
            "工银" to "工商银行",
            "建设银行" to "建设银行",
            "农业银行" to "农业银行",
            "中国银行" to "中国银行",
            "交通银行" to "交通银行",
            "邮储银行" to "邮储银行",
            "邮政储蓄" to "邮储银行",
            "平安银行" to "平安银行",
            "浦发银行" to "浦发银行",
            "中信银行" to "中信银行",
            "光大银行" to "光大银行",
            "民生银行" to "民生银行",
            "广发银行" to "广发银行",
            "兴业银行" to "兴业银行",
            "华夏银行" to "华夏银行"
        )

        private val IGNORED_PACKAGES = setOf(
            "com.android.systemui",
            "com.google.android.apps.nexuslauncher",
            "com.android.launcher",
            "com.android.launcher2",
            "com.android.launcher3",
            "com.coloros.gallery3d",
            "com.heytap.gallery3d",
            "com.android.gallery3d",
            "com.miui.gallery",
            "com.google.android.apps.photos",
            "com.sec.android.gallery3d",
            "com.huawei.photos",
            "com.vivo.gallery",
            "com.oplus.gallery"
        )
    }

    fun resolve(screenshotTimeMillis: Long): ScreenshotSourceInfo {
        val queryStartMillis = screenshotTimeMillis - LOOKBACK_MS
        val queryEndMillis = screenshotTimeMillis + LOOKAHEAD_MS
        val hasPermission = hasUsageStatsPermission()
        LoggerPlugin.info(
            TAG,
            "开始解析截图来源: screenshotTime=$screenshotTimeMillis, window=$queryStartMillis..$queryEndMillis, hasUsageStats=$hasPermission"
        )

        if (!hasPermission) {
            LoggerPlugin.warning(TAG, "UsageStats权限未授权，无法解析截图来源")
            return ScreenshotSourceInfo(
                packageName = null,
                appName = null,
                paymentChannel = null,
                confidence = 0.0,
                method = "no_usage_stats_permission",
                queryStartMillis = queryStartMillis,
                queryEndMillis = queryEndMillis
            )
        }

        return try {
            val usageStatsManager =
                context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val events = usageStatsManager.queryEvents(
                queryStartMillis,
                queryEndMillis
            )
            val event = UsageEvents.Event()
            var bestPackage: String? = null
            var bestTime = 0L
            var eventCount = 0
            var foregroundEventCount = 0
            var ignoredEventCount = 0
            val candidates = mutableListOf<String>()

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                eventCount++
                if (!isForegroundEvent(event.eventType)) continue
                foregroundEventCount++

                val packageName = event.packageName ?: continue
                if (shouldIgnore(packageName)) {
                    ignoredEventCount++
                    continue
                }
                if (candidates.size < 12) {
                    candidates.add("${event.timeStamp}:$packageName:${event.eventType}")
                }
                if (event.timeStamp >= bestTime) {
                    bestTime = event.timeStamp
                    bestPackage = packageName
                }
            }

            LoggerPlugin.info(
                TAG,
                "UsageStats查询完成: events=$eventCount, foreground=$foregroundEventCount, ignored=$ignoredEventCount, candidates=${candidates.joinToString(",")}"
            )

            if (bestPackage == null) {
                LoggerPlugin.warning(TAG, "未找到可用前台App事件")
                ScreenshotSourceInfo(
                    packageName = null,
                    appName = null,
                    paymentChannel = null,
                    confidence = 0.0,
                    method = "usage_stats_no_candidate",
                    queryStartMillis = queryStartMillis,
                    queryEndMillis = queryEndMillis,
                    eventCount = eventCount,
                    foregroundEventCount = foregroundEventCount,
                    ignoredEventCount = ignoredEventCount
                )
            } else {
                val appName = resolveAppName(bestPackage)
                val channel = PAYMENT_CHANNEL_BY_PACKAGE[bestPackage]
                    ?: inferPaymentChannelFromAppName(appName)
                val confidence = when {
                    PAYMENT_CHANNEL_BY_PACKAGE.containsKey(bestPackage) -> 0.9
                    channel != null -> 0.75
                    else -> 0.5
                }
                LoggerPlugin.info(
                    TAG,
                    "截图来源命中: package=$bestPackage, app=$appName, channel=${channel ?: "无"}, confidence=$confidence, eventTime=$bestTime"
                )
                ScreenshotSourceInfo(
                    packageName = bestPackage,
                    appName = appName,
                    paymentChannel = channel,
                    confidence = confidence,
                    method = "usage_stats",
                    eventTimeMillis = bestTime,
                    queryStartMillis = queryStartMillis,
                    queryEndMillis = queryEndMillis,
                    eventCount = eventCount,
                    foregroundEventCount = foregroundEventCount,
                    ignoredEventCount = ignoredEventCount
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "解析截图来源失败", e)
            LoggerPlugin.error(TAG, "解析截图来源失败: ${e.message}")
            ScreenshotSourceInfo(
                packageName = null,
                appName = null,
                paymentChannel = null,
                confidence = 0.0,
                method = "usage_stats_error",
                queryStartMillis = queryStartMillis,
                queryEndMillis = queryEndMillis
            )
        }
    }

    fun hasUsageStatsPermission(): Boolean {
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
            val allowed = mode == AppOpsManager.MODE_ALLOWED
            LoggerPlugin.info(TAG, "UsageStats权限检查: package=${context.packageName}, mode=$mode, allowed=$allowed")
            allowed
        } catch (e: Exception) {
            LoggerPlugin.error(TAG, "UsageStats权限检查失败: ${e.message}")
            false
        }
    }

    private fun isForegroundEvent(eventType: Int): Boolean {
        return eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
            eventType == UsageEvents.Event.ACTIVITY_RESUMED
    }

    private fun shouldIgnore(packageName: String): Boolean {
        return packageName == context.packageName || IGNORED_PACKAGES.contains(packageName)
    }

    private fun resolveAppName(packageName: String): String? {
        return try {
            val packageManager = context.packageManager
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }

    private fun inferPaymentChannelFromAppName(appName: String?): String? {
        if (appName.isNullOrBlank()) return null
        return PAYMENT_CHANNEL_BY_APP_LABEL
            .firstOrNull { (keyword, _) -> appName.contains(keyword, ignoreCase = true) }
            ?.second
    }
}
