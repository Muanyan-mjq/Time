import 'dart:math' as math;

import 'package:daily/model/repeat_rule.dart';

/// 全 App 统一的「天」口径。
///
/// 一律先把日历日归一化到 UTC 零点再相减。用 UTC 是为了绕开夏令时：
/// 在本地时区下 `DateTime(2026, 3, 8).difference(DateTime(2026, 3, 7)).inDays`
/// 会得到 0，因为两个本地零点之间只差 23 小时。中国 1991 年后没有夏令时，
/// 但这样写零成本，且在任何时区、任何 CI 上结果都对。
DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// [b] 减 [a] 的日历天数，可为负。
int daysBetween(DateTime a, DateTime b) => _day(b).difference(_day(a)).inDays;

/// 距今天的天数。> 0 未来，== 0 今天，< 0 过去。
///
/// 这是全 App 唯一的真值来源：首页卡片的「已经 / 还有 N 天」、详情页的大数字、
/// 海报上的天数，全部由它得出，物理上不可能出现三处不一致。
int signedDaysFromToday(DateTime target, {DateTime? now}) =>
    daysBetween(now ?? DateTime.now(), target);

/// 在 [base] 上加 [months] 个月；日溢出时夹取到目标月的最后一天
/// （1 月 31 日 + 1 个月 → 2 月 28/29 日）。
DateTime addMonthsClamped(DateTime base, int months) {
  final total = base.year * 12 + (base.month - 1) + months;
  final year = (total / 12).floor();
  final month = total - year * 12 + 1;
  // day = 0 表示上个月的最后一天，正好用来求本月天数
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, math.min(base.day, lastDay));
}

/// 日历日加减，跨月跨年自动进位。同样先归一化到 UTC 零点。
DateTime addDays(DateTime d, int days) => DateTime.utc(d.year, d.month, d.day + days);

/// 从 [origin] 出发，找 [from] 当天或之后的第一个重复日。
///
/// 复用 [addMonthsClamped]，所以夹取语义和 [splitYmd] 完全一致：
/// 2024-02-29 的每年重复在平年落到 2 月 28 日，回到闰年又是 2 月 29 日；
/// 1 月 31 日的每月重复是 2 月 28/29 日、3 月 31 日、4 月 30 日……
///
/// 用闭式求解（按年月差粗估周期数再向两侧收敛），不做逐日扫描 ——
/// 一条 1998 年的每年重复记录走到今天要扫一万天，没必要。
///
/// [RepeatRule.none] 直接返回 [origin]，非重复记录因此天然落回「起始日」的旧语义。
DateTime nextOccurrence(DateTime origin, RepeatRule rule, DateTime from) {
  final step = rule.monthsPerStep;
  if (step == 0) return origin;

  final base = _day(origin);
  final target = _day(from);
  // 起始日还没到（或正好是今天）：下一次就是它自己
  if (!base.isBefore(target)) return base;

  var n = ((target.year - base.year) * 12 + (target.month - base.month)) ~/ step;
  while (n > 0 && addMonthsClamped(base, n * step).isAfter(target)) {
    n--;
  }
  while (addMonthsClamped(base, (n + 1) * step).isBefore(target)) {
    n++;
  }
  final candidate = addMonthsClamped(base, n * step);
  return candidate.isBefore(target) ? addMonthsClamped(base, (n + 1) * step) : candidate;
}

/// 把 [from] → [to] 分解成「年 / 月 / 日」。
///
/// 算法是「最大整数月 + 余数天」，不做借位：
///   1) 求最大的 m 使 addMonthsClamped(from, m) <= to
///   2) anchor = addMonthsClamped(from, m)
///   3) days = daysBetween(anchor, to)          // 恒落在 [0, 30]
///
/// 这个写法保证每推进一个日历日「总天数」恰好 +1，且 days 永远是两位数以内。
/// 借位式写法（从总天数里减年份再减月份）在 2024-01-31 → 2024-03-01 会算出负数天。
///
/// 夹取语义是刻意的：2024-02-29 → 2025-02-28 得到「1年0月0天」，
/// 因为 2 月 28 日就是那年 2 月 29 日的周年日。别改成「0年11月30天」。
({int years, int months, int days}) splitYmd(DateTime from, DateTime to) {
  final lo = _day(from);
  final hi = _day(to);
  if (hi.isBefore(lo)) {
    final r = splitYmd(to, from);
    return (years: r.years, months: r.months, days: r.days);
  }
  // 先按月份差粗估（最多大 1），再向两侧收敛，避免长区间上的线性扫描
  var m = (hi.year - lo.year) * 12 + (hi.month - lo.month);
  while (m > 0 && addMonthsClamped(lo, m).isAfter(hi)) {
    m--;
  }
  while (!addMonthsClamped(lo, m + 1).isAfter(hi)) {
    m++;
  }
  final anchor = addMonthsClamped(lo, m);
  return (years: m ~/ 12, months: m % 12, days: daysBetween(anchor, hi));
}

/// 磁盘格式，必须逐字保持 `yyyy-MM-dd` —— 数据库里存的就是这个格式。
String fmtStorage(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// 展示格式 `2026年9月10日`。
String fmtDisplay(DateTime d) => '${d.year}年${d.month}月${d.day}日';

/// 紧凑格式 `09-10`。时光轴上用它：年份由轴上的年份刻度交代，两边不重复，
/// 一行也就摆得下标题、日期和倒计时三样东西。
String fmtMonthDay(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 两位数计数，用于详情页的三个大数字。
String fmt2(int n) => n < 10 ? '0$n' : '$n';

/// 首页卡片和详情页共用的标签文案。
///
/// [days] 就是 [signedDaysFromToday] 的返回值，两处标签必须由同一个数得出。
String countdownLabel(int days) {
  if (days > 0) return '还有 $days 天';
  if (days < 0) return '已经 ${-days} 天';
  return '就是今天';
}
