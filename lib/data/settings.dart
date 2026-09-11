import 'dart:convert';
import 'dart:io';

import 'package:daily/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 全 App 的设置，落在文档目录下的一个 `settings.json` 里。
///
/// 不引 shared_preferences：为了一个布尔值带一个原生插件不划算，而这边已经有
/// `path_provider` 和 `lib/data/covers.dart` 那套文件式存储的先例，沿用同一套写法。
class Settings {
  Settings._();

  static final Settings instance = Settings._();

  /// 深色模式。默认亮色 —— 2020 年那版的样子才是 App 的本色，
  /// 而且暗色不跟系统走（启动图无法预知系统主题，跟系统会闪）。
  final ValueNotifier<bool> darkMode = ValueNotifier(false);

  /// 通知栏常驻倒计时。**默认关** —— 一条划不掉的常驻通知打扰感很强，
  /// 「想要的人自己开」比「不想要的人自己关」体面。
  final ValueNotifier<bool> ongoingNotification = ValueNotifier(false);

  /// 隐私锁。默认关。
  ///
  /// 说清楚它是什么：进 App 前先让系统验一下指纹/锁屏密码，挡住的是
  /// 「别人拿起你手机随手一翻」。**不是加密** —— 数据库和照片都是明文，
  /// 连上电脑照样读得到（README 里也是这么写的）。
  final ValueNotifier<bool> lockEnabled = ValueNotifier(false);

  File? _file;

  Future<void> load() async {
    final root = await getApplicationDocumentsDirectory();
    final file = File(p.join(root.path, kSettingsFileName));
    _file = file;
    if (!file.existsSync()) return;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return;
      darkMode.value = json['darkMode'] == true;
      ongoingNotification.value = json['ongoingNotification'] == true;
      lockEnabled.value = json['lockEnabled'] == true;
    } catch (_) {
      // 设置文件读坏了不该拦住启动（写到一半被杀就会这样）。
      // 退回默认值，下次保存时自动修好。
    }
  }

  Future<void> setDarkMode(bool value) {
    if (darkMode.value == value) return Future.value();
    darkMode.value = value;
    return _write();
  }

  Future<void> setOngoingNotification(bool value) {
    if (ongoingNotification.value == value) return Future.value();
    ongoingNotification.value = value;
    return _write();
  }

  Future<void> setLockEnabled(bool value) {
    if (lockEnabled.value == value) return Future.value();
    lockEnabled.value = value;
    return _write();
  }

  /// 每次都整份重写。键少，合并的成本比「记得改 load 和 save 两处」低。
  Future<void> _write() async {
    final file = _file;
    if (file == null) return;
    await file.writeAsString(
      jsonEncode({
        'darkMode': darkMode.value,
        'ongoingNotification': ongoingNotification.value,
        'lockEnabled': lockEnabled.value,
      }),
      flush: true,
    );
  }
}
