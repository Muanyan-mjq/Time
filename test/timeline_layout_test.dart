import 'package:daily/model/daily.dart';
import 'package:daily/model/repeat_rule.dart';
import 'package:daily/utils/date_util.dart';
import 'package:daily/utils/timeline_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// 时光轴的排版是纯函数，边界全在这儿钉住 —— 页面上只剩画和滚。
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

  /// 把排版结果写成一行一行的壳，「轴长什么样」在断言里就能直接读出来。
  List<String> shape(TimelinePlan plan) => [
        for (final row in plan.rows)
          switch (row) {
            YearRow(:final year) => '年 $year',
            TodayRow() => '—— 今天 ——',
            RecordRow(:final daily, :final day) => '#${daily.id} ${fmtStorage(day)}',
          },
      ];

  int rowOf(TimelinePlan plan, int id) =>
      plan.rows.indexWhere((r) => r is RecordRow && r.daily.id == id);

  List<int> signedDaysOf(TimelinePlan plan) =>
      [for (final r in plan.rows) if (r is RecordRow) r.signedDays];

  group('行序', () {
    test('未来在上、今天在中间、过去在下', () {
      final plan = planTimeline([
        at('2020-01-01', id: 1),
        at('2027-01-01', id: 2),
        at('2026-09-11', id: 3),
        at('2000-01-01', id: 4),
        at('2030-01-01', id: 5),
      ], today: today);
      expect(shape(plan), [
        '年 2030', '#5 2030-01-01',
        '年 2027', '#2 2027-01-01',
        '—— 今天 ——',
        '#3 2026-09-11',
        '年 2020', '#1 2020-01-01',
        '年 2000', '#4 2000-01-01',
      ]);
      expect(plan.todayIndex, 4);
      expect(plan.rows[plan.todayIndex], isA<TodayRow>());
    });

    test('整条轴按「距今天数」从大到小排', () {
      // 这一条比上面那条更狠：它同时说了未来在上、过去在下，
      // 还说了未来是从远到近、过去是从近到远 —— 轴的单调性只有一条
      final plan = planTimeline([
        at('2030-01-01', id: 1),
        at('2027-01-01', id: 2),
        at('2026-09-11', id: 3),
        at('2020-01-01', id: 4),
        at('2000-01-01', id: 5),
      ], today: today);
      final days = signedDaysOf(plan);
      expect(days, hasLength(5));
      expect(days.first, greaterThan(0), reason: '最上面那条是未来的');
      expect(days.last, lessThan(0), reason: '最下面那条是过去的');
      for (var i = 1; i < days.length; i++) {
        expect(days[i], lessThanOrEqualTo(days[i - 1]), reason: '第 $i 行比上一行更远离今天，轴反了');
      }
    });

    test('同一天的多条按 id 稳定排，重建之间不换位', () {
      final plan = planTimeline([
        at('2027-03-03', id: 3),
        at('2027-03-03', id: 1),
        at('2027-03-03', id: 2),
      ], today: today);
      expect(
        [for (final r in plan.rows) if (r is RecordRow) r.daily.id],
        [1, 2, 3],
      );
    });

    test('日期解析不了的记录不进轴 —— 时间线上没有位置就是没有位置', () {
      final plan = planTimeline([
        at('', id: 1),
        at('不是日期', id: 2),
        at('2026-01-01', id: 3),
      ], today: today);
      expect(shape(plan), ['—— 今天 ——', '#3 2026-01-01']);
    });

    test('空列表：没有行，高度 0，处处不炸', () {
      final plan = planTimeline(const [], today: today);
      expect(plan.rows, isEmpty);
      expect(plan.height, 0);
      expect(plan.todayIndex, -1);
      expect(plan.firstRecordIndex, isNull);
      expect(plan.visibleRows(0, 500), isNull);
      expect(plan.nearestRecordIndex(10, 100), isNull);
      expect(plan.xOf(today, 100), 50, reason: '没有跨度可言，落在正中间');
    });

    test('重复记录用下一次重复日定位', () {
      final plan = planTimeline([
        at('1998-05-08', id: 1, rule: RepeatRule.yearly),
      ], today: today);
      final row = plan.rows.whereType<RecordRow>().single;
      expect(row.day, DateTime.utc(2027, 5, 8), reason: '1998 年的每年重复，下一次是 2027-05-08');
      expect(row.signedDays, 239);
      expect(row.isToday, isFalse);
      expect(plan.firstRecordIndex, 1, reason: '上面先有 2027 年那行刻度');
    });
  });

  group('年份刻度', () {
    test('只在跨年处插一行，今年不会在「今天」下面重复盖一次章', () {
      final plan = planTimeline([
        at('2030-05-01', id: 1),
        at('2028-05-01', id: 2),
        at('2026-10-01', id: 3),
        at('2026-09-11', id: 4),
        at('2026-01-01', id: 5),
        at('2025-12-31', id: 6),
      ], today: today);
      expect(shape(plan), [
        '年 2030', '#1 2030-05-01',
        '年 2028', '#2 2028-05-01',
        '年 2026', '#3 2026-10-01',
        '—— 今天 ——',
        '#4 2026-09-11',
        '#5 2026-01-01',
        '年 2025', '#6 2025-12-31',
      ]);
    });
  });

  group('行高与滚动位置', () {
    test('tops 是行高的前缀和，height 是总高', () {
      final plan = planTimeline([
        at('2030-01-01', id: 1),
        at('2020-01-01', id: 2),
      ], today: today);
      var y = 0.0;
      for (var i = 0; i < plan.rows.length; i++) {
        expect(plan.topOf(i), closeTo(y, 0.001), reason: '第 $i 行的顶边对不上前缀和');
        y += plan.rows[i].height;
      }
      expect(plan.height, closeTo(y, 0.001));
      expect(plan.topOf(plan.rows.length), closeTo(y, 0.001), reason: '末尾要多存一个总高，好当最后一行的底边用');
    });

    test('visibleRows 取的是「和视口有交集」的那一段', () {
      // 单条未来记录：年刻度 30 + 记录 64 + 今天 44，总高 138
      final plan = planTimeline([at('2030-01-01', id: 1)], today: today);
      expect(plan.todayIndex, 2);
      expect(plan.height, 138);

      expect(plan.visibleRows(0, 138), (first: 0, last: 2));
      expect(plan.visibleRows(0, 30), (first: 0, last: 0), reason: '行底正好压在视口下沿也算看得见');
      expect(plan.visibleRows(30, 10), (first: 1, last: 1), reason: '刻度整行在视口上方，不算');
      expect(plan.visibleRows(94, 44), (first: 2, last: 2));
      expect(plan.visibleRows(138, 44), isNull, reason: '滚过尾巴之后一条都看不见');
      expect(plan.visibleRows(-50, 138), (first: 0, last: 1), reason: '回弹到负偏移时贴着头那几行');
    });
  });

  group('概览带', () {
    final plan = planTimeline([
      at('2000-01-01', id: 1),
      at('2020-01-01', id: 2),
      at('2030-01-01', id: 3),
    ], today: today);
    const w = 100.0;

    test('横轴两端正好是最早和最晚的那天', () {
      expect(fmtStorage(plan.from), '2000-01-01');
      expect(fmtStorage(plan.to), '2030-01-01');
      expect(plan.xOf(plan.from, w), closeTo(0, 0.001));
      expect(plan.xOf(plan.to, w), closeTo(w, 0.001));
    });

    test('按时间线性铺开：疏密就是那些年攒下的东西，不是行号', () {
      final early = plan.xOf(DateTime.utc(2000, 1, 1), w);
      final mid = plan.xOf(DateTime.utc(2020, 1, 1), w);
      final now = plan.xOf(plan.today, w);
      final late = plan.xOf(DateTime.utc(2030, 1, 1), w);
      expect(early, lessThan(mid));
      expect(mid, lessThan(now));
      expect(now, lessThan(late));
      // 2000→2020 占掉三分之二，2020→2030 只剩三分之一
      expect(mid, closeTo(w * 2 / 3, 0.5));
    });

    test('同一天的点落在同一个 x 上', () {
      final day = DateTime.utc(2026, 9, 11);
      expect(plan.xOf(day, w), plan.xOf(day, w));
      // 本地零点写的同一格，和 UTC 零点写的必须是同一个位置
      expect(plan.xOf(DateTime(2026, 9, 11), w), closeTo(plan.xOf(day, w), 0.001));
    });

    test('点带：落点最近的记录接住它', () {
      expect(plan.nearestRecordIndex(plan.xOf(DateTime.utc(2000, 1, 1), w), w), rowOf(plan, 1));
      expect(plan.nearestRecordIndex(plan.xOf(DateTime.utc(2020, 1, 1), w), w), rowOf(plan, 2));
      expect(plan.nearestRecordIndex(w, w), rowOf(plan, 3));
      // 点在两条之间的空白上也有归属，不会点了没反应
      final between = plan.xOf(DateTime.utc(2020, 1, 1), w) - 20;
      expect(plan.nearestRecordIndex(between, w), rowOf(plan, 2));
      expect(plan.nearestRecordIndex(0, 0), isNull, reason: '带子还没量出宽度，别猜');
    });

    test('全部落在今天：跨度是 0，点带不除以零', () {
      final flat = planTimeline([
        at('2026-09-11', id: 1),
        at('2026-09-11', id: 2),
      ], today: today);
      expect(fmtStorage(flat.from), '2026-09-11');
      expect(fmtStorage(flat.to), '2026-09-11');
      expect(flat.xOf(flat.today, w), 50);
      expect(flat.nearestRecordIndex(0, w), rowOf(flat, 1));
      expect(flat.nearestRecordIndex(w, w), rowOf(flat, 1));
    });
  });

  test('标签文案和首页共用同一个 countdownLabel', () {
    final plan = planTimeline([at('2026-09-11', id: 1)], today: today);
    final row = plan.rows.whereType<RecordRow>().single;
    expect(row.isToday, isTrue);
    expect(countdownLabel(row.signedDays), '就是今天');
  });
}
