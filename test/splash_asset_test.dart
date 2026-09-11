import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

/// 启动动画是手写的 JSON，没有设计工具兜底 —— 一个多余的分号、一个拼错的
/// 类型名（比如把 `el` 写成 `ellipse`）在真机上就是一片空白，而且不报错。
/// 这两个测试把「能解析」和「画得出来」钉住。
const String _asset = 'assets/lottie/splash.json';

void main() {
  test('手写的 Lottie 能被解析，时长 1.2 秒', () async {
    final data = await rootBundle.load(_asset);
    final composition = await LottieComposition.fromByteData(data);

    expect(composition.startFrame, 0);
    // 72 帧 / 60fps = 1.2 秒。帧号经过一次「除帧率再乘回来」的往返，会有末位误差
    expect(composition.endFrame, closeTo(72, 0.02));
    expect(composition.frameRate, closeTo(60, 0.01));
    expect(composition.duration.inMilliseconds, 1200);
  });

  test('两层都在：青色圆点 + 靛蓝圆弧', () async {
    final data = await rootBundle.load(_asset);
    final composition = await LottieComposition.fromByteData(data);
    expect(composition.layers.map((l) => l.name), ['dot', 'arc']);
  });

  testWidgets('能画出来且不抛异常', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 220,
          height: 220,
          child: Lottie.asset(_asset, repeat: false),
        ),
      ),
    ));

    // 播到动画中段和结尾各看一次：起止帧正常不代表中间不炸
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
  });
}
