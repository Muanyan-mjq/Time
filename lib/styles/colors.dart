import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 全 App 的调色板，亮暗各一套。
///
/// 亮色就是 2020 年那版的取值 —— 它就是设计语言本身，颜色一个都没改。
/// 变的只是载体：从 `static const` 变成实例字段，好让两套并存。
///
/// 亮色底必须**不透明**：它要和 native 的 `@color/app_background` 逐字一致，
/// 否则从启动图切到首帧会闪一下。老代码写的是 6% 透明度的灰
/// （`Color.fromRGBO(189,195,199,0.06)`），叠在 Flutter 画布的黑底上会被算成
/// (11,12,12) —— 那才是「首页看着是黑的」的根因，不是配色选择，是合成错误。
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.sheet,
    required this.buttonPrimary,
    required this.onButtonPrimary,
    required this.onBackground,
    required this.onBackgroundMuted,
    required this.onBackgroundFaint,
    required this.divider,
    required this.highlight,
    required this.aboutArc,
    required this.aboutBlob,
  });

  /// 页面底色
  final Color background;

  /// 卡片、输入框、弹窗的底板
  final Color surface;

  /// 底部弹层（FAB 菜单、封面选择）的底板
  final Color sheet;

  /// 主按钮：FAB 和底部那颗大按钮
  final Color buttonPrimary;

  /// 主按钮上的文字与图标
  final Color onButtonPrimary;

  /// 正文里的强文字与图标
  final Color onBackground;

  /// 次要文字与图标
  final Color onBackgroundMuted;

  /// 最弱的一档：骨架转圈、空态图标
  final Color onBackgroundFaint;

  /// 分割线
  final Color divider;

  /// 选中态描边
  final Color highlight;

  /// 关于页右上角那道弧
  final Color aboutArc;

  /// 关于页左下角那团圆斑
  final Color aboutBlob;

  static const AppColors light = AppColors(
    background: Color(0xFFFBFBFC),
    surface: Color(0xFFFFFFFF),
    sheet: Color(0xFFF5F5F5),
    buttonPrimary: Color(0xFF000000),
    onButtonPrimary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF333333),
    onBackgroundMuted: Color(0xFF757575),
    onBackgroundFaint: Color(0xFFBDBDBD),
    divider: Color(0xFFDBDBDB),
    highlight: Color(0xFF000000),
    // 2020 年那版的取值，原样
    aboutArc: Color.fromRGBO(93, 92, 238, 0.9),
    aboutBlob: Color(0xFF21FFD9),
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    sheet: Color(0xFF1E1E1E),
    buttonPrimary: Color(0xFFEDEDED),
    onButtonPrimary: Color(0xFF121212),
    onBackground: Color(0xFFEDEDED),
    onBackgroundMuted: Color(0xFF9A9A9F),
    onBackgroundFaint: Color(0xFF5A5A5E),
    divider: Color(0xFF2E2E2E),
    highlight: Color(0xFFEDEDED),
    // 同一组色相，只把饱和度压下去：原值叠在 #121212 上是一道刺眼的霓虹，
    // 而这两块是背景装饰，不该比正文还抢眼
    aboutArc: Color.fromRGBO(93, 92, 238, 0.35),
    aboutBlob: Color.fromRGBO(33, 255, 217, 0.22),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// 状态栏图标该亮还是该暗。浅底上必须用深色图标，反之亦然 ——
  /// 首页是浅底，详情页顶部是大图，两边的取值本来就不一样。
  static SystemUiOverlayStyle statusBarOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark;
}
