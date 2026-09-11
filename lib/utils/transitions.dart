import 'package:flutter/material.dart';

/// 全 App 的转场手感。抽出来是因为首页的 `_pushScale` 和详情页的编辑入口
/// 本来各写各的，曲线和时长对不上，同一个 App 里出现了两种手感。
const Duration kTransitionDuration = Duration(milliseconds: 300);

const Curve kTransitionCurve = Curves.easeOutCubic;

/// 错落入场的相邻间隔。
const Duration kStaggerStep = Duration(milliseconds: 55);

/// 最多延迟到第几项。列表一长，第 20 项要等一秒多才出来，看着像卡顿 ——
/// 到这一项之后一起出现反而更干净。
const int kStaggerMaxIndex = 8;

/// 从 [alignment] 方向放大进入的页面转场。
///
/// 首页 FAB 弹出来的页面从右下角长出来，详情页的编辑从右上角长出来 ——
/// 起点贴着各自的入口，才不会让人找不到「刚才是从哪进去的」。
Route<T> buildScaleRoute<T>({
  required Widget page,
  Alignment alignment = Alignment.bottomRight,
}) {
  return PageRouteBuilder<T>(
    transitionDuration: kTransitionDuration,
    reverseTransitionDuration: kTransitionDuration,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: kTransitionCurve),
      alignment: alignment,
      child: child,
    ),
  );
}

/// 按 [index] 错开的一段淡入 + 上移。用于列表项和底部弹层的菜单项。
class StaggerIn extends StatelessWidget {
  final int index;

  /// 起始下移量（逻辑像素）。
  final double offset;
  final Widget child;

  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.offset = 14,
  });

  @override
  Widget build(BuildContext context) {
    final delay = kStaggerStep * index.clamp(0, kStaggerMaxIndex);
    final total = kTransitionDuration + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: kTransitionCurve,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, offset * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// 内容换值时，新内容从下方滚入。
///
/// 用在详情页那排大数字上：点一下在「年月日」和「总天数」之间切换时，
/// 比纯淡入更有翻页的实感，也比 2020 年那版靠 3 秒定时器轮播省电得多。
///
/// 刻意**不做出场动画**：两个视图尺寸位置完全重合，真要做交叉滚动就得把
/// 「上一个值」当状态留住；没有出场动画的观感损失很小，换来的是不用维护
/// 一份只服务于动画的旧数据。
class RollIn extends StatelessWidget {
  /// 值变一次，动画从头播一次。
  final Object value;
  final Widget child;

  /// 滚入的起始位移（逻辑像素）。够小才像「翻」而不是「飞」。
  static const double _offset = 22;

  const RollIn({super.key, required this.value, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // key 跟着值走：值一变就是一棵新树，动画自然从头播
      key: ValueKey(value),
      tween: Tween(begin: 0, end: 1),
      duration: kTransitionDuration,
      curve: kTransitionCurve,
      child: child,
      builder: (context, t, child) => ClipRect(
        child: Transform.translate(
          offset: Offset(0, (1 - t) * _offset),
          child: Opacity(opacity: t, child: child),
        ),
      ),
    );
  }
}
