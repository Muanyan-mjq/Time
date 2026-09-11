import 'dart:io';

import 'package:daily/data/db.dart';
import 'package:daily/model/cover.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/model/daily_group.dart';
import 'package:daily/model/repeat_rule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 历代的建表语句，都从当时的代码里逐字抄来。
///
/// 故意不用 `kCreateTableSql` —— 迁移必须能对付真实的老库，而不是「我们现在
/// 以为的老库」。少抄一个空格都会让这些测试失去意义。
const String _ddlV1 = '''
Create Table daily_cache(
  id integer primary key autoincrement,
  title text,
  headText text,
  targetDay text,
  imageUrl text,
  remark text
)''';

const String _ddlV2 = '''
Create Table daily_cache(
  id integer primary key autoincrement,
  title text,
  headText text,
  targetDay text,
  imageUrl text,
  remark text,
  coverKey text
)''';

const String _ddlV3 = '''
Create Table daily_cache(
  id integer primary key autoincrement,
  title text,
  headText text,
  targetDay text,
  imageUrl text,
  remark text,
  coverKey text,
  repeatRule text
)''';

/// 迁移完成后应当有的列，顺序就是各次 `ALTER TABLE ADD COLUMN` 的追加顺序。
const List<String> _v4Columns = [
  'id',
  'title',
  'headText',
  'targetDay',
  'imageUrl',
  'remark',
  'coverKey',
  'repeatRule',
  'remindEnabled',
  'remindDaysBefore',
  'remindHour',
  'remindMinute',
];

