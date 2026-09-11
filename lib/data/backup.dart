/// 备份与恢复。
///
/// 格式是一个 zip：
///
/// ```
/// time-backup-20260911-1430.zip
/// ├── manifest.json                     { schema, app, version, exportedAt, count, dailies: [...] }
/// └── covers/c_1757123456789_4f2a.jpg   ← 文件名原样，和 coverKey 里存的相对路径对得上
/// ```
///
/// 两个刻意的设计：
///
/// 1. **记录本体是 JSON，不是数据库文件**。直接拷 `db.daily` 省事得多，但那样备份
///    就和 SQLite 的二进制格式绑死了 —— 换 schema 版本、换个实现都读不了，用户
///    手里那个 zip 就废了。JSON 里字段名和列名逐字一致，出问题时用户自己也能打开看。
/// 2. **不写 id**。恢复时交给 SQLite 重新分配：引用 id 的地方（通知 id、Hero tag）
///    全都是每次从列表重新算的，没有一处把旧 id 存在别的地方。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:daily/constants.dart';
import 'package:daily/data/cover_palette.dart';
import 'package:daily/data/covers.dart';
import 'package:daily/data/daily_repository.dart';
import 'package:daily/data/db.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/utils/external_flow.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// 备份格式的版本号。换 schema 就加一，让老 App 能干净地拒绝新文件。
const int kBackupSchema = 1;

/// 记录本体在 zip 里的位置。
const String kBackupManifest = 'manifest.json';

/// 允许读取的备份文件上限。压进去的是手机照片，几十条也就几十 MB ——
/// 这个数字挡的是「选错文件」，不是限制正常使用。
const int kMaxBackupBytes = 512 * 1024 * 1024;

/// 备份文件读不了。[message] 直接可以给用户看。
class BackupFormatException implements Exception {
  final String message;

  const BackupFormatException(this.message);

  @override
  String toString() => message;
}

/// 一次导出 / 恢复的结果。
class BackupResult {
  final bool ok;

  /// 用户在系统选择器或确认框里放弃了。不是错误，界面不弹任何东西。
  final bool cancelled;

  final String message;

  const BackupResult.ok(this.message) : ok = true, cancelled = false;

  const BackupResult.fail(this.message) : ok = false, cancelled = false;

  const BackupResult.cancelled() : ok = true, cancelled = true, message = '';
}

/// 落进 manifest 的一条记录 = 一行插入语句的值，字段名和列名逐字一致，不带 id。
///
/// 带上 `imageUrl` 是刻意的：这一列虽然不再写，但它是 v1 时代「照片原本在哪」的
/// 唯一记录，恢复时原样还回去，历史不丢。
Map<String, Object?> dailyToBackup(Daily d) => {
      'title': d.title,
      'headText': d.headText,
      'targetDay': d.targetDay,
      'imageUrl': d.imageUrl,
      'remark': d.remark,
      'coverKey': d.coverKey,
      'repeatRule': d.repeatRule.name,
      'remindEnabled': d.remindEnabled ? 1 : 0,
      'remindDaysBefore': d.remindDaysBefore,
      'remindHour': d.remindHour,
      'remindMinute': d.remindMinute,
    };

/// `covers/xxx.jpg` 形态的路径清洗，两个方向共用同一段规则。
///
/// zip 的 entry 名一律用 `/`，所以这里按 `/` 手拆而不走 `package:path` ——
/// 后者的分隔符跟随平台，在 Windows 上跑测试时会给出不一样的结果。
String? _cleanCoverPath(String path) {
  final parts = path.split('/');
  if (parts.length != 2 || parts[0] != kCoversDir) return null;
  final name = parts[1];
  // `..` / `.` 一律不要：备份是外来数据，放过它就是把文档目录里的任意文件交出去
  if (name.isEmpty || name == '.' || name == '..') return null;
  return path;
}

/// `f:covers/c_123_4f2a.jpg` → `covers/c_123_4f2a.jpg`。
///
/// 渐变封面、空值、以及 v1 那条线留下的绝对路径（存在 `imageUrl` 里）都返回 null ——
/// 别的设备上的绝对路径没有意义，也不能塞进 zip。
String? photoEntryName(String? coverKey) {
  if (coverKey == null || !coverKey.startsWith(kPhotoPrefix)) return null;
  return _cleanCoverPath(coverKey.substring(kPhotoPrefix.length));
}

/// zip 里的一条 entry 名 → 它能对上哪个 `coverKey`；不是照片则返回 null。
String? coverKeyForEntry(String entry) {
  final clean = _cleanCoverPath(entry);
  return clean == null ? null : '$kPhotoPrefix$clean';
}

/// 解出来的「备份目录页」：有哪些记录、带了哪些照片。
class BackupManifest {
  final List<Daily> dailies;

  /// zip 里实际带着的照片，元素形如 `covers/xxx.jpg`。
  final Set<String> photos;

  final String appVersion;
  final DateTime? exportedAt;

  const BackupManifest({
    required this.dailies,
    required this.photos,
    required this.appVersion,
    required this.exportedAt,
  });
}

