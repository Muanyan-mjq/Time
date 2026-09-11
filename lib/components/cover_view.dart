import 'dart:io';

import 'package:daily/data/cover_palette.dart';
import 'package:daily/model/cover.dart';
import 'package:flutter/material.dart';

/// 把 [Cover] 画出来。合并了老代码的 file_image.dart 和 placeholder_image.dart
/// —— 网络占位图的活已经没有了。
class CoverView extends StatelessWidget {
  final Cover cover;
  final BoxFit fit;

  /// 解码宽度（物理像素）。列表里的小图没必要按原图解码：相册照片最长边
  /// 1600，一张进内存就是 10MB，时光轴 15px 的圆点也照单全收的话，滚动时
  /// 反复冲 ImageCache。null = 保持原尺寸（详情页、海报这类大图）。
  final int? decodeWidth;

  const CoverView({
    super.key,
    required this.cover,
    this.fit = BoxFit.cover,
    this.decodeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return switch (cover) {
      // gaplessPlayback：Hero 飞行途中重建时不会闪一下白
      PhotoCover(:final path) => Image.file(
          File(path),
          fit: fit,
          cacheWidth: decodeWidth,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _GradientFallback(index: 0),
        ),
      GradientCover(:final index) => _GradientFallback(index: index),
    };
  }
}

class _GradientFallback extends StatelessWidget {
  final int index;

  const _GradientFallback({required this.index});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(gradient: gradientFor(index)),
        child: const SizedBox.expand(),
      );
}
