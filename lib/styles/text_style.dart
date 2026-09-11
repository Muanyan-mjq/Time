import 'package:flutter/material.dart';

/// 全 App 的文字样式。
///
/// 分两类，界限是「这段文字贴在照片上吗」：
///
/// * 贴封面的 8 个（`titleTextStyle` 那一组）**永远是白色**，写成 `static const`。
///   它们画在用户照片或渐变上，底色不可控，跟随主题只会把白字变成灰字、
///   在深色照片上彻底读不出来。所以它们不参与主题切换。
/// * 其余 15 个跟随主题，取法从 `AppTextStyles.foo` 改成
///   `AppTextStyles.of(context).foo`。
///
/// 亮色取值全部是 2020 年那版的原样。
class AppTextStyles {
  const AppTextStyles({
    required this.appTitle,
    required this.appTip,
    required this.contentStyle,
    required this.inputLabelStyle,
    required this.inputHintStyle,
    required this.inputValueStyle,
    required this.deleteStyle,
    required this.aboutStyle,
    required this.aboutMiddleStyle,
    required this.aboutBottomStyle,
    required this.shareTitleStyle,
    required this.groupTitleStyle,
    required this.emptyTitleStyle,
    required this.emptyHintStyle,
    required this.primaryButtonStyle,
  });

  /// APP Title
  final TextStyle appTitle;

  /// APP Welcome
  final TextStyle appTip;

  /// (Daily detail Content) BottomTip
  final TextStyle contentStyle;

  /// (Daily add Input label) label
  final TextStyle inputLabelStyle;

  /// (Daily add Input hint) hint
  final TextStyle inputHintStyle;

  /// (Daily add Input value) value
  final TextStyle inputValueStyle;

  /// Daily delete
  final TextStyle deleteStyle;

  /// Daily about
  final TextStyle aboutStyle;

  /// Daily about
  final TextStyle aboutMiddleStyle;

  /// Daily about
  final TextStyle aboutBottomStyle;

  /// Daily share
  final TextStyle shareTitleStyle;

  /// 首页分组标题「未来 · 3」
  final TextStyle groupTitleStyle;

  /// 空态主文案
  final TextStyle emptyTitleStyle;

  /// 空态引导
  final TextStyle emptyHintStyle;

  /// 主要按钮（表单底部「保存」、锁屏「解锁」）上的文字。
  ///
  /// 底色一律是 `buttonPrimary`，所以字色取配对的 `onButtonPrimary` ——
  /// 亮色是黑底白字，暗色整个翻过来。这两个值必须和 AppColors 里那对保持
  /// 一致：它们不在同一个文件里，改一个就得改另一个。
  final TextStyle primaryButtonStyle;

  static const AppTextStyles light = AppTextStyles(
    appTitle: TextStyle(
      fontSize: 30,
      color: Colors.black87,
      fontWeight: FontWeight.bold,
      fontFamily: 'Conspired',
    ),
    appTip: TextStyle(
      fontSize: 14,
      color: Colors.black54,
      fontWeight: FontWeight.w100,
      fontFamily: 'Dongqing',
    ),
    contentStyle: TextStyle(
      height: 1.5,
      fontSize: 16,
      letterSpacing: 1.0,
      color: Color(0xFF666666),
      fontWeight: FontWeight.w200,
      fontFamily: 'Dongqing',
    ),
    inputLabelStyle: TextStyle(
      fontSize: 16,
      color: Color(0xFF333333),
      fontWeight: FontWeight.w100,
      fontFamily: 'Dongqing',
    ),
    inputHintStyle: TextStyle(
      fontSize: 15,
      color: Color(0xFF666666),
      fontFamily: 'Dongqing',
    ),
    inputValueStyle: TextStyle(
      fontSize: 16,
      color: Color(0xFF333333),
      fontFamily: 'Dongqing',
    ),
    deleteStyle: TextStyle(
      color: Color(0xFF333333),
      fontSize: 14,
      fontWeight: FontWeight.w100,
      fontFamily: 'Dongqing',
    ),
    aboutStyle: TextStyle(
      color: Color(0xFF333333),
      fontSize: 14,
      fontWeight: FontWeight.w100,
      fontFamily: 'Dongqing',
    ),
    aboutMiddleStyle: TextStyle(
      color: Color(0xFF333333),
      fontSize: 16,
      fontWeight: FontWeight.w100,
      fontFamily: 'Dongqing',
    ),
    aboutBottomStyle: TextStyle(
      color: Color(0xFF333333),
      fontSize: 12,
      fontWeight: FontWeight.w100,
      fontFamily: 'Dongqing',
    ),
    shareTitleStyle: TextStyle(
      color: Color(0xFF333333),
      fontSize: 16,
      fontWeight: FontWeight.w400,
      fontFamily: 'Dongqing',
    ),
    groupTitleStyle: TextStyle(
      fontSize: 13,
      color: Colors.black54,
      fontWeight: FontWeight.w300,
      letterSpacing: 1.5,
      fontFamily: 'Dongqing',
    ),
    emptyTitleStyle: TextStyle(
      fontSize: 17,
      color: Colors.black54,
      fontWeight: FontWeight.w300,
      letterSpacing: 1.0,
      fontFamily: 'Dongqing',
    ),
    emptyHintStyle: TextStyle(
      fontSize: 13,
      color: Colors.black38,
      fontWeight: FontWeight.w200,
      fontFamily: 'Dongqing',
    ),
    primaryButtonStyle: TextStyle(
      fontSize: 16,
      color: Color(0xFFFFFFFF),
      fontWeight: FontWeight.w500,
    ),
  );