/// 把 JSON 里的一条记录规整成 `Daily.fromMap` 认的形态。
///
/// 备份文件是这个 App 唯一会读进来的外来数据，边界检查就该只在这一处做：
/// 用户手改过、或者从旧版备份升上来，都不该让一条记录把整次恢复带崩。
Map<String, Object?> _normalize(Map<String, Object?> raw) {
  String str(String key) {
    final v = raw[key];
    return v is String ? v : '';
  }

  int count(String key, int fallback) {
    final v = raw[key];
    return v is num ? v.toInt() : fallback;
  }

  return {
    'title': str('title'),
    'headText': str('headText'),
    'targetDay': str('targetDay'),
    'imageUrl': raw['imageUrl'] is String ? raw['imageUrl'] : null,
    'remark': str('remark'),
    'coverKey': raw['coverKey'] is String ? raw['coverKey'] : null,
    'repeatRule': str('repeatRule'),
    'remindEnabled': raw['remindEnabled'] == true || raw['remindEnabled'] == 1 ? 1 : 0,
    'remindDaysBefore': count('remindDaysBefore', 0),
    'remindHour': count('remindHour', kDefaultRemindHour),
    'remindMinute': count('remindMinute', 0),
  };
}

/// 解开 zip 并校验 manifest。
///
/// 认不出的 schema **直接拒绝**，不做「尽量读一点」的兼容 —— 备份是用户唯一的
/// 一份数据，读一半比读不了更糟，他会以为恢复成功了。
BackupManifest parseBackup(List<int> bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const BackupFormatException('这不是一个有效的备份文件');
  }

  final file = archive.findFile(kBackupManifest);
  if (file == null) {
    throw const BackupFormatException('备份文件里没有 $kBackupManifest');
  }

  final Object? json;
  try {
    json = jsonDecode(utf8.decode(file.readBytes() ?? const []));
  } catch (_) {
    throw const BackupFormatException('$kBackupManifest 读不出来，文件可能已经损坏');
  }
  if (json is! Map) {
    throw const BackupFormatException('$kBackupManifest 的内容不是一份记录清单');
  }
  if (json['schema'] != kBackupSchema) {
    throw BackupFormatException(
      '这份备份的格式版本（${json['schema'] ?? '未知'}）这个版本的 App 读不了',
    );
  }

  final raw = json['dailies'];
  if (raw is! List) {
    throw const BackupFormatException('备份里没有记录列表');
  }
  final dailies = <Daily>[
    for (final e in raw)
      if (e is Map) Daily.fromMap(_normalize(e.cast<String, Object?>())),
  ];

  return BackupManifest(
    dailies: dailies,
    photos: {
      for (final f in archive.files)
        if (!f.isDirectory && coverKeyForEntry(f.name) != null) f.name,
    },
    appVersion: json['version'] is String ? json['version'] as String : '',
    exportedAt:
        json['exportedAt'] is String ? DateTime.tryParse(json['exportedAt'] as String) : null,
  );
}