/// v1 那三条老数据，覆盖「失效的本地图 / 网络图 / 空日期」三种情况。
const List<Map<String, Object?>> _legacyRows = [
  {
    'title': '失效的本地图',
    'headText': '家人',
    'targetDay': '2019-05-08',
    'imageUrl': '/data/user/0/com.example.daily/cache/gone.jpg',
    'remark': '老照片在应用私有缓存里，早被系统清了',
  },
  {
    'title': '网络图',
    'headText': '朋友',
    'targetDay': '2020-09-10',
    'imageUrl': 'https://cdn.xieyezi.com/daily_friend.jpg',
    'remark': 'CDN 已经整个没了',
  },
  {
    'title': '空日期',
    'headText': '学习',
    'targetDay': '',
    'imageUrl': '',
    'remark': '',
  },
];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('daily_migration');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// 用某一代的建表语句造一个老库。
  ///
  /// 用 `databaseFactory.openDatabase(version: n)` 而不是 App 的 openDatabase：
  /// 这样连 `onCreate` 都是那一代的，跟真机上留下的老库一致。
  Future<String> makeLegacyDb({
    required int version,
    required String ddl,
    List<Map<String, Object?>> rows = const [],
  }) async {
    final path = p.join(tmp.path, kDbFileName);
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, _) => db.execute(ddl),
      ),
    );
    for (final row in rows) {
      await db.insert(kTableName, row);
    }
    await db.close();
    return path;
  }

  Future<Database> openWithApp(DatabaseFactory factory, String path, {int version = 4}) {
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: createSchema,
        onUpgrade: migrateSchema,
      ),
    );
  }

  Future<List<String>> columnsOf(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info($kTableName)');
    return [for (final c in cols) c['name'] as String];
  }

  Future<int> userVersionOf(Database db) async {
    final rows = await db.rawQuery('PRAGMA user_version');
    return rows.first['user_version'] as int;
  }

  test('v1 → v4：表变 12 列、user_version 变 4、imageUrl 一字未改', () async {
    final path = await makeLegacyDb(version: 1, ddl: _ddlV1, rows: _legacyRows);

    final before = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1, onCreate: (_, _) {}),
    );
    final v1Rows = await before.query(kTableName, orderBy: 'id');
    await before.close();
    expect(v1Rows.length, 3);

    final db = await openWithApp(databaseFactory, path);

    expect(await columnsOf(db), _v4Columns);
    expect(await userVersionOf(db), 4);

    final after = await db.query(kTableName, orderBy: 'id');
    expect(after.length, 3);
    // imageUrl 一字未改
    expect(
      [for (final r in after) r['imageUrl']],
      [for (final r in v1Rows) r['imageUrl']],
    );
    // 三列新列全是 null，等着走回退逻辑
    expect(after.every((r) => r['coverKey'] == null), isTrue);
    expect(after.every((r) => r['repeatRule'] == null), isTrue);
    expect(after.every((r) => r['remindEnabled'] == null), isTrue);

    await db.close();
  });

  test('v2 → v4：老 coverKey 原样留着，只补后面两代新列', () async {
    final path = await makeLegacyDb(
      version: 2,
      ddl: _ddlV2,
      rows: [
        {
          'title': '用户照片',
          'headText': '家人',
          'targetDay': '2021-03-04',
          'imageUrl': '/data/user/0/com.muanyan.daily/files/covers/c_1.jpg',
          'remark': '',
          'coverKey': 'f:covers/c_1.jpg',
        },
        {
          'title': '渐变',
          'headText': '朋友',
          'targetDay': '2022-06-07',
          'imageUrl': '',
          'remark': '',
          'coverKey': 'g:2',
        },
      ],
    );

    final db = await openWithApp(databaseFactory, path);
    expect(await columnsOf(db), _v4Columns);
    expect(await userVersionOf(db), 4);

    final rows = await db.query(kTableName, orderBy: 'id');
    expect([for (final r in rows) r['coverKey']], ['f:covers/c_1.jpg', 'g:2']);
    expect(rows.every((r) => r['repeatRule'] == null), isTrue);
    expect(rows.every((r) => r['remindEnabled'] == null), isTrue);

    await db.close();
  });

  test('v3 → v4：repeatRule 原样留着，只补 4 列提醒字段', () async {
    final path = await makeLegacyDb(
      version: 3,
      ddl: _ddlV3,
      rows: [
        {
          'title': '结婚纪念日',
          'headText': '恋爱',
          'targetDay': '2018-05-08',
          'imageUrl': '',
          'remark': '',
          'coverKey': 'g:0',
          'repeatRule': 'yearly',
        },
      ],
    );

    final db = await openWithApp(databaseFactory, path);
    expect(await columnsOf(db), _v4Columns);
    expect(await userVersionOf(db), 4);

    final row = (await db.query(kTableName)).single;
    expect(row['repeatRule'], 'yearly');
    expect(row['coverKey'], 'g:0');
    // 提醒列是 null，读出来应该退回「关着 + 默认 9:00」
    final daily = Daily.fromMap(row);
    expect(daily.repeatRule, RepeatRule.yearly);
    expect(daily.remindEnabled, isFalse);
    expect(daily.remindHour, kDefaultRemindHour);
    expect(daily.remindMinute, 0);

    await db.close();
  });

  test('v1 的三条老数据都不崩：两条回退到渐变，空日期那条排在最后', () async {
    final path = await makeLegacyDb(version: 1, ddl: _ddlV1, rows: _legacyRows);
    final db = await openWithApp(databaseFactory, path);
    final rows = [for (final r in await db.query(kTableName, orderBy: 'id')) Daily.fromMap(r)];
    await db.close();

    // 前两条：路径已失效 / http 开头，都当坏的，渐变兜底
    for (final d in rows.take(2)) {
      final cover = resolveCover(
        coverKey: d.coverKey,
        imageUrl: d.imageUrl,
        locate: (_) => null,
      );
      expect(cover, isA<GradientCover>(), reason: d.title);
    }

    final groups = groupDailies(rows);
    expect(groups.map((g) => g.name), [kGroupFuture, kGroupPast]);

    final future = groups.first;
    expect(future.items.length, 1);
    expect(future.items.single.daily.title, '空日期');
    expect(future.items.single.signedDays, isNull);

    // 两条有日期的都在已过去组，且最近的在最上面
    expect(groups[1].items.length, 2);
    expect(groups[1].items.first.daily.title, '网络图');
    expect(groups[1].items.last.daily.title, '失效的本地图');
  });

  test('全新安装：onCreate 直接建出 12 列，能写入所有新字段', () async {
    // 建表语句落后于 kDbVersion 的话，新装的 App 第一次写入就会撞
    // "no such column: coverKey" / "no such column: repeatRule"
    final path = p.join(tmp.path, 'fresh.daily');
    final db = await openWithApp(databaseFactory, path);

    expect(await columnsOf(db), _v4Columns);
    expect(await userVersionOf(db), 4);

    final id = await db.insert(kTableName, {
      'title': '新记录',
      'headText': '恋爱',
      'targetDay': '2026-09-10',
      'remark': '',
      'coverKey': 'f:covers/c_1_4f2a.jpg',
      'repeatRule': 'yearly',
      'remindEnabled': 1,
      'remindDaysBefore': 3,
      'remindHour': 20,
      'remindMinute': 30,
    });
    final row = (await db.query(kTableName, where: 'id = ?', whereArgs: [id])).single;
    expect(row['coverKey'], 'f:covers/c_1_4f2a.jpg');
    expect(row['imageUrl'], isNull);

    final daily = Daily.fromMap(row);
    expect(daily.repeatRule, RepeatRule.yearly);
    expect(daily.remindEnabled, isTrue);
    expect(daily.remindDaysBefore, 3);
    expect(daily.remindHour, 20);
    expect(daily.remindMinute, 30);

    await db.close();
  });

  test('migrateSchema 在 oldVersion >= 4 时什么都不做', () async {
    // 再 ALTER 一次会撞 duplicate column name
    final path = p.join(tmp.path, 'fresh2.daily');
    final db = await openWithApp(databaseFactory, path);
    await migrateSchema(db, 4, 4);
    expect((await columnsOf(db)).length, 12);
    await db.close();
  });
}
