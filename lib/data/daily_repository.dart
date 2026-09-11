import 'package:daily/data/db.dart';
import 'package:daily/model/daily.dart';
import 'package:flutter/foundation.dart';

/// 单例。老代码每个页面 `new` 一个 helper 再各自 `open()`，白白开好几条连接。
class DailyRepository {
  DailyRepository._();

  static final DailyRepository instance = DailyRepository._();

  /// 全量列表，界面监听它就行。
  ///
  /// 存在的理由是「谁来触发重读」这件事不能靠调用方自觉：新增、编辑、删除、
  /// 备份导入、通知点进来，每条路径都得记得手动刷新一次，迟早漏一个。
  /// 现在所有写操作都从这里走，写完自动刷新，界面只需要监听。
  final ValueNotifier<List<Daily>> items = ValueNotifier(const []);

  /// 不排序 —— 顺序由 `groupDailies` 在 Dart 里决定（见 model/daily_group.dart）。
  Future<List<Daily>> queryAll() async {
    final db = await Db.instance.open();
    final rows = await db.query(kTableName);
    return rows.map(Daily.fromMap).toList();
  }

  /// 重读全表并推给监听者。
  ///
  /// **不抛异常**：调用它的地方要么是「写已经成功了，只是顺手刷新一下」，
  /// 要么是「放掉首屏骨架」，这两种场景下异常逃出去都只会把好事变成坏事
  /// （误报保存失败、或者骨架永远收不掉）。失败只上报，列表保持上一次的值。
  Future<void> refresh() async {
    try {
      items.value = await queryAll();
    } catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'daily',
        context: ErrorDescription('重读纪念日列表'),
      ));
    }
  }

  Future<int> insert(Daily daily) async {
    final db = await Db.instance.open();
    final id = await db.insert(kTableName, daily.toInsertMap());
    await refresh();
    return id;
  }

  /// 返回是否真的改到了行。
  ///
  /// 老代码用 `ConflictAlgorithm.replace` 且在 id 匹配不到时静默返回，
  /// 于是「编辑成功」了却什么都没发生 —— 一次坏编辑还可能悄悄新建一行。
  Future<bool> update(Daily daily) async {
    final db = await Db.instance.open();
    final n = await db.update(
      kTableName,
      daily.toUpdateMap(),
      where: 'id = ?',
      whereArgs: [daily.id],
    );
    await refresh();
    return n == 1;
  }

  Future<bool> delete(int id) async {
    final db = await Db.instance.open();
    final n = await db.delete(kTableName, where: 'id = ?', whereArgs: [id]);
    await refresh();
    return n == 1;
  }
}