/// `time-backup-20260911-1430.zip` —— 带时间戳，导过几次一目了然。
String backupFileName(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'time-backup-${t.year}${two(t.month)}${two(t.day)}'
      '-${two(t.hour)}${two(t.minute)}.zip';
}

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  /// 打包全部记录并交给系统选择器保存。
  Future<BackupResult> export() async {
    final List<Daily> rows;
    final Uint8List bytes;
    try {
      rows = await DailyRepository.instance.queryAll();
      bytes = await _pack(rows);
    } catch (e) {
      return BackupResult.fail('打包失败：$e');
    }

    final Uri? target;
    try {
      // 必须走 bytes：Android 上 `saveFile` 是 SAF，由插件自己写文件，
      // 它返回的 content:// 路径不能拿 dart:io 去写
      target = await ExternalFlow.run(
        () => FilePicker.saveFile(
          fileName: backupFileName(DateTime.now()),
          bytes: bytes,
          mimeType: 'application/zip',
          dialogTitle: '导出备份',
        ),
      );
    } catch (e) {
      return BackupResult.fail('保存失败：$e');
    }
    if (target == null) return const BackupResult.cancelled();

    final photos = (await _packedPhotos(rows)).length;
    return BackupResult.ok('已导出 ${rows.length} 条记录、$photos 张照片');
  }

  /// 选文件 → 校验 → [confirm] 里问用户 → 覆盖。
  ///
  /// 确认框由调用方注入，这样「什么时候问用户」和「问完做什么」的顺序留在这一处，
  /// 中途没有半个状态漏给界面去拼。
  Future<BackupResult> restore({
    required Future<bool> Function(int existing, int incoming) confirm,
  }) async {
    final BackupPrep? prep;
    try {
      prep = await _choose();
    } on BackupFormatException catch (e) {
      return BackupResult.fail(e.message);
    } catch (e) {
      return BackupResult.fail('打开文件选择器失败：$e');
    }
    // 用户没选文件
    if (prep == null) return const BackupResult.cancelled();

    final db = await Db.instance.open();
    final existing = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $kTableName'),
        ) ??
        0;
    if (!await confirm(existing, prep.manifest.dailies.length)) {
      return const BackupResult.cancelled();
    }

    return _apply(prep);
  }

  /// 让用户选一个备份文件并校验。返回 null 表示他取消了。
  Future<BackupPrep?> _choose() async {
    final picked = await ExternalFlow.run(
      () => FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: '选择备份文件',
      ),
    );
    if (picked == null) return null;
    if (await picked.length() > kMaxBackupBytes) {
      throw const BackupFormatException('这个文件太大了，不像是一份备份');
    }
    final bytes = await picked.readAsBytes();
    return BackupPrep(bytes, parseBackup(bytes));
  }

  /// 真正动手：先把照片落地，再换数据库，最后才收拾旧照片。
  ///
  /// 顺序是刻意的 —— 任何一步失败，用户损失的都不是照片。反过来先清空的话，
  /// 中途出错就是「记录没了、照片也没了」。
  Future<BackupResult> _apply(BackupPrep prep) async {
    final manifest = prep.manifest;
    final wanted = <String, String>{}; // 照片 entry 名 → coverKey
    for (final d in manifest.dailies) {
      final entry = photoEntryName(d.coverKey);
      if (entry != null) wanted[entry] = d.coverKey!;
    }
    final missing = wanted.keys.where((k) => !manifest.photos.contains(k)).length;

    try {
      final photos = await _restorePhotos(prep);
      await _replaceRows(manifest.dailies);
      // 新数据已经稳了，再清掉上一批没人引用的照片。24 小时内的会留到下次冷启动
      await Covers.instance.sweepOrphans(wanted.values.toSet());
      await DailyRepository.instance.refresh();
      // refresh 之后提醒会跟着重排：通知服务监听的就是这份列表

      final tail = missing == 0 ? '' : '，$missing 张照片不在备份里，已用渐变封面代替';
      return BackupResult.ok(
        '已恢复 ${manifest.dailies.length} 条记录、$photos 张照片$tail',
      );
    } catch (e) {
      return BackupResult.fail('恢复失败：$e');
    }
  }

  Future<Uint8List> _pack(List<Daily> rows) async {
    final archive = Archive();
    archive.addFile(ArchiveFile.string(
      kBackupManifest,
      const JsonEncoder.withIndent('  ').convert({
        'schema': kBackupSchema,
        'app': kAppName,
        'version': kAppVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'count': rows.length,
        'dailies': [for (final d in rows) dailyToBackup(d)],
      }),
    ));

    for (final entry in (await _packedPhotos(rows)).entries) {
      archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// 收集所有能读到的封面照片：`covers/xxx.jpg` → 字节。
  ///
  /// 读不到的照片直接跳过 —— 记录照备份，恢复出来那条会是渐变封面，
  /// 总好过因为一张图丢了整次导出。
  Future<Map<String, Uint8List>> _packedPhotos(List<Daily> rows) async {
    final out = <String, Uint8List>{};
    for (final d in rows) {
      final entry = photoEntryName(d.coverKey);
      if (entry == null) continue;
      final abs = Covers.instance.locate(d.coverKey!);
      if (abs == null) continue;
      out[entry] = await File(abs).readAsBytes();
    }
    return out;
  }

  /// 把 zip 里的照片解到临时目录，全部成功后再按原名搬进 `covers/`。
  ///
  /// 分两步是为了「没解完就不动现有照片」：zip 中间有一条坏数据时，异常抛在
  /// 临时目录那一步，`covers/` 和数据库都还是恢复前的样子。
  Future<int> _restorePhotos(BackupPrep prep) async {
    final temp = await Directory(
      p.join((await getTemporaryDirectory()).path,
          'time-restore-${DateTime.now().millisecondsSinceEpoch}'),
    ).create(recursive: true);
    try {
      final landed = <File>[];
      for (final entry in ZipDecoder().decodeBytes(prep.bytes).files) {
        if (entry.isDirectory) continue;
        final key = coverKeyForEntry(entry.name);
        if (key == null) continue;
        final bytes = entry.readBytes();
        if (bytes == null) continue;
        final file = File(p.join(temp.path, p.basename(entry.name)));
        await file.writeAsBytes(bytes, flush: true);
        landed.add(file);
      }
      for (final file in landed) {
        await Covers.instance.adopt(p.basename(file.path), file.path);
      }
      return landed.length;
    } finally {
      if (temp.existsSync()) await temp.delete(recursive: true);
    }
  }

  /// 换数据库。一个事务里删干净再插回去：中途任何一条出错都整体回滚，
  /// 不会出现「旧的清了、新的只进了一半」。
  Future<void> _replaceRows(List<Daily> dailies) async {
    final db = await Db.instance.open();
    await db.transaction((txn) async {
      await txn.delete(kTableName);
      for (final d in dailies) {
        await txn.insert(kTableName, dailyToBackup(d));
      }
    });
  }
}

/// 校验通过、等用户点头的一次恢复。
class BackupPrep {
  final List<int> bytes;
  final BackupManifest manifest;

  const BackupPrep(this.bytes, this.manifest);
}
