import 'package:daily/components/daily_card.dart';
import 'package:daily/model/cover.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/model/repeat_rule.dart';
import 'package:daily/pages/detail/detail.dart';
import 'package:daily/utils/date_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 详情页和卡片上「时间」这件事只有一个说法。
///
/// 以前同一个画面里「就是今天」能出现三次（右上角徽章、中间大字、右下角
/// 倒计时），而切到「天」视图时中间那个大数字又和右下角是同一个数说两遍。
/// 这里钉住收敛之后的行为。

Daily _daily({
  String targetDay = '2019-05-08',
  String title = '第一次去旅游',
  String headText = '神奇的西藏',
  RepeatRule repeat = RepeatRule.yearly,
  bool remind = true,
  int daysBefore = 3,
  int hour = 9,
  int minute = 0,
}) =>
    Daily(
      id: 1,
      title: title,
      headText: headText,
      targetDay: targetDay,
      remark: '',
      repeatRule: repeat,
      remindEnabled: remind,
      remindDaysBefore: daysBefore,
      remindHour: hour,
      remindMinute: minute,
    );

Future<void> _pumpCard(
  WidgetTester tester, {
  required int? signedDays,
  required bool isToday,
  Widget? bottomTrailing,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DailyCoverCard(
          cover: const GradientCover(0),
          headText: '神奇的西藏',
          title: '第一次去旅游',
          targetDay: '2019-05-08',
          signedDays: signedDays,
          isToday: isToday,
          bottomTrailing: bottomTrailing,
        ),
      ),
    ),
  );
}

void main() {
  group('scheduleLabel', () {
    test('不重复 + 没开提醒', () {
      expect(_daily(repeat: RepeatRule.none, remind: false).scheduleLabel, '不重复 · 不提醒');
    });

    test('每年 + 提前 3 天 09:00', () {
      expect(_daily().scheduleLabel, '每年 · 提前3天 09:00');
    });

    test('每月 + 当天，时刻补零', () {
      final d = _daily(repeat: RepeatRule.monthly, daysBefore: 0, hour: 8, minute: 5);
      expect(d.scheduleLabel, '每月 · 当天 08:05');
    });
  });

  group('卡片右下角', () {
    testWidgets('非当天：还是倒计时', (tester) async {
      await _pumpCard(tester, signedDays: 5, isToday: false);
      expect(find.text('还有 5 天'), findsOneWidget);
      expect(find.text('就是今天'), findsNothing);
    });

    testWidgets('当天：只说一次「就是今天」，由徽章说', (tester) async {
      await _pumpCard(tester, signedDays: 0, isToday: true);
      // 徽章那一圈呼吸光是循环动画，pumpAndSettle 会一直等下去
      await tester.pump();
      expect(find.text('就是今天'), findsOneWidget);
    });

    testWidgets('给了 bottomTrailing 就不画倒计时', (tester) async {
      await _pumpCard(
        tester,
        signedDays: 5,
        isToday: false,
        bottomTrailing: const Text('每年 · 不提醒'),
      );
      expect(find.text('每年 · 不提醒'), findsOneWidget);
      expect(find.text('还有 5 天'), findsNothing);
    });
  });

  group('详情页', () {
    testWidgets('右下角是重复 + 提醒，不是倒计时', (tester) async {
      await tester.pumpWidget(MaterialApp(home: HeroDetailPage(daily: _daily())));
      await tester.pumpAndSettle();

      expect(find.text('每年 · 提前3天 09:00'), findsOneWidget);
      expect(find.textContaining('还有'), findsNothing);
    });

    testWidgets('窄屏上状态行不省略，左边的日期也还在', (tester) async {
      // 这一行和日期挤在同一行里，`scheduleLabel` 的文案就是为它减肥的
      tester.view.physicalSize = const Size(360, 640) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(home: HeroDetailPage(daily: _daily())));
      await tester.pumpAndSettle();

      final label = tester.renderObject<RenderParagraph>(find.text('每年 · 提前3天 09:00'));
      expect(label.didExceedMaxLines, isFalse, reason: '状态行被省略号截断了，说明文案太长');
      expect(find.text('2019-05-08'), findsOneWidget);
    });

    testWidgets('起始日就是今天：中间说「从今天开始」，徽章说「就是今天」', (tester) async {
      final today = fmtStorage(DateTime.now());
      await tester.pumpWidget(
        MaterialApp(
          home: HeroDetailPage(
            daily: _daily(targetDay: today, repeat: RepeatRule.none, remind: false),
          ),
        ),
      );
      // 彩纸和呼吸光都是动画，pumpAndSettle 会等不停
      await tester.pump();

      expect(find.text('就是今天'), findsOneWidget);
      expect(find.text('从今天开始'), findsOneWidget);
      expect(find.text('不重复 · 不提醒'), findsOneWidget);
    });
  });
}
