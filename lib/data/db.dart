import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 文件名、表名、列名一律保持 2020 年原样，迁移契约全靠它。
const String kDbFileName = 'db.daily';
const String kTableName = 'daily_cache';
const int kDbVersion = 4;

/// 当前版本（v4）的表结构，12 列。
///
/// 全新安装走 `onCreate` 时必须一次建出所有列 —— 建表语句停在旧版本的话，
/// 新装的 App 第一次写入就会撞上 "no such column: repeatRule"。
/// 这是 v1→v2 踩过的坑，v3、v4 都别再踩。老库升级走 [migrateSchema]。
const String kCreateTableSql = '''
Create Table $kTableName(
  id integer primary key autoincrement,
  title text,
  headText text,
  targetDay text,
  imageUrl text,
  remark text,
  coverKey text,
  repeatRule text,
  remindEnabled integer,
  remindDaysBefore integer,
  remindHour integer,
  remindMinute integer
)''';

Future<void> createSchema(Database db, int version) => db.execute(kCreateTableSql);

/// 逐级升级。每一段都只依赖「上一版长什么样」，所以从 v1 一路升到 v4、
/// 或者从 v3 只升一版，走的都是同一段代码。只在末尾加新分支，不改老分支。
Future<void> migrateSchema(Database db, int oldVersion, int newVersion) async {
  // v1 → v2：只加列，不搬数据、不清 imageUrl。
  //
  // imageUrl 保留为「只增不改」的历史存档列：迁移时并不知道那些老路径还能不能解析，
  // 清掉就永久失去了「照片原本在哪」的唯一记录。新数据不再写这一列。
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE $kTableName ADD COLUMN coverKey TEXT');
  }

  // v2 → v3：重复规则。老记录全是 null，读的时候当「不重复」。
  if (oldVersion < 3) {
    await db.execute('ALTER TABLE $kTableName ADD COLUMN repeatRule TEXT');
  }

  // v3 → v4：提醒。同样全是 null，读的时候按「没开提醒 + 早上 9 点」处理。
  if (oldVersion < 4) {
    await db.execute('ALTER TABLE $kTableName ADD COLUMN remindEnabled INTEGER');
    await db.execute('ALTER TABLE $kTableName ADD COLUMN remindDaysBefore INTEGER');
    await db.execute('ALTER TABLE $kTableName ADD COLUMN remindHour INTEGER');
    await db.execute('ALTER TABLE $kTableName ADD COLUMN remindMinute INTEGER');
  }
}

/// 单例 + memoized 连接。老代码每个页面 new 一个 helper 各自 open()，
/// 白白开了好几条连接。
class Db {
  Db._();

  static final Db instance = Db._();

  Future<Database>? _opening;

  Future<Database> open() => _opening ??= _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), kDbFileName);
    return openDatabase(
      path,
      version: kDbVersion,
      onCreate: createSchema,
      onUpgrade: migrateSchema,
    );
  }
}
