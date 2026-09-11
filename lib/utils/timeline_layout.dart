import 'dart:math' as math;

import 'package:daily/model/daily.dart';
import 'package:daily/utils/date_util.dart';

/// 轴上最远的那一枚缩到多小 / 多淡。
///
/// 不是 0：再远的记录也还是「我的记录」，缩到看不见就成装饰了。
const double kTimelineMinScale = 0.55;
const double kTimelineMinOpacity = 0.34;

/// 时光轴上的一枚。
class TimelineSlot {
  final Daily daily;

  /// 定位用的那一天：非重复记录是起始日，重复记录是下一次。
  final DateTime day;

  /// 距今天数，负数是过去。
  final int signedDays;

  /// 相对轴心（今天）的水平像素偏移，落在 ±halfWidth 之间。
  final double x;

  /// 越远越小。1.0 是最靠近今天的那一档。
  final double scale;

  /// 越远越淡。过去和未来都淡，方向感由 [x] 的正负给。
  final double opacity;

  const TimelineSlot({
    required this.daily,
    required this.day,
    required this.signedDays,
    required this.x,
    required this.scale,
    required this.opacity,
  });
}

/// 把一列纪念日摊到以「今天」为原点的水平轴上，从左到右按时间排好。
///
/// 刻度是**对数**的：`x = sign(d) · log(1+|d|) / log(1+max|d|) · halfWidth`。
/// 线性刻度下，一条 1998 年的记录会把 2020 年以后的全部挤进轴上几个像素里 ——
/// 而这条轴大半的价值恰恰在「这几年我攒了些什么」。
///
/// 分母取**这批数据里最远的那条**，于是纵向永远铺满整个视口、不会缩在一角；
/// 代价是新增一条很老的记录会让其余的整体往中间收一点。这是取舍，不是 bug。
///
/// 日期解析不了的记录**不进轴**：时间线上没有位置就是没有位置，硬塞到今天旁边
/// 是个谎。它们照旧留在首页的「未来」组里（见 [groupDailies]）。
List<TimelineSlot> timelineLayout(
  List<Daily> dailies, {
  required DateTime today,
  required double halfWidth,
}) {
  final dated = <({Daily daily, DateTime day, int days})>[];
  for (final d in dailies) {
    final day = d.nextDateFrom(today);
    if (day == null) continue;
    dated.add((daily: d, day: day, days: signedDaysFromToday(day, now: today)));
  }
  if (dated.isEmpty) return const [];

  // 全序排序。只比天数的话，两条同一天的记录会在重建之间互相换位，点会跳。
  dated.sort((a, b) {
    final byDays = a.days.compareTo(b.days);
    if (byDays != 0) return byDays;
    final byTarget = a.daily.targetDay.compareTo(b.daily.targetDay);
    if (byTarget != 0) return byTarget;
    return a.daily.id.compareTo(b.daily.id);
  });

  var maxAbs = 0;
  for (final e in dated) {
    maxAbs = math.max(maxAbs, e.days.abs());
  }
  // 全部落在今天：没有远近可分，都堆在轴心
  if (maxAbs == 0) {
    return [
      for (final e in dated)
        TimelineSlot(
          daily: e.daily,
          day: e.day,
          signedDays: 0,
          x: 0,
          scale: 1,
          opacity: 1,
        ),
    ];
  }

  // 底数在比值里约掉，自然对数即可
  final denominator = math.log(1 + maxAbs);
  final slots = <TimelineSlot>[];
  for (final e in dated) {
    final t = math.log(1 + e.days.abs()) / denominator; // 0（今天）→ 1（最远）
    slots.add(
      TimelineSlot(
        daily: e.daily,
        day: e.day,
        signedDays: e.days,
        x: (e.days < 0 ? -1.0 : 1.0) * t * halfWidth,
        scale: 1 - (1 - kTimelineMinScale) * t,
        opacity: 1 - (1 - kTimelineMinOpacity) * t,
      ),
    );
  }
  return slots;
}
