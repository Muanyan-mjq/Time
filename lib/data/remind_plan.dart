/// 提醒排班里两个**纯**决策。
///
/// 抽出来是因为它们决定了「会不会响」「响的是哪条」，而真正要调用系统闹钟的
/// 那部分必须挂在插件上、没法单测。把判断和调用分开，判断就能钉死 ——
/// 一个亮着的提醒开关却什么都不做，是用户最晚才发现的那种坏法。
library;

import 'package:daily/model/daily.dart';
import 'package:daily/utils/date_util.dart';

/// 这条记录下次该在什么时候响。
///
/// 关着提醒、日期坏了都返回 null。**时刻已经过去也返回 null**：非重复记录里
/// 已经过去的日子、以及「提前 3 天」但 3 天前早已过完的，硬排一个过去的时间点，
/// 系统会立刻弹出来 —— 那不是提醒，是惊吓。
///
/// 代价是这类记录当年不会响（要等下一年也等不到，因为非重复记录没有下一次）。
/// 所以表单里对这种情况有一行明说的提示，用户看得见。
DateTime? remindMoment(Daily daily, DateTime now) {
  final day = daily.remindDateFrom(now);
  if (day == null) return null;
  final at = DateTime(day.year, day.month, day.day, daily.remindHour, daily.remindMinute);
  return at.isAfter(now) ? at : null;
}

/// 通知栏常驻倒计时该显示哪条：离今天最近的那个。
///
/// 优先「今天或未来」里最近的一条；全都过去了就取最不远的那个 ——
/// 通知栏里写「已经 300 天」也比空着好。日期坏了的记录一律不算候选。
({Daily daily, int days})? nearestReminder(List<Daily> dailies, DateTime now) {
  ({Daily daily, int days})? best;
  for (final d in dailies) {
    final next = d.nextDateFrom(now);
    if (next == null) continue;
    final days = signedDaysFromToday(next, now: now);
    if (days >= 0 && (best == null || days < best.days)) best = (daily: d, days: days);
  }
  if (best != null) return best;

  for (final d in dailies) {
    final date = d.date;
    if (date == null) continue;
    final days = signedDaysFromToday(date, now: now);
    if (best == null || days > best.days) best = (daily: d, days: days);
  }
  return best;
}
