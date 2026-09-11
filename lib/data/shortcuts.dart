import 'dart:async';

import 'package:daily/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 桌面图标长按弹出的快捷方式。
///
/// 原生那边（`MainActivity.kt` + `res/xml/shortcuts.xml`）只把 intent 里的 action
/// 翻译成 `'new'` / `'timeline'` 两个词，**具体怎么响应交给首页** —— 只有它知道
/// 表单和时光轴该怎么开。这样原生侧永远只是「传递一个意图」，不碰导航。
class AppShortcuts {
  AppShortcuts._();

  static final AppShortcuts instance = AppShortcuts._();

  /// 原生只会推这两个词过来。写成常量而不是散落的字面量：
  /// 拼错一个字母不会有任何报错，只会「点了没反应」。
  static const String kNew = 'new';
  static const String kTimeline = 'timeline';

  /// 待处理的动作，`'new'` 或 `'timeline'`。消费方处理完负责置回 null。
  final ValueNotifier<String?> pending = ValueNotifier(null);

  Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      // App 已经开着时点快捷方式：activity 是 singleTop，走 onNewIntent，原生推过来
      if (call.method == 'shortcut') _deliver(call.arguments);
      return null;
    });

    try {
      // 冷启动时 intent 比 Dart 先到，那会儿还没有 handler 可推，原生替我们存着
      _deliver(await _channel.invokeMethod<String>('takePending'));
    } on MissingPluginException {
      // 测试环境 / 非 Android 平台没有这个 channel。快捷方式用不了，
      // 但 App 一切正常，不该在这里抛出去
    } on PlatformException {
      // 同上：原生侧出问题只损失快捷方式这一个入口
    }
  }

  static const MethodChannel _channel = MethodChannel(kShortcutChannel);

  void _deliver(Object? action) {
    if (action is String && action.isNotEmpty) pending.value = action;
  }
}
