import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 六套渐变，下标与原 App 的六个分类一一对应：
/// 恋爱 / 家人 / 朋友 / 工作 / 学习 / 生日。
///
/// 这些颜色是照 2020 年那 6 张 CDN 图的色调定的，不是随手取的。
const List<({String name, List<Color> colors})> kCoverGradients = [
  (name: '恋爱', colors: [Color(0xFFF48FB1), Color(0xFFC2185B)]),
  (name: '家人', colors: [Color(0xFFFFCC80), Color(0xFFE65100)]),
  (name: '朋友', colors: [Color(0xFF80CBC4), Color(0xFF00695C)]),
  (name: '工作', colors: [Color(0xFF90CAF9), Color(0xFF1565C0)]),
  (name: '学习', colors: [Color(0xFFB39DDB), Color(0xFF4527A0)]),
  (name: '生日', colors: [Color(0xFFFFAB91), Color(0xFFBF360C)]),
];

/// 渐变封面的代号前缀，存进 coverKey。
const String kGradientPrefix = 'g:';

/// 照片封面的代号前缀。
const String kPhotoPrefix = 'f:';

/// 渐变背景，用于卡片与海报的兜底。
LinearGradient gradientFor(int index) {
  final g = kCoverGradients[_clampIndex(index)];
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: g.colors,
  );
}

/// 越界一律夹取，绝不当场抛异常 —— 这个下标可能来自用户手改过的数据库。
int _clampIndex(int index) => index.isNaN ? 0 : math.min(math.max(index, 0), kCoverGradients.length - 1);

/// 渐变代号取名字，用于表单里的选择器。
String gradientName(int index) => kCoverGradients[_clampIndex(index)].name;
