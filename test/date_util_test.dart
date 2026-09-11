import 'package:daily/utils/date_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitYmd', () {
    test('同一天是 0年0月0天', () {
      expect(
        splitYmd(DateTime(2026, 9, 10), DateTime(2026, 9, 10)),
        (years: 0, months: 0, days: 0),
      );
    });

    test('回归：2019-05-08 → 2020-09-10 是 1年4月2天', () {
      // screenshot/Screenshot_3.png 是这个日期的真实截图，老版本显示 01/04/06。
      // 旧算法：491 ~/ 365 = 1，(491-365) ~/ 30 = 4，491-365-120 = 6 —— 差 4 天。
      expect(
        splitYmd(DateTime(2019, 5, 8), DateTime(2020, 9, 10)),
        (years: 1, months: 4, days: 2),
      );
    });

    test('不满一个月：2025-01-31 → 2025-02-28', () {
      // 夹取语义：2 月 28 日就是 1 月 31 日的「一个月」纪念日
      expect(
        splitYmd(DateTime(2025, 1, 31), DateTime(2025, 2, 28)),
        (years: 0, months: 1, days: 0),
      );
    });

    test('闰二月：2024-01-31 → 2024-02-29 也是满一个月', () {
      expect(
        splitYmd(DateTime(2024, 1, 31), DateTime(2024, 2, 29)),
        (years: 0, months: 1, days: 0),
      );
    });

    test('借位写法会算出负数天的那条：2024-01-31 → 2024-03-01', () {
      expect(
        splitYmd(DateTime(2024, 1, 31), DateTime(2024, 3, 1)),
        (years: 0, months: 1, days: 1),
      );
    });

    test('闰年周年：2024-02-29 → 2025-02-28 就是满一年', () {
      // 别改成「0年11月30天」—— 2 月 28 日就是那年第一个周年日
      expect(
        splitYmd(DateTime(2024, 2, 29), DateTime(2025, 2, 28)),
        (years: 1, months: 0, days: 0),
      );
    });

    test('days 恒落在 [0, 30]、months 恒落在 [0, 11]', () {
      for (var i = 0; i < 800; i++) {
        final r = splitYmd(DateTime(2024, 1, 31), DateTime(2024, 1, 31 + i));
        expect(r.days, inInclusiveRange(0, 30), reason: '第 $i 天');
        expect(r.months, inInclusiveRange(0, 11), reason: '第 $i 天');
      }
    });

    test('每推进一个日历日，总天数恰好 +1', () {
      final from = DateTime(2019, 5, 8);
      for (var i = 0; i < 400; i++) {
        expect(daysBetween(from, DateTime(2019, 5, 8 + i)), i);
      }
    });

    test('起点终点反过来传，结果一样', () {
      expect(
        splitYmd(DateTime(2020, 9, 10), DateTime(2019, 5, 8)),
        (years: 1, months: 4, days: 2),
      );
    });
  });

  group('signedDaysFromToday / daysBetween', () {
    final now = DateTime(2026, 9, 10);

    test('昨天 -1、今天 0、明天 +1', () {
      expect(signedDaysFromToday(DateTime(2026, 9, 9), now: now), -1);
      expect(signedDaysFromToday(DateTime(2026, 9, 10), now: now), 0);
      expect(signedDaysFromToday(DateTime(2026, 9, 11), now: now), 1);
    });

    test('跨夏令时也按日历天数算', () {
      // 本地时区下 DateTime(2026,3,8).difference(DateTime(2026,3,7)).inDays
      // 会得到 0 —— 两个本地零点只差 23 小时。UTC 归一化就是为了这个。
      expect(daysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 8)), 1);
      expect(daysBetween(DateTime(2026, 11, 1), DateTime(2026, 11, 2)), 1);
    });

    test('忽略时分秒', () {
      expect(daysBetween(DateTime(2026, 9, 10, 23, 59), DateTime(2026, 9, 11, 0, 1)), 1);
      expect(daysBetween(DateTime(2026, 9, 10, 0, 1), DateTime(2026, 9, 10, 23, 59)), 0);
    });
  });

  group('格式化', () {
    test('fmtStorage 逐字是 yyyy-MM-dd（磁盘上存的就是这个）', () {
      expect(fmtStorage(DateTime(2026, 9, 10)), '2026-09-10');
      expect(fmtStorage(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('fmtDisplay', () {
      expect(fmtDisplay(DateTime(2026, 9, 10)), '2026年9月10日');
      expect(fmtDisplay(DateTime(2026, 1, 5)), '2026年1月5日');
    });

    test('fmt2', () {
      expect(fmt2(0), '00');
      expect(fmt2(9), '09');
      expect(fmt2(10), '10');
      expect(fmt2(365), '365');
    });

    test('countdownLabel 的五种文案', () {
      expect(countdownLabel(0), '就是今天');
      expect(countdownLabel(3), '还有 3 天');
      expect(countdownLabel(400), '还有 400 天');
      expect(countdownLabel(-1826), '已经 1826 天');
      expect(countdownLabel(-3), '已经 3 天');
    });
  });
}
