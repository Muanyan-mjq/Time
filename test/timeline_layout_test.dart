import 'package:daily/model/daily.dart';
import 'package:daily/model/repeat_rule.dart';
import 'package:daily/utils/date_util.dart';
import 'package:daily/utils/timeline_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// 时光轴的排版是纯函数，所以边界全在这儿钉住 —— 页面上只剩画。
///
/// 「今天」一律显式传进去，不依赖运行时时钟。
void main() {
  final today = DateTime.utc(2026, 9, 11);

  Daily at(String targetDay, {int id = 0, RepeatRule rule = RepeatRule.none}) => Daily(
        id: id,
        title: '记录 $id',
        headText: '',
        targetDay: targetDay,
        remark: '',
        repeatRule: rule,
      );

  /// 轴心在 0、最远端恰好落在 ±halfWidth。
  const half = 300.0;

  group('timelineLayout', () {
    test('只有一条未来的记录：它落在右半轴的最远端', () {
      final slots = timelineLayout(
        [at('2027-09-11', id: 1)],
        today: today,
        halfWidth: half,
      );
      expect(slots, hasLength(1));
      expect(slots.single.signedDays, 365);
      expect(slots.single.x, closeTo(half, 0.01), reason: '唯一一条就是最远那条，占满半轴');
      expect(slots.single.scale, closeTo(kTimelineMinScale, 0.001));
      expect(slots.single.opacity, closeTo(kTimelineMinOpacity, 0.001));
    });

    test('全部在今天：没有远近可分，都堆在轴心且不缩放', () {
      final slots = timelineLayout(
        [
          at('2026-09-11', id: 1),
          at('2026-09-11', id: 2),
          at('2026-09-11', id: 3, rule: RepeatRule.yearly),
        ],
        today: today,
        halfWidth: half,
      );
      expect(slots, hasLength(3));
      for (final s in slots) {
        expect(s.signedDays, 0);
        expect(s.x, 0);
        expect(s.scale, 1);
        expect(s.opacity, 1);
      }
      // 同一天的三条按 id 稳定排序，重建之间不会互相换位
      expect(slots.map((s) => s.daily.id), [1, 2, 3]);
    });

    test('全在过去：x 全是负的，越远越靠左越小越淡', () {
      final slots = timelineLayout(
        [at('2000-01-01', id: 1), at('2020-01-01', id: 2)],
        today: today,
        halfWidth: half,
      );
      expect(slots, hasLength(2));
      expect(slots.every((s) => s.x < 0), isTrue, reason: '过去一律在左半轴');
      // 排序是从远到近（时间升序），所以第一条是最远的那条
      final far = slots.first;
      final near = slots.last;
      expect(far.signedDays, lessThan(near.signedDays));
      expect(far.x, lessThan(near.x));
      expect(far.scale, lessThan(near.scale));
      expect(far.opacity, lessThan(near.opacity));
      expect(far.x, closeTo(-half, 0.01), reason: '最远那条顶到左端点');
    });

    test('全在未来：x 全是正的，最远那条顶到右端点', () {
      final slots = timelineLayout(
        [at('2030-01-01', id: 1), at('2031-01-01', id: 2)],
        today: today,
        halfWidth: half,
      );
      expect(slots.every((s) => s.x > 0), isTrue);
      expect(slots.last.x, closeTo(half, 0.01));
      expect(slots.first.x, lessThan(slots.last.x));
    });

    test('对数刻度：最远那条独占端点，近处那几条也不会被挤成一条线', () {
      // 线性刻度下 2026 年会贴在今天上；对数刻度下它应该离开轴心一段可见的距离
      final slots = timelineLayout(
        [at('1998-05-08', id: 1), at('2026-09-11', id: 2), at('2026-10-11', id: 3)],
        today: today,
        halfWidth: half,
      );
      expect(slots.first.x, closeTo(-half, 0.01));
      final monthLater = slots.firstWhere((s) => s.daily.id == 3);
      final now = slots.firstWhere((s) => s.daily.id == 2);
      expect(now.x, 0);
      // 「一个月后」要离轴心足够远才不会和「就是今天」的标签叠在一起
      expect(monthLater.x, greaterThan(30));
      // 但也得明显近于那条二十八年前的，否则刻度就白做了
      expect(monthLater.x, lessThan(half / 2));
    });

    test('重复记录用下一次定位，所以永远落在右半轴', () {
      final slots = timelineLayout(
        [at('1998-05-08', id: 1, rule: RepeatRule.yearly)],
        today: today,
        halfWidth: half,
      );
      expect(slots.single.signedDays, 239);
      expect(slots.single.x, greaterThan(0), reason: '下一次在 2027-05-08，还没到');
      expect(slots.single.day, DateTime.utc(2027, 5, 8));
    });

    test('日期解析不了的记录不进轴 —— 时间线上没有位置就是没有位置', () {
      final slots = timelineLayout(
        [at('', id: 1), at('不是日期', id: 2), at('2026-01-01', id: 3)],
        today: today,
        halfWidth: half,
      );
      expect(slots.map((s) => s.daily.id), [3]);
    });

    test('空列表返回空，不抛异常', () {
      expect(timelineLayout(const [], today: today, halfWidth: half), isEmpty);
    });

    test('halfWidth 只做等比缩放，不改变顺序', () {
      final data = [at('1990-01-01', id: 1), at('2030-01-01', id: 2)];
      final wide = timelineLayout(data, today: today, halfWidth: 1000);
      final narrow = timelineLayout(data, today: today, halfWidth: 50);
      expect(wide.map((s) => s.signedDays), narrow.map((s) => s.signedDays));
      expect(wide.last.x / narrow.last.x, closeTo(1000 / 50, 0.001));
    });
  });

  test('标签文案和首页共用同一个 countdownLabel', () {
    final slots = timelineLayout([at('2026-09-11', id: 1)], today: today, halfWidth: half);
    expect(countdownLabel(slots.single.signedDays), '就是今天');
  });
}
