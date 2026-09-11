import 'package:daily/model/daily.dart';
import 'package:daily/pages/poster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 海报从「一条记录一张」变成「一叠，左右滑着挑」之后，翻页这件事本身
/// 得有人守：打开时停在哪张、滑不滑得动、指示器什么时候从圆点换成
/// 「1 / 9」。这三件事不落在任何一个纯函数上，只能用组件测试钉。

List<Daily> _dailies(int count) => [
      for (var i = 0; i < count; i++)
        Daily(
          id: i + 1,
          title: '记录${i + 1}',
          headText: '副标题${i + 1}',
          targetDay: '2020-01-${(i % 9) + 1}',
          remark: '',
          // 渐变封面不走 Covers.locate，测试里不用起临时目录
          coverKey: 'g:${i % 6}',
        ),
    ];

Future<void> _pump(
  WidgetTester tester, {
  required List<Daily> dailies,
  int initialIndex = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(home: PosterPage(dailies: dailies, initialIndex: initialIndex)),
  );
  await tester.pump();
}

/// 圆点指示器的数量。页面上只有它画圆形 DecoratedBox ——
/// 海报自己的两层背景都是矩形渐变的 DecoratedBox。
int _dots(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .where((w) =>
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle)
    .length;

/// 翻一页。PageView 只有当前页会被建出来，所以判断「翻过去了」看的是内容。
Future<void> _flip(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-600, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('打开时停在指定的那张', (tester) async {
    await _pump(tester, dailies: _dailies(3), initialIndex: 2);

    expect(find.text('记录3'), findsOneWidget);
    expect(find.text('记录1'), findsNothing);
  });

  testWidgets('initialIndex 超过末页：夹到最后一张', (tester) async {
    await _pump(tester, dailies: _dailies(2), initialIndex: 99);

    expect(find.text('记录2'), findsOneWidget);
  });

  testWidgets('initialIndex 是负数：夹回第一张', (tester) async {
    await _pump(tester, dailies: _dailies(2), initialIndex: -3);

    expect(find.text('记录1'), findsOneWidget);
  });

  testWidgets('往左滑切到下一张', (tester) async {
    await _pump(tester, dailies: _dailies(3));
    expect(find.text('记录1'), findsOneWidget);

    await _flip(tester);

    expect(find.text('记录2'), findsOneWidget);
    expect(find.text('记录1'), findsNothing);
  });

  testWidgets('空列表只渲染一张宣传卡，没有页码提示', (tester) async {
    await _pump(tester, dailies: const []);

    expect(find.text('每一个平凡的日子，都值得纪念'), findsOneWidget);
    expect(_dots(tester), 0);
    expect(find.textContaining(' / '), findsNothing);
  });

  testWidgets('8 张用圆点，翻页后还是 8 个', (tester) async {
    await _pump(tester, dailies: _dailies(8));
    expect(_dots(tester), 8);
    expect(find.textContaining(' / '), findsNothing);

    await _flip(tester);

    expect(find.text('记录2'), findsOneWidget);
    expect(_dots(tester), 8);
  });

  testWidgets('9 张换成「1 / 9」，翻页后跟着走', (tester) async {
    await _pump(tester, dailies: _dailies(9));
    expect(find.text('1 / 9'), findsOneWidget);
    expect(_dots(tester), 0);

    await _flip(tester);

    expect(find.text('2 / 9'), findsOneWidget);
  });
}
