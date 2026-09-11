import 'package:daily/model/daily.dart';
import 'package:daily/utils/date_util.dart';

const String kGroupFuture = '未来';
const String kGroupPast = '已过去';

/// 一条纪念日，附带算好的距今天数。
class DailyEntry {
  final Daily daily;

  /// 倒计时真正指向的那一天。
  ///
  /// 非重复记录就是起始日；重复记录是下一个重复日。它被单独存下来，是因为
  /// 「还有 N 天」和「年龄」两个视角都要用它，而 `daily.date` 只够后者用。
  final DateTime? nextDate;

  /// 距今天数：> 0 未来，== 0 今天，< 0 过去。
  /// 日期解析不了时为 null，界面显示「日期待补充」。
  final int? signedDays;

  const DailyEntry(this.daily, this.nextDate, this.signedDays);

  DateTime? get date => daily.date;
}

/// 首页的一个分组。
class DailyGroup {
  final String name;
  final List<DailyEntry> items;

  const DailyGroup(this.name, this.items);

  /// 「未来 · 3」
  String get label => '$name · ${items.length}';
}

/// 把纪念日分成「未来」和「已过去」两组，各自按离今天的远近升序。
///
/// 排序的基准是 [Daily.nextDate] 而不是起始日：重复记录的下一次永远在今天
/// 或之后，所以它们恒落在「未来」组 —— 这正确，因为它的下一次确实还没到。
///
/// 放在 Dart 里而不是 SQL 里：SQLite 的 `julianday()` 跟 [date_util] 的
/// UTC 口径对不齐，而且数据量只有几十条，放这儿可以纯单元测试。
///
/// 排序用全序（天数 → 日期字符串 → id）。`List.sort` 不稳定，只比天数的话
/// 两条「还有 5 天」的记录会在重建之间互相换位，Hero 动画会闪。
List<DailyGroup> groupDailies(List<Daily> dailies, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final entries = <DailyEntry>[];
  for (final d in dailies) {
    final next = d.nextDateFrom(today);
    entries.add(DailyEntry(d, next, next == null ? null : signedDaysFromToday(next, now: today)));
  }

  // 今天归「未来」：它是「还剩 0 天」，再单开一组就跟「未来 / 已过去」两组矛盾了
  final future = entries.where((e) => e.signedDays == null || e.signedDays! >= 0).toList()..sort(_compare);
  final past = entries.where((e) => e.signedDays != null && e.signedDays! < 0).toList()..sort(_compare);

  return [
    if (future.isNotEmpty) DailyGroup(kGroupFuture, future),
    if (past.isNotEmpty) DailyGroup(kGroupPast, past),
  ];
}

int _compare(DailyEntry a, DailyEntry b) {
  // 没日期的沉到最底
  if (a.signedDays == null || b.signedDays == null) {
    if (a.signedDays == null && b.signedDays == null) {
      return a.daily.id.compareTo(b.daily.id);
    }
    return a.signedDays == null ? 1 : -1;
  }
  final byDistance = a.signedDays!.abs().compareTo(b.signedDays!.abs());
  if (byDistance != 0) return byDistance;
  final byDay = a.daily.targetDay.compareTo(b.daily.targetDay);
  if (byDay != 0) return byDay;
  return a.daily.id.compareTo(b.daily.id);
}
