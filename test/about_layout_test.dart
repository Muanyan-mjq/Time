import 'package:daily/pages/about/about.dart';
import 'package:daily/styles/dimens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 关于页整页是绝对定位摆出来的，行数只会越加越多 —— 设置栏从 5 行涨到
/// 6 行那次就把它顶进了上面那两行版本号里，而这一栏是后画的，会直接盖上去。
///
/// 这里钉住三件事：矮屏上不许压到版本号（也不许顶出黄黑条），高屏上的位置
/// 和设计稿一致（贴着底边，不在中间浮着），以及那一栏里到底剩几个开关 ——
/// 「深色模式」已经删掉（首页弹层里有），行数得对上。
Future<void> _pumpAbout(
  WidgetTester tester, {
  required Size logicalSize,
  required double bottomPadding,
}) async {
  const dpr = 3.0;
  tester.view.physicalSize = logicalSize * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = FakeViewPadding(bottom: bottomPadding * dpr);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: About()));
  await tester.pump();
}

void main() {
  testWidgets('高屏：设置栏还是贴着底边，没有被顶到中间', (tester) async {
    await _pumpAbout(tester, logicalSize: const Size(393, 873), bottomPadding: 24);

    expect(tester.takeException(), isNull);
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    expect(viewport.top, kAboutSettingsTop);
    expect(viewport.bottom, 873 - 24 - kAboutSettingsBottom);

    // 内容比视口矮（192 对 429），reverse 让它贴住底边 —— 不 reverse 会
    // 贴着顶边，那一栏就浮在屏幕中间了。滑块那一行有 48 高，是行里最高的
    // 一个，所以它的底边就是整栏的底边
    final lastRow = tester.getRect(find.byType(Switch).last);
    expect(lastRow.bottom, closeTo(viewport.bottom, 1));
  });

  testWidgets('矮屏：设置栏被上边界拦住，不会盖住版本号', (tester) async {
    await _pumpAbout(tester, logicalSize: const Size(360, 640), bottomPadding: 48);

    expect(tester.takeException(), isNull);
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    final version = tester.getRect(find.text('这是一款能够留住时光的APP'));

    expect(viewport.top, greaterThanOrEqualTo(version.bottom), reason: '设置栏压到版本号上了');
    expect(viewport.bottom, 640 - 48 - kAboutSettingsBottom);
    expect(viewport.height, greaterThan(0));

    // 这一栏确实装不下（5 行 192 对 172），被切掉一点的是最上面那个装饰性
    // 入口；两个开关都还看得见，而且仍然贴着底边 —— 矮屏上最要紧的部分不能先丢
    expect(tester.getTopLeft(find.text('功能介绍')).dy, lessThan(viewport.top));
    expect(tester.getRect(find.byType(Switch).last).bottom, closeTo(viewport.bottom, 1));
  });

  testWidgets('设置栏里只剩两个开关，三个页脚链接各是一个', (tester) async {
    await _pumpAbout(tester, logicalSize: const Size(393, 873), bottomPadding: 24);

    expect(tester.takeException(), isNull);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(find.text('通知栏倒计时'), findsOneWidget);
    expect(find.text('隐私锁'), findsOneWidget);
    // 首页那个弹层里已经有一个深色模式开关，关于页再摆一个就是两个入口
    expect(find.text('深色模式'), findsNothing);

    // 以前三个名字挤在一个 GestureDetector 里，点哪儿都跳仓库首页
    expect(find.text('隐私协议'), findsOneWidget);
    expect(find.text('软件使用协议'), findsOneWidget);
    expect(find.text('官方地址'), findsOneWidget);
  });
}
