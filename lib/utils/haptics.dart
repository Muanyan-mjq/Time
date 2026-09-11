import 'package:flutter/services.dart';

/// 全 App 的触感反馈，`HapticFeedback` 的语义化包装。
///
/// 包一层而不是在各个调用点直接调 `HapticFeedback.xxx()`：一来省得每个地方
/// 都要记住哪种操作配哪一档，二来没有震动马达的设备会静默降级。
///
/// 原则：只在「用户这一下真的改变了什么」时震。点击一个没有响应的地方也震，
/// 是在用触感掩盖卡顿。
///
/// 另一个原则：这一层的任何失败都不许冒泡 —— 震动是锦上添花，绝不能因为它
/// 让一次保存或一次删除中途断掉。
Future<void> tapFeedback() => _fire(HapticFeedback.lightImpact);

/// 状态翻转了：开关、选中、日期落定。
Future<void> toggleFeedback() => _fire(HapticFeedback.selectionClick);

/// 要发生一件有点分量的事：长按起了菜单、即将删除。
Future<void> warningFeedback() => _fire(HapticFeedback.mediumImpact);

/// 落盘成功：保存、导入、导出。
Future<void> successFeedback() => _fire(HapticFeedback.lightImpact);

Future<void> _fire(Future<void> Function() call) async {
  try {
    await call();
  } on PlatformException {
    // 设备没有震动马达 / 系统里关掉了触感反馈，两种情况都当无事发生
  }
}
