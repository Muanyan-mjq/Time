import 'package:daily/data/daily_repository.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/pages/detail/detail.dart';
import 'package:daily/pages/timeline.dart';
import 'package:daily/styles/dimens.dart';
import 'package:daily/utils/date_util.dart';
import 'package:daily/utils/timeline_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 时光轴页面：行都画出来了、概览带什么时候出现、点带跳转、回到今天。
///
/// 页面里的「今天」读的是运行时时钟，所以这里的日期一律拿 `addDays(now, n)`
/// 现算 —— 钉死某一天的写法过一阵子就会自己烂掉。
Future<void> _pumpTimeline(WidgetTester tester, List<Daily> dailies) async {
  DailyRepository.instance.items.value = dailies;
  addTearDown(() => DailyRepository.instance.items.value = const []);
  await tester.pumpWidget(const MaterialApp(home: TimelinePage()));
  await tester.pumpAndSettle();
}

/// 相对今天第 [daysFromToday] 天的一条记录。渐变封面不走磁盘，测试里不碰相册。
Daily _rec(int id, int daysFromToday) => Daily(
      id: id,
      title: '记录 $id',
      headText: '',
      targetDay: fmtStorage(addDays(DateTime.now(), daysFromToday)),
      remark: '',
      coverKey: 'g:${id % 6}',
    );

/// 14 条铺得很开：一屏肯定装不下，最早那条和最远那条分别顶在轴的两头。
List<Daily> _spread() => [
      for (var i = 1; i <= 6; i++) _rec(i, i * 300),
      _rec(7, 0),
      for (var i = 8; i <= 14; i++) _rec(i, -(i - 7) * 300),
    ];

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    ))
    .position;

/// 「回到今天」当前是不是按不动的状态（藏着的时候按它不该有反应）。
bool _todayButtonIgnored(WidgetTester tester) => tester
    .widget<IgnorePointer>(find
        .ancestor(of: find.text('回到今天'), matching: find.byType(IgnorePointer))
        .first)
    .ignoring;

void main() {
  test('行高跟着卡片走：缩略图 + 上下内边距 + 行间空隙', () {
    expect(
      kTimelineCardHeight,
      kTimelineThumbSize + 2 * kTimelineCardPadding,
      reason: '卡片高就是缩略图加上下那圈内边距',
    );
    expect(
      kTimelineRowHeight,
      kTimelineCardHeight + kTimelineRowGap,
      reason: '卡片高多少，行高就得是多少 —— 差一像素，概览带的高亮和点按跳转就全错位',
    );
  });

  testWidgets('一条记录都没有时是空态，不是一条光秃秃的轴', (tester) async {
    await _pumpTimeline(tester, const []);

    expect(tester.takeException(), isNull);
    expect(find.text('还没有值得纪念的日子'), findsOneWidget);
    expect(find.text('添加第一条'), findsOneWidget);
    expect(find.byType(ListView), findsNothing, reason: '空轴上没有行可摆');
    expect(find.text('今天'), findsNothing);
  });

  testWidgets('记录都在轴上：标题、日期、倒计时，外加一道「今天」', (tester) async {
    await _pumpTimeline(tester, [_rec(1, 30), _rec(2, 0), _rec(3, -30)]);

    expect(tester.takeException(), isNull);
    expect(find.text('记录 1'), findsOneWidget);
    expect(find.text('记录 2'), findsOneWidget);
    expect(find.text('记录 3'), findsOneWidget);
    expect(find.text(fmtMonthDay(addDays(DateTime.now(), 30))), findsOneWidget);
    expect(find.text('还有 30 天'), findsOneWidget);
    expect(find.text('已经 30 天'), findsOneWidget);
    expect(find.text('就是今天'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget, reason: '「今天」那道横标只此一处');
  });

  testWidgets('年份是左对齐的分节标题，标题上写着这一年有几条', (tester) async {
    final dailies = [_rec(1, 300), _rec(2, 400), _rec(3, 500)];
    await _pumpTimeline(tester, dailies);

    final years = planTimeline(dailies, today: DateTime.now()).rows.whereType<YearRow>().toList();
    expect(years, isNotEmpty);
    for (final row in years) {
      expect(find.text('${row.year}'), findsOneWidget);
      expect(find.text('· ${row.count}'), findsOneWidget);
    }
  });

  testWidgets('一屏装得下就不摆概览带', (tester) async {
    await _pumpTimeline(tester, [_rec(1, 30), _rec(2, 0), _rec(3, -30)]);

    // 一屏装得下时列表拿走整块高度：概览带不在，也就不占那 kTimelineBandHeight
    expect(tester.getSize(find.byType(ListView)).height, 600 - 48);
    expect(_position(tester).pixels, 0, reason: '装得下就没有可滚的，也没必要滚');
  });

  testWidgets('一屏装不下：概览带出现，而且打开就落在今天', (tester) async {
    await _pumpTimeline(tester, _spread());

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(ListView)).height,
      600 - 48 - kTimelineBandHeight,
      reason: '概览带占了顶上那一条',
    );
    // 页面自己滚到了今天，不用用户再找
    final list = tester.getRect(find.byType(ListView));
    final today = tester.getRect(find.text('今天'));
    expect(today.top, greaterThanOrEqualTo(list.top));
    expect(today.bottom, lessThanOrEqualTo(list.bottom));
    expect(_position(tester).pixels, greaterThan(0), reason: '今天在轴中间，得滚一段才看得见');
  });

  testWidgets('点概览带最右端，跳到最远的那条未来记录', (tester) async {
    await _pumpTimeline(tester, _spread());

    // 先滑到轴尾（最早那条），再点带子的右端
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.text('记录 14'), findsOneWidget, reason: '一条 2100 天前的记录');

    await tester.tapAt(Offset(800 - kTimelineBandPadding - 2, 48 + kTimelineBandHeight / 2));
    await tester.pumpAndSettle();

    expect(_position(tester).pixels, 0, reason: '最远那条在轴的头上');
    expect(find.text('记录 6'), findsOneWidget, reason: '一条 1800 天后的记录');
  });

  testWidgets('滚走之后「回到今天」才按得动，按一下回到今天', (tester) async {
    await _pumpTimeline(tester, _spread());

    expect(_todayButtonIgnored(tester), isTrue, reason: '本来就停在今天，这个按钮没有意义');

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(_todayButtonIgnored(tester), isFalse, reason: '滚走了就该让它能按');
    expect(find.text('今天'), findsNothing, reason: '这会儿确实看不见今天了');

    await tester.tap(find.text('回到今天'));
    await tester.pumpAndSettle();

    expect(_todayButtonIgnored(tester), isTrue);
    final list = tester.getRect(find.byType(ListView));
    final today = tester.getRect(find.text('今天'));
    expect(today.top, greaterThanOrEqualTo(list.top));
    expect(today.bottom, lessThanOrEqualTo(list.bottom));
  });

  testWidgets('点一条记录进详情页', (tester) async {
    await _pumpTimeline(tester, [_rec(1, 30), _rec(2, -30)]);

    await tester.tap(find.text('记录 2'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(HeroDetailPage), findsOneWidget);
  });
}
