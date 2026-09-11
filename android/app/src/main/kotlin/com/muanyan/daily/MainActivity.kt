package com.muanyan.daily

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 必须是 FlutterFragmentActivity：隐私锁用的 local_auth 在 Android 上的实现就是往
 * FragmentManager 里挂一个 BiometricPrompt，而 FlutterActivity 没有 FragmentManager。
 * 换回 FlutterActivity 会启动即崩，主题也得跟着继承 AppCompat（见 res/values/styles.xml）。
 */
class MainActivity : FlutterFragmentActivity() {

    private var channel: MethodChannel? = null

    /// 桌面图标长按快捷方式带进来的动作。引擎起来了但 Dart 还没注册 handler 时，
    /// 动作先在这儿存着，等 Dart 主动来问。
    private var pending: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // 冷启动的 intent 得在 super.onCreate 之前读出来 —— configureFlutterEngine 是在
        // super.onCreate 里回调的，等到那时候再读就晚了
        pending = shortcutOf(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val c = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kChannel)
        c.setMethodCallHandler { call, result ->
            if (call.method == "takePending") {
                result.success(pending)
                pending = null
            } else {
                result.notImplemented()
            }
        }
        channel = c
    }

    /// activity 是 singleTop：App 已经开着时点快捷方式不会再走 onCreate，只来这儿
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = shortcutOf(intent) ?: return
        pending = action
        try {
            channel?.invokeMethod("shortcut", action)
        } catch (_: Exception) {
            // 推不过去也没关系，Dart 下次问 takePending 时还能拿到
        }
    }

    private fun shortcutOf(intent: Intent?): String? = when (intent?.action) {
        kActionNew -> "new"
        kActionTimeline -> "timeline"
        else -> null
    }

    companion object {
        private const val kChannel = "com.muanyan.daily/shortcuts"
        private const val kActionNew = "com.muanyan.daily.action.NEW_DAILY"
        private const val kActionTimeline = "com.muanyan.daily.action.TIMELINE"
    }
}