  static const AppTextStyles dark = AppTextStyles(
    appTitle: TextStyle(
      fontSize: 30,
      color: Color(0xFFEDEDED),
      fontWeight: FontWeight.bold,
      fontFamily: 'Conspired',
    ),
    appTip: TextStyle(
      fontSize: 14,
      color: Color(0xFF9A9A9F),
      fontWeight: FontWeight.w100,
      fontFamily: 'Dongqing',
    ),
    contentStyle: TextStyle(
      height: 1.5,
      fontSize: 16,
      letterSpacing: 1.0,
      color: Color(0xFFB4B4B9),
      fontWeight: FontWeight.w200,
      fontFamily: 'Dongqing',
    ),
    inputLabelStyle: TextStyle(
      fontSize: 16,
      color: Color(0xFFEDEDED),
      fontWeight: FontWeight.w100,
      fontFamily: 'Dongqing',
    ),
    inputHintStyle: TextStyle(
      fontSize: 15,
      color: Color(0xFF7A7A80),
      fontFamily: 'Dongqing',
    ),
    inputValueStyle: TextStyle(
      fontSize: 16,
      color: Color(0xFFEDEDED),
      fontFamily: 'Dongqing',
    ),
    deleteStyle: TextStyle(
      color: Color(0xFFEDEDED),
      fontSize: 14,
      fontWeight: FontWeight.w100,
      fontFamily: 'Dongqing',
    ),
    aboutStyle: TextStyle(
      color: Color(0xFFEDEDED),
      fontSize: 14,
      fontWeight: FontWeight.w100,
      fontFamily: 'Dongqing',
    ),
    aboutMiddleStyle: TextStyle(
      color: Color(0xFFEDEDED),
      fontSize: 16,
      fontWeight: FontWeight.w100,
      fontFamily: 'Dongqing',
    ),
    aboutBottomStyle: TextStyle(
      color: Color(0xFFEDEDED),
      fontSize: 12,
      fontWeight: FontWeight.w100,
      fontFamily: 'Dongqing',
    ),
    shareTitleStyle: TextStyle(
      color: Color(0xFFEDEDED),
      fontSize: 16,
      fontWeight: FontWeight.w400,
      fontFamily: 'Dongqing',
    ),
    groupTitleStyle: TextStyle(
      fontSize: 13,
      color: Color(0xFF9A9A9F),
      fontWeight: FontWeight.w300,
      letterSpacing: 1.5,
      fontFamily: 'Dongqing',
    ),
    emptyTitleStyle: TextStyle(
      fontSize: 17,
      color: Color(0xFF9A9A9F),
      fontWeight: FontWeight.w300,
      letterSpacing: 1.0,
      fontFamily: 'Dongqing',
    ),
    emptyHintStyle: TextStyle(
      fontSize: 13,
      color: Color(0xFF6E6E73),
      fontWeight: FontWeight.w200,
      fontFamily: 'Dongqing',
    ),
    primaryButtonStyle: TextStyle(
      fontSize: 16,
      color: Color(0xFF121212),
      fontWeight: FontWeight.w500,
    ),
  );

  static AppTextStyles of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  // —— 以下永远白色：它们贴在照片/渐变封面上，不参与主题切换 ——

  /// Daily title
  static const TextStyle titleTextStyle = TextStyle(
    fontSize: 30,
    color: Colors.white,
    fontFamily: 'Dongqing',
  );

  /// Daily headText
  static const TextStyle headTextStyle = TextStyle(
    fontSize: 16,
    color: Colors.white,
    fontFamily: 'Dongqing',
  );

  /// Daily targetDay
  static const TextStyle targetDayStyle = TextStyle(
    fontSize: 16,
    color: Colors.white,
    fontFamily: 'Dongqing',
  );

  /// (Daily countYear countMonth countDay countTotalDay) Title
  static const TextStyle countTitleStyle = TextStyle(
    fontSize: 24,
    color: Colors.white,
    fontWeight: FontWeight.w500,
    fontFamily: 'Dongqing',
  );

  /// (Daily countYear countMonth countDay countTotalDay) BottomTip
  static const TextStyle countBottomTipStyle = TextStyle(
    fontSize: 16,
    color: Colors.white,
    fontWeight: FontWeight.w200,
    fontFamily: 'Dongqing',
  );

  /// (Daily add Select cateGoryText) cateGoryText
  static const TextStyle cateGoryTextStyle = TextStyle(
    fontSize: 24,
    color: Colors.white,
    fontWeight: FontWeight.w100,
    fontFamily: 'Dongqing',
  );

  /// Daily chooseImage
  static const TextStyle chooseImageStyle = TextStyle(
    fontSize: 14,
    color: Colors.white,
    fontWeight: FontWeight.w200,
    fontFamily: 'Dongqing',
  );

  /// 首页卡片的「已经 N 天 / 还有 N 天」
  static const TextStyle countdownStyle = TextStyle(
    fontSize: 15,
    color: Colors.white,
    fontWeight: FontWeight.w300,
    letterSpacing: 0.5,
    fontFamily: 'Dongqing',
  );
}
