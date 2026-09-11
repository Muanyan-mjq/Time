import 'dart:async';
import 'dart:io';

import 'package:daily/utils/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 全屏看大图。只有封面是真的照片时才进得来 —— 渐变是代码画的，
/// 放大没有任何信息量。
///
/// 纯黑底，因为这是在看照片：周围任何一点颜色都会影响对照片的判断。
class PhotoViewPage extends StatefulWidget {
  /// 磁盘上的绝对路径。
  final String path;

  /// 从详情页卡片飞过来的 Hero tag。必须和详情页那枚不同 ——
  /// 详情页还留在树上，两枚同名 Hero 会直接触发框架断言。
  final String heroTag;

  const PhotoViewPage({super.key, required this.path, required this.heroTag});

  @override
  State<PhotoViewPage> createState() => _PhotoViewPageState();
}

class _PhotoViewPageState extends State<PhotoViewPage> with SingleTickerProviderStateMixin {
  static const double _maxScale = 4;
  static const double _doubleTapScale = 2.5;

  /// 下滑超过这个距离就退出。
  static const double _dismissDistance = 110;

  final TransformationController _transformation = TransformationController();

  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnimation;

  /// 当前缩放倍数。用来决定「这一下拖动是看图的平移，还是退出的手势」。
  double _scale = 1;

  /// 本次手势已经下滑了多少。放大状态下始终是 0。
  double _dragDown = 0;

  /// 双击的落点，缩放要以它为中心。
  Offset _doubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_onTransformChanged);
    _zoom.addListener(() {
      final anim = _zoomAnimation;
      if (anim != null) _transformation.value = anim.value;
    });
  }

  @override
  void dispose() {
    _transformation.removeListener(_onTransformChanged);
    _transformation.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final next = _transformation.value.getMaxScaleOnAxis();
    if (next == _scale) return;
    setState(() => _scale = next);
  }

  @override
  Widget build(BuildContext context) {
    // 退出过程中整页跟着手指往下走，同时淡出 —— 不这么做的话松手回弹
    // 会显得像卡了一下
    final progress = (_dragDown / 400).clamp(0.0, 1.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Transform.translate(
          offset: Offset(0, _dragDown),
          child: Opacity(
            opacity: 1 - progress * 0.6,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    // 双击在 1× 和 2.5× 之间切换，落点居中于手指
                    onDoubleTapDown: _focus,
                    onDoubleTap: _toggleZoom,
                    child: InteractiveViewer(
                      transformationController: _transformation,
                      minScale: 1,
                      maxScale: _maxScale,
                      // 1× 时不给平移：这时候图片正好铺满，任何平移都是
                      // 「想退出」而不是「想看别处」
                      panEnabled: _scale > 1.01,
                      onInteractionStart: (_) => _dragDown = 0,
                      onInteractionUpdate: _onInteractionUpdate,
                      onInteractionEnd: (_) => _endDrag(),
                      child: Hero(
                        tag: widget.heroTag,
                        // 必须是 expand 而不是按图片原始尺寸撑开：Hero 飞行时
                        // 会把目标子节点按「插值矩形」当紧约束重新布局，
                        // 给一张 4000px 的图松约束，飞行就会放大到离谱的尺寸
                        child: SizedBox.expand(
                          child: Image.file(File(widget.path), fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 4,
                  right: 6,
                  child: _buildCloseButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: const SizedBox(
        width: 44,
        height: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Color(0x73000000), Color(0x00000000)]),
          ),
          child: Icon(Icons.close, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  /// 下滑退出走 `InteractiveViewer` 自己的回调，而不是在外面再套一个
  /// 拖动识别器。
  ///
  /// 手势竞技场里子节点先注册、先获胜，外面那个垂直拖动永远收不到事件；
  /// 而 1× 时 `InteractiveViewer` 的位移本来就被边界夹成 0，图片不会跟着动。
  /// 于是这里只是借它的回调读原始位移，视觉位移由我们自己画。
  void _onInteractionUpdate(ScaleUpdateDetails details) {
    if (_scale > 1.01) {
      // 放大之后，往下拖是看图片的上半部分，不是退出
      if (_dragDown != 0) setState(() => _dragDown = 0);
      return;
    }
    // 双指捏合时的 focalPointDelta 也在动，但那种情况 _scale 已经变了
    final next = _dragDown + details.focalPointDelta.dy;
    // 只认往下的方向：往上拖是想看状态栏，不该触发退出
    setState(() => _dragDown = next <= 0 ? 0 : next);
  }

  void _endDrag() {
    final shouldPop = _dragDown > _dismissDistance;
    setState(() => _dragDown = 0);
    if (shouldPop) Navigator.pop(context);
  }

  void _focus(TapDownDetails details) => _doubleTapPosition = details.localPosition;

  void _toggleZoom() {
    unawaited(tapFeedback());
    final begin = _transformation.value;
    final target = _scale > 1.01 ? 1.0 : _doubleTapScale;
    final p = _doubleTapPosition;
    // 让手指底下那一点在缩放前后停在原地：先把画布平移 -p*(s-1)，再缩放
    final end = target == 1.0
        ? Matrix4.identity()
        : Matrix4.translationValues(-p.dx * (target - 1), -p.dy * (target - 1), 0)
            .multiplied(Matrix4.diagonal3Values(target, target, 1));
    _zoomAnimation = Matrix4Tween(begin: begin, end: end).animate(
      CurvedAnimation(parent: _zoom, curve: Curves.easeOutCubic),
    );
    _zoom.forward(from: 0);
  }
}
