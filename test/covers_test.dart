import 'dart:io';

import 'package:daily/constants.dart';
import 'package:daily/data/covers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('coverStoragePath', () {
    test('剥掉落库用的 f: 前缀', () {
      expect(coverStoragePath('f:covers/c_1.jpg'), 'covers/c_1.jpg');
    });

    test('已经是相对路径的原样返回', () {
      expect(coverStoragePath('covers/c_1.jpg'), 'covers/c_1.jpg');
    });

    test('v1 遗留的绝对路径不动', () {
      expect(
        coverStoragePath('/data/user/0/com.muanyan.daily/files/a.jpg'),
        '/data/user/0/com.muanyan.daily/files/a.jpg',
      );
    });
  });

  group('locate / remove', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('time_covers_test');
      await Directory(p.join(root.path, kCoversDir)).create(recursive: true);
      Covers.instance.debugUseRoot(root);
    });

    tearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });

    test('带前缀的落库原文也能定位到文件', () {
      final f = File(p.join(root.path, kCoversDir, 'c_1.jpg'))
        ..writeAsBytesSync([1, 2, 3]);

      // 落库原文里的分隔符是 `/`，Windows 上拼出来是混着来的，比归一化后的值
      String? locate(String stored) {
        final abs = Covers.instance.locate(stored);
        return abs == null ? null : p.normalize(abs);
      }

      expect(locate('f:covers/c_1.jpg'), p.normalize(f.path));
      expect(locate('covers/c_1.jpg'), p.normalize(f.path));
    });

    test('文件不存在时返回 null，不抛异常', () {
      expect(Covers.instance.locate('f:covers/nope.jpg'), isNull);
      expect(Covers.instance.locate(''), isNull);
    });

    test('remove 收落库原文，真的把文件删掉', () async {
      final f = File(p.join(root.path, kCoversDir, 'c_2.jpg'))
        ..writeAsBytesSync([1, 2, 3]);

      await Covers.instance.remove('f:covers/c_2.jpg');

      expect(f.existsSync(), isFalse);
    });
  });
}
