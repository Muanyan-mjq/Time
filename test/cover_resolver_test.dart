import 'package:daily/data/cover_palette.dart';
import 'package:daily/model/cover.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假的磁盘：只有 [existing] 里的存储值算存在，原样返回当绝对路径。
String? Function(String) _locate(Set<String> existing) =>
    (stored) => existing.contains(stored) ? stored : null;

void main() {
  group('resolveCover', () {
    test('g: 解析成对应下标', () {
      final c = resolveCover(coverKey: 'g:3', imageUrl: null, locate: _locate({}));
      expect(c, isA<GradientCover>());
      expect((c as GradientCover).index, 3);
    });

    test('f: 文件还在就显示照片', () {
      final c = resolveCover(
        coverKey: 'f:covers/a.jpg',
        imageUrl: null,
        locate: _locate({'covers/a.jpg'}),
      );
      expect(c, isA<PhotoCover>());
      expect((c as PhotoCover).path, 'covers/a.jpg');
    });

    test('f: 但文件被清掉了 → 渐变兜底，不崩', () {
      final c = resolveCover(
        coverKey: 'f:covers/gone.jpg',
        imageUrl: null,
        locate: _locate({'covers/other.jpg'}),
      );
      expect(c, isA<GradientCover>());
      expect((c as GradientCover).index, 0);
    });

    test('认不出的 coverKey 一律夹取到 0', () {
      for (final key in ['garbage', 'http://cdn.xieyezi.com/daily_love.jpg', 'x:1']) {
        final c = resolveCover(coverKey: key, imageUrl: null, locate: _locate({}));
        expect(c, isA<GradientCover>(), reason: key);
        expect((c as GradientCover).index, 0, reason: key);
      }
    });

    test('g: 后面的数字是空的或乱码时夹取到 0', () {
      for (final key in ['g:', 'g:abc']) {
        final c = resolveCover(coverKey: key, imageUrl: null, locate: _locate({}));
        expect((c as GradientCover).index, 0, reason: key);
      }
    });

    test('越界下标交给 gradientFor 夹取，不崩', () {
      final c = resolveCover(coverKey: 'g:99', imageUrl: null, locate: _locate({})) as GradientCover;
      expect(c.index, 99);
      expect(() => gradientFor(99), returnsNormally);
      expect(() => gradientFor(-5), returnsNormally);
      expect(() => gradientName(99), returnsNormally);
    });

    test('有 coverKey 时绝不去碰 imageUrl', () {
      expect(
        resolveCover(
          coverKey: 'g:0',
          imageUrl: '/somewhere/old.jpg',
          locate: (_) => throw StateError('不该被调用'),
        ),
        isA<GradientCover>(),
      );
    });

    group('老数据（没有 coverKey）', () {
      test('imageUrl 路径还活着就继续显示那张照片', () {
        final c = resolveCover(
          coverKey: null,
          imageUrl: '/data/user/0/com.example.daily/cache/old.jpg',
          locate: _locate({'/data/user/0/com.example.daily/cache/old.jpg'}),
        );
        expect(c, isA<PhotoCover>());
      });

      test('路径已失效 → 渐变兜底，不崩', () {
        // 老照片在应用私有缓存里，早被系统清了。迁移的职责是「不崩」，
        // 渐变兜底就是正确答案，这里不做「恢复照片」的虚假承诺。
        for (final legacy in [null, '', '/gone/x.jpg', '/data/user/10/cache/x.jpg']) {
          final c = resolveCover(coverKey: null, imageUrl: legacy, locate: _locate({}));
          expect(c, isA<GradientCover>(), reason: '$legacy');
        }
      });

      test('http 开头的旧值当坏的', () {
        // 只可能来自从没落库过的假欢迎卡
        final c = resolveCover(
          coverKey: null,
          imageUrl: 'https://cdn.xieyezi.com/daily_love.jpg',
          locate: _locate({'https://cdn.xieyezi.com/daily_love.jpg'}),
        );
        expect(c, isA<GradientCover>());
      });
    });
  });

  group('cover_palette', () {
    test('六套渐变对应原来的六个分类名', () {
      expect(
        [for (var i = 0; i < kCoverGradients.length; i++) gradientName(i)],
        ['恋爱', '家人', '朋友', '工作', '学习', '生日'],
      );
    });

    test('每套渐变两个色标', () {
      for (var i = 0; i < kCoverGradients.length; i++) {
        expect(gradientFor(i).colors.length, 2);
      }
    });
  });
}
