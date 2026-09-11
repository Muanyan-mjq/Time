import 'package:daily/model/daily.dart';
import 'package:daily/model/daily_group.dart';
import 'package:daily/model/repeat_rule.dart';
import 'package:daily/utils/date_util.dart';
import 'package:flutter_test/flutter_test.dart';

/// 重复规则是这一轮最容易出错的地方：它同时改变了「下一次是哪天」和
/// 「还有几天」两个语义，而这两件事又被首页卡片、详情页、海报、提醒共用。
/// 所以每个边界都在这儿钉死。
///
/// 所有用例的「今天」都是显式传进去的，不依赖运行时时钟 —— 否则这些测试
/// 会在某一天突然变红。
void main() {
  group('nextOccurrence', () {
    test('不重复：无论今天几号，返回的都是起始日本身', () {
      final origin = DateTime.utc(2016, 3, 4);
      expect(
        nextOccurrence(origin, RepeatRule.none, DateTime.utc(2026, 9, 11)),
        origin,
      );
      // 起始日在未来也一样
      expect(
        nextOccurrence(origin, RepeatRule.none, DateTime.utc(2000, 1, 1)),
        origin,
      );
    });

    test('每年重复：起始日已经过了就是明年', () {
      expect(
        nextOccurrence(DateTime.utc(1998, 5, 8), RepeatRule.yearly, DateTime.utc(2026, 9, 11)),
        DateTime.utc(2027, 5, 8),
      );
    });

    test('每年重复：当天正好是重复日时返回今天，不是明年', () {
      expect(
        nextOccurrence(DateTime.utc(1998, 5, 8), RepeatRule.yearly, DateTime.utc(2026, 5, 8)),
        DateTime.utc(2026, 5, 8),
      );
    });

    test('每年重复：2月29日在平年夹到2月28日，回到闰年又是29日', () {
      final origin = DateTime.utc(2024, 2, 29);
      // 2025 是平年
      expect(
        nextOccurrence(origin, RepeatRule.yearly, DateTime.utc(2025, 1, 1)),
        DateTime.utc(2025, 2, 28),
      );
      // 平年的「2月28日」就是那一年的周年日，当天算达成
      expect(
        nextOccurrence(origin, RepeatRule.yearly, DateTime.utc(2025, 2, 28)),
        DateTime.utc(2025, 2, 28),
      );
      // 过了那一天，下一次是再一年后的 2月28日
      expect(
        nextOccurrence(origin, RepeatRule.yearly, DateTime.utc(2025, 3, 1)),
        DateTime.utc(2026, 2, 28),
      );
      // 2028 又是闰年
      expect(
        nextOccurrence(origin, RepeatRule.yearly, DateTime.utc(2028, 1, 1)),
        DateTime.utc(2028, 2, 29),
      );
    });

    test('每月重复：1月31日依次是2月28/29日、3月31日、4月30日', () {
      final origin = DateTime.utc(2024, 1, 31);
      expect(
        nextOccurrence(origin, RepeatRule.monthly, DateTime.utc(2024, 2, 1)),
        DateTime.utc(2024, 2, 29), // 2024 是闰年
      );
      expect(
        nextOccurrence(origin, RepeatRule.monthly, DateTime.utc(2024, 3, 5)),
        DateTime.utc(2024, 3, 31),
      );
      expect(
        nextOccurrence(origin, RepeatRule.monthly, DateTime.utc(2024, 4, 1)),
        DateTime.utc(2024, 4, 30),
      );
      // 夹取不会「越夹越短」：12 月又回到 31 日
      expect(
        nextOccurrence(origin, RepeatRule.monthly, DateTime.utc(2024, 12, 1)),
        DateTime.utc(2024, 12, 31),
      );
    });

    test('每月重复：跨年也对', () {
      expect(
        nextOccurrence(DateTime.utc(2025, 11, 15), RepeatRule.monthly, DateTime.utc(2026, 1, 2)),
        DateTime.utc(2026, 1, 15),
      );
    });

    test('起始日在未来：返回起始日，不往前找', () {
      expect(
        nextOccurrence(DateTime.utc(2030, 1, 1), RepeatRule.yearly, DateTime.utc(2026, 9, 11)),
        DateTime.utc(2030, 1, 1),
      );
    });

    test('很远的老起始日：不会退化成逐月扫描', () {
      // 1998 年的每年重复走到 2026 年要跨 336 个月，闭式求解应当一步到位
      expect(
        nextOccurrence(DateTime.utc(1998, 5, 8), RepeatRule.yearly, DateTime.utc(2026, 9, 11)),
        DateTime.utc(2027, 5, 8),
      );
    });
  });

  group('Daily.nextDate / remindDateFrom', () {
    Daily make({
      required String targetDay,
      RepeatRule rule = RepeatRule.none,
      bool remind = false,
      int daysBefore = 0,
    }) =>
        Daily(
          title: 't',
          headText: 'h',
          targetDay: targetDay,
          remark: '',
          repeatRule: rule,
          remindEnabled: remind,
          remindDaysBefore: daysBefore,
        );

    test('非重复记录的 nextDate 恒等于起始日', () {
      final today = DateTime.utc(2026, 9, 11);
      // 是「原样等于」，不是「换算到同一天」—— 这就是 nextDate 引入后
      // 首页卡片、详情页、海报三处行为一个字都不用改的原因
      final pasted = make(targetDay: '2019-05-08');
      expect(pasted.nextDateFrom(today), pasted.date);
      // 起始日在未来也一样，不会被「下一次」抢走
      final future = make(targetDay: '2030-01-01');
      expect(future.nextDateFrom(today), future.date);
    });

    test('重复记录的 nextDate 是今天起的第一个重复日', () {
      final today = DateTime.utc(2026, 9, 11);
      expect(
        make(targetDay: '1998-05-08', rule: RepeatRule.yearly).nextDateFrom(today),
        DateTime.utc(2027, 5, 8),
      );
    });

    test('日期解析不了时 nextDate 和提醒日期都是 null', () {
      final today = DateTime.utc(2026, 9, 11);
      final d = make(targetDay: '', rule: RepeatRule.yearly, remind: true);
      expect(d.nextDateFrom(today), isNull);
      expect(d.remindDateFrom(today), isNull);
    });

    test('提醒默认关着，开关拨开才算出日期', () {
      final today = DateTime.utc(2026, 9, 11);
      final off = make(targetDay: '1998-05-08', rule: RepeatRule.yearly);
      expect(off.remindDateFrom(today), isNull);

      final on = make(targetDay: '1998-05-08', rule: RepeatRule.yearly, remind: true);
      // 提前 0 天 = 当天
      expect(on.remindDateFrom(today), DateTime.utc(2027, 5, 8));
    });

    test('提前 N 天：从下一次重复日往前推，会跨月跨年', () {
      final today = DateTime.utc(2026, 9, 11);
      final d = make(
        targetDay: '1998-05-08',
        rule: RepeatRule.yearly,
        remind: true,
        daysBefore: 3,
      );
      expect(d.remindDateFrom(today), DateTime.utc(2027, 5, 5));
    });
  });

  group('重复记录在首页的位置', () {
    Daily make(int id, String targetDay, RepeatRule rule) => Daily(
          id: id,
          title: 'd$id',
          headText: 'h',
          targetDay: targetDay,
          remark: '',
          repeatRule: rule,
        );

    test('重复记录永远落在「未来」组，即使起始日在很多年前', () {
      final today = DateTime.utc(2026, 9, 11);
      final groups = groupDailies([
        make(1, '1998-05-08', RepeatRule.yearly), // 下一次 2027-05-08
        make(2, '2019-05-08', RepeatRule.none), // 已经过去
      ], now: today);

      expect(groups.map((g) => g.name), [kGroupFuture, kGroupPast]);

      final future = groups.first.items.single;
      expect(future.daily.id, 1);
      expect(future.nextDate, DateTime.utc(2027, 5, 8));
      // 1998-05-08 起算的 239 天，正是验收里那个数
      expect(future.signedDays, 239);

      expect(groups[1].items.single.daily.id, 2);
      expect(groups[1].items.single.signedDays, isNegative);
    });

    test('重复记录的卡片文案由 nextDate 得出，与详情页共用一个数', () {
      final today = DateTime.utc(2026, 9, 11);
      final groups = groupDailies([make(1, '1998-05-08', RepeatRule.yearly)], now: today);
      final entry = groups.single.items.single;
      expect(countdownLabel(entry.signedDays!), '还有 239 天');
    });
  });
}
