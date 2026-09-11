import 'package:daily/model/daily.dart';
import 'package:daily/styles/dimens.dart';
import 'package:daily/utils/date_util.dart';

/// 时光轴的排版，全是纯数据 —— 页面只负责画和滚。
///
/// 轴是竖的：未来在上、今天一道横标、过去在下，越往下越久远；上下两端都
/// 是「离今天越来越远」。一屏装不下就滚，所以不再有容量天花板，每条记录
/// 也不必把信息挤进一枚 92px 宽的标签里。
///
/// 行的**高度全部固定**：概览带的高亮、点按跳转、「回到今天」的显隐，都要
/// 靠滚动位置反推行号（见 [TimelinePlan.visibleRows]）。哪一行改成不定高，
/// 这套映射就作废 —— 这也是它被单独拎出来、还要有测试的原因。
sealed class TimelineRow {
  const TimelineRow();

  double get height;
}

/// 年份分隔：轴上多出一截刻度，年份数字写在轴的左边。
///
/// 只在跨年时出现一次，不是每条记录都盖一个章。今年这一段的年份由
/// 「今天」那道横标顺手交代，所以下面不会再重复一遍。
final class YearRow extends TimelineRow {
  final int year;

  const YearRow(this.year);

  @override
  double get height => kTimelineYearRowHeight;
}

/// 今天。它是这条轴上唯一固定的东西：上面是未来，下面是过去。
final class TodayRow extends TimelineRow {
  const TodayRow();

  @override
  double get height => kTimelineTodayRowHeight;
}

/// 一条记录。封面圆点压在轴上，右边是标题、日期和倒计时。
final class RecordRow extends TimelineRow {
  final Daily daily;

  /// 定位用的那一天：非重复记录是起始日，重复记录是下一次重复日。
  /// 轴上没有「起始日」这个概念，只有「它落在哪一天」。
  final DateTime day;

  /// 距今天数：> 0 未来，== 0 今天，< 0 过去。
  final int signedDays;

  const RecordRow(this.daily, this.day, this.signedDays);

  bool get isToday => signedDays == 0;

  @override
  double get height => kTimelineRowHeight;
}

/// 排好版的时光轴：一串定高的行，加一份行号 ↔ 滚动位置的对照表。
class TimelinePlan {
  final List<TimelineRow> rows;

  /// 每行顶边的 y，长度是 rows.length + 1，最后一个是整轴总高。
  final List<double> _tops;

  /// 概览带横轴的两端。两端都含今天 —— 「今天」那枚刻线必须落在带上，
  /// 否则点带就不是「一辈子」而是「有记录的那一段」。
  final DateTime from;
  final DateTime to;

  /// 排版时用的「今天」。存下来是为了让概览带能画出今天那枚刻线。
  final DateTime today;

  const TimelinePlan._(this.rows, this._tops, this.from, this.to, this.today);

  double get height => _tops.isEmpty ? 0 : _tops.last;

  /// 「今天」那道横标在第几行。永远有（只要轴上有记录）。
  int get todayIndex => rows.indexWhere((r) => r is TodayRow);

  double topOf(int index) => _tops[index];

  /// 视口里看得见的第一行和最后一行。整行都在视口外的不算。
  ///
  /// 线性扫一遍就够：几十行，而且这个函数只在滚动时报到的那一帧跑一次。
  ({int first, int last})? visibleRows(double scrollTop, double viewportHeight) {
    if (rows.isEmpty) return null;
    final bottom = scrollTop + viewportHeight;
    int? first;
    var last = 0;
    for (var i = 0; i < rows.length; i++) {
      if (_tops[i + 1] <= scrollTop) continue;
      if (_tops[i] >= bottom) break;
      first ??= i;
      last = i;
    }
    return first == null ? null : (first: first, last: last);
  }

  /// 概览带：某一天落在横轴的哪个位置（0 是最早那端，width 是最晚那端）。
  ///
  /// 按**日历天**算，不按时间差：非重复记录的日子是本地零点、重复记录的是
  /// UTC 零点，两者直接相减会差出一个时区来。差一天在高亮上只有零点几像素，
  /// 但「同一天的点必须落在同一个 x 上」这件事值得无条件成立。
  double xOf(DateTime day, double width) {
    final span = daysBetween(from, to);
    if (span <= 0) return width / 2;
    return daysBetween(from, day) / span * width;
  }

