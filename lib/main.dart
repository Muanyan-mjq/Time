import 'dart:async';

import 'package:daily/app.dart';
import 'package:daily/data/covers.dart';
import 'package:daily/data/daily_repository.dart';
import 'package:daily/data/notifications.dart';
import 'package:daily/data/settings.dart';
import 'package:daily/data/shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 封面解析在 build 期是同步的，必须先把文档目录拿到手
  await Covers.instance.init();
  // 主题要在首帧就知道，否则冷启动会先亮一下再变暗
  await Settings.instance.load();
  // 列表也在首帧之前读完（几十条记录，几毫秒）：启动遮罩因此能完整播完一遍
  // 动画 —— 放到 runApp 之后的话，数据先到就会把动画截断。顺带首页也不会
  // 先闪一下骨架。
  await DailyRepository.instance.refresh();
  runApp(const DailyApp());

  // 这几件都不阻塞首帧，也互不牵连 —— 一件出问题不该让另一件也不做
  unawaited(NotificationService.instance.initialize());
  // 桌面图标长按进来的动作由首页兑现，但它得先挂上监听才接得到
  unawaited(AppShortcuts.instance.initialize());
  unawaited(Covers.instance.sweepOrphans({
    for (final d in DailyRepository.instance.items.value)
      if (d.coverKey != null) d.coverKey!,
  }));
}
