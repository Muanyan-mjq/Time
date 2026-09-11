import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:daily/constants.dart';
import 'package:daily/data/backup.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/model/repeat_rule.dart';
import 'package:flutter_test/flutter_test.dart';

/// 按 `data/backup.dart` 的格式拼一个 zip，用来喂给 `parseBackup`。
///
/// 刻意在测试里自己拼而不是调导出：这样「导出写出来的东西」和「导出应该写出的
/// 东西」是两个独立的陈述，格式漂了能被看见。
Uint8List zipOf({
  Object? manifest = _sentinel,
  Map<String, List<int>> photos = const {},
}) {
  final archive = Archive();
  if (manifest != _sentinel) {
    archive.addFile(ArchiveFile.string(
      kBackupManifest,
      manifest is String ? manifest : jsonEncode(manifest),
    ));
  }
  photos.forEach((name, bytes) => archive.addFile(ArchiveFile.bytes(name, bytes)));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

const Object _sentinel = Object();

Map<String, Object?> manifestOf({
  Object? schema = kBackupSchema,
  List<Object?> dailies = const [],
}) =>
    {
      'schema': schema,
      'app': kAppName,
      'version': kAppVersion,
      'exportedAt': '2026-09-11T14:30:00.000',
      'count': dailies.length,
      'dailies': dailies,
    };

/// 一条所有列都填满的记录 —— round trip 测试要用它证明「一个字段都没丢」。
const Daily fullDaily = Daily(
  id: 7,
  title: '结婚纪念日',
  headText: '余生请多指教',
  targetDay: '1998-05-08',
  imageUrl: '/storage/emulated/0/DCIM/old.jpg',
  remark: '那天的雨很大',
  coverKey: 'f:covers/c_1757123456789_4f2a.jpg',
  repeatRule: RepeatRule.yearly,
  remindEnabled: true,
  remindDaysBefore: 3,
  remindHour: 20,
  remindMinute: 30,
);

void main() {
  group('photoEntryName', () {
    test('照片封面映射成 zip 里的 entry 名', () {
      expect(photoEntryName('f:covers/c_1757123456789_4f2a.jpg'),
          'covers/c_1757123456789_4f2a.jpg');
    });

    test('渐变封面没有对应的照片', () {
      expect(photoEntryName('g:3'), isNull);
    });

    test('空值不参与备份', () {
      expect(photoEntryName(null), isNull);
      expect(photoEntryName(''), isNull);
    });

    test('v1 遗留的绝对路径不进 zip', () {
      // imageUrl 一定是别的设备/别的时刻的绝对路径，塞进备份毫无意义
      expect(photoEntryName('f:/storage/emulated/0/DCIM/a.jpg'), isNull);
      expect(photoEntryName('f:/data/user/0/com.muanyan.daily/files/a.jpg'), isNull);
    });

    test('越界的相对路径一律拒绝', () {
      // 备份是外来数据：放过 `..` 就是把自己文档目录里的任意文件交出去
      expect(photoEntryName('f:covers/../../settings.json'), isNull);
      expect(photoEntryName('f:covers/..'), isNull);
      expect(photoEntryName('f:covers/sub/a.jpg'), isNull);
      expect(photoEntryName('f:other/a.jpg'), isNull);
      expect(photoEntryName('f:covers\\a.jpg'), isNull);
    });
  });

  group('coverKeyForEntry', () {
    test('entry 名还原成 coverKey', () {
      expect(coverKeyForEntry('covers/c_1_4f2a.jpg'), 'f:covers/c_1_4f2a.jpg');
    });

    test('不是 covers 下的东西都不是照片', () {
      expect(coverKeyForEntry(kBackupManifest), isNull);
      expect(coverKeyForEntry('covers/'), isNull);
      expect(coverKeyForEntry('covers'), isNull);
      expect(coverKeyForEntry('covers/../../evil'), isNull);
    });
  });

  group('dailyToBackup', () {
    test('字段名和数据库列名逐字一致，只是不带 id', () {
      final map = dailyToBackup(fullDaily);
      expect(map.keys, {
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
      });
      expect(map['repeatRule'], 'yearly');
      expect(map['remindEnabled'], 1);
    });

    test('没开提醒写 0 而不是 false', () {
      const d = Daily(title: 'a', headText: 'b', targetDay: '2020-01-01', remark: 'c');
      expect(dailyToBackup(d)['remindEnabled'], 0);
    });
  });

  group('parseBackup 读得进来', () {
    test('一条记录的所有列一个都不丢', () {
      final parsed = parseBackup(zipOf(manifest: manifestOf(dailies: [dailyToBackup(fullDaily)])));

      expect(parsed.dailies, hasLength(1));
      final got = parsed.dailies.single;
      expect(got.title, fullDaily.title);
      expect(got.headText, fullDaily.headText);
      expect(got.targetDay, fullDaily.targetDay);
      expect(got.imageUrl, fullDaily.imageUrl);
      expect(got.remark, fullDaily.remark);
      expect(got.coverKey, fullDaily.coverKey);
      expect(got.repeatRule, fullDaily.repeatRule);
      expect(got.remindEnabled, fullDaily.remindEnabled);
      expect(got.remindDaysBefore, fullDaily.remindDaysBefore);
      expect(got.remindHour, fullDaily.remindHour);
      expect(got.remindMinute, fullDaily.remindMinute);
      // id 不备份，交回给 SQLite 重新分配
      expect(got.id, 0);
    });

    test('列出 zip 里带了哪些照片', () {
      final parsed = parseBackup(zipOf(
        manifest: manifestOf(dailies: [dailyToBackup(fullDaily)]),
        photos: {
          'covers/c_1757123456789_4f2a.jpg': [1, 2, 3],
          'covers/c_9_0001.jpg': [4, 5],
        },
      ));

      expect(parsed.photos, {
        'covers/c_1757123456789_4f2a.jpg',
        'covers/c_9_0001.jpg',
      });
    });

    test('照片字节能原样取出来', () {
      final bytes = zipOf(
        manifest: manifestOf(),
        photos: {
          'covers/c_1_0001.jpg': [0, 255, 7, 42],
        },
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.findFile('covers/c_1_0001.jpg')!.readBytes(), [0, 255, 7, 42]);
    });

    test('导出时间能解析出来', () {
      final parsed = parseBackup(zipOf(manifest: manifestOf()));
      expect(parsed.exportedAt, DateTime(2026, 9, 11, 14, 30));
      expect(parsed.appVersion, kAppVersion);
    });

    test('空备份是合法的：恢复到一条都没有', () {
      expect(parseBackup(zipOf(manifest: manifestOf())).dailies, isEmpty);
    });

    test('用户手改过的记录按兜底值读，不炸整次恢复', () {
      final parsed = parseBackup(zipOf(manifest: manifestOf(dailies: [
        {
          'title': '只有标题',
          // 其余列缺失、数字写成字符串、开关写成 true
          'remindEnabled': true,
          'remindHour': '20',
          'repeatRule': 42,
        },
      ])));

      final got = parsed.dailies.single;
      expect(got.title, '只有标题');
      expect(got.headText, '');
      expect(got.targetDay, '');
      expect(got.coverKey, isNull);
      expect(got.repeatRule, RepeatRule.none);
      expect(got.remindEnabled, isTrue);
      // 写坏的数字退回默认值，而不是把 20 当成字符串硬用
      expect(got.remindHour, kDefaultRemindHour);
      expect(got.remindMinute, 0);
      // 日期解析不了的记录不崩，界面按「日期待补充」处理
      expect(got.date, isNull);
    });

    test('记录列表里混进非对象元素时跳过它', () {
      final parsed = parseBackup(zipOf(manifest: manifestOf(dailies: [
        'oops',
        42,
        dailyToBackup(fullDaily),
      ])));
      expect(parsed.dailies, hasLength(1));
    });
  });

  group('parseBackup 拒绝读不了的', () {
    test('不是 zip', () {
      expect(() => parseBackup([1, 2, 3, 4]), throwsA(isA<BackupFormatException>()));
    });

    test('zip 里没有 manifest', () {
      expect(
        () => parseBackup(zipOf(manifest: _sentinel)),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('manifest 不是 JSON', () {
      expect(
        () => parseBackup(zipOf(manifest: '这不是 json')),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('schema 认不出来就拒绝，不做「尽量读一点」', () {
      expect(
        () => parseBackup(zipOf(manifest: manifestOf(schema: 99))),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => parseBackup(zipOf(manifest: manifestOf(schema: null))),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('没有记录列表', () {
      expect(
        () => parseBackup(zipOf(manifest: {'schema': kBackupSchema, 'app': kAppName})),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('错误信息能直接给用户看', () {
      try {
        parseBackup(zipOf(manifest: manifestOf(schema: 99)));
        fail('应该抛异常');
      } on BackupFormatException catch (e) {
        expect(e.message, contains('99'));
        expect(e.toString(), e.message);
      }
    });
  });

  group('backupFileName', () {
    test('带时间戳，导过几次能按名字排序', () {
      expect(backupFileName(DateTime(2026, 9, 11, 14, 30)), 'time-backup-20260911-1430.zip');
      expect(backupFileName(DateTime(2026, 1, 2, 3, 4)), 'time-backup-20260102-0304.zip');
    });
  });
}