  /// 概览带反过来用：点在横轴的 [x] 上，最近的那条记录是第几行。
  ///
  /// 不带时间刻度尺的地图也是这样 —— 点到哪儿都算数，落点最近的记录接住它。
  /// 比较直接在横坐标上做，所以「看着最近」和「接住你的那条」是同一件事。
  int? nearestRecordIndex(double x, double width) {
    if (rows.isEmpty || width <= 0) return null;
    int? best;
    var bestGap = 0.0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! RecordRow) continue;
      final gap = (xOf(row.day, width) - x).abs();
      if (best == null || gap < bestGap) {
        best = i;
        bestGap = gap;
      }
    }
    return best;
  }

  /// 从上到下第一条记录落在第几行（空轴返回 null）。
  int? get firstRecordIndex {
    final i = rows.indexWhere((r) => r is RecordRow);
    return i < 0 ? null : i;
  }
}

/// 把一列纪念日摊成一条竖轴。
///
/// 顺序是「离今天的远近」，不是单纯的时间先后：未来从远到近排在上面，
/// 跨过「今天」，过去再从近到远往下排。于是滚动的感觉是确定的 ——
/// 往下永远是回到更久以前，往上永远是走向更远的将来。
///
/// 日期解析不了的记录**不进轴**：时间线上没有位置就是没有位置，硬塞到
/// 今天旁边是个谎。它们照旧留在首页（见 `groupDailies`）。
TimelinePlan planTimeline(List<Daily> dailies, {required DateTime today}) {
  final dated = <({Daily daily, DateTime day, int days})>[];
  for (final d in dailies) {
    final day = d.nextDateFrom(today);
    if (day == null) continue;
    dated.add((daily: d, day: day, days: signedDaysFromToday(day, now: today)));
  }
  if (dated.isEmpty) return TimelinePlan._(const [], const [0], today, today, today);

  // 一个比较器管三段：天数从大到小 —— 落在轴上就是「越往上越远、越往下越远」，
  // 未来那段是远的在上，过去那段是近的在上，同一个方向。
  //
  // 只比天数的话，两条同一天的记录会在重建之间互相换位，圆点跟着跳；
  // 所以同一天里再比起始日和 id。id 用升序、不跟着天数一起翻过来，
  // 那样同一天的两条在轴上、在今天下面、在今天上面读起来都是一个次序。
  int byDistanceAway(({Daily daily, DateTime day, int days}) a, ({Daily daily, DateTime day, int days}) b) {
    final byDays = b.days.compareTo(a.days);
    if (byDays != 0) return byDays;
    final byTarget = a.daily.targetDay.compareTo(b.daily.targetDay);
    if (byTarget != 0) return byTarget;
    return a.daily.id.compareTo(b.daily.id);
  }

  final future = [for (final e in dated) if (e.days > 0) e]..sort(byDistanceAway);
  final todayList = [for (final e in dated) if (e.days == 0) e]..sort(byDistanceAway);
  final past = [for (final e in dated) if (e.days < 0) e]..sort(byDistanceAway);

  final rows = <TimelineRow>[];
  int? lastYear;
  void addRecord(({Daily daily, DateTime day, int days}) e) {
    if (lastYear != e.day.year) {
      rows.add(YearRow(e.day.year));
      lastYear = e.day.year;
    }
    rows.add(RecordRow(e.daily, e.day, e.days));
  }

  for (final e in future) {
    addRecord(e);
  }
  rows.add(const TodayRow());
  // 今天那几条的年份就是今天，横标已经交代过了
  lastYear = today.year;
  for (final e in todayList) {
    addRecord(e);
  }
  for (final e in past) {
    addRecord(e);
  }

  final tops = <double>[0];
  var y = 0.0;
  for (final r in rows) {
    y += r.height;
    tops.add(y);
  }

  var from = today;
  var to = today;
  for (final e in dated) {
    if (e.day.isBefore(from)) from = e.day;
    if (e.day.isAfter(to)) to = e.day;
  }

  return TimelinePlan._(rows, tops, from, to, today);
}
