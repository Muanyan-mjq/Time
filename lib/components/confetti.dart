import 'package:flutter/material.dart';

/// 纪念日当天的彩纸。一次性播完就停，不循环、不引依赖、不自绘图片。
///
/// 用固定的散列而不是自由随机：同一条记录每次进来看到的彩纸是同一场，
/// 截图不会每次都变，也不用为了可复现去注入一个 Random。
class ConfettiBurst extends StatefulWidget {
  /// 播一次多久。900ms 是「够看清、又不挡住大数字」的长度。
  static const Duration duration = Duration(milliseconds: 900);

  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ConfettiBurst.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          // 播完就把画布摘掉：留着它也不会再画，但没必要让详情页永远挂一个
          // 已经完成的 painter
          if (_controller.isCompleted) return const SizedBox.shrink();
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(t: _controller.value),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;

  _ConfettiPainter({required this.t});

  /// 白色为主，金 / 粉 / 浅蓝各一点 —— 卡片上的字已经够满了，
  /// 彩纸再花就糊成一片。
  static const List<Color> _colors = [
    Color(0xFFFFFFFF),
    Color(0xFFF3F3F3),
    Color(0xFFFFD873),
    Color(0xFFFFB4C8),
    Color(0xFFB8E0FF),
  ];

  static const int _count = 26;

  @override
  void paint(Canvas canvas, Size size) {
    // 位移全部按画布尺寸换算，所以同一个 painter 在 460 高的详情页和
    // 别的地方都成立
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    for (var i = 0; i < _count; i++) {
      final x0 = _unit(i, 1) * w;
      final vx = (_unit(i, 3) - 0.5) * w * 0.36;
      final vy = (0.55 + _unit(i, 2) * 0.45) * h * 1.15;
      final spin = (_unit(i, 4) - 0.5) * 16;
      // 起手就散开一点，不然前 100ms 全挤在上边缘一条线上
      final local = (t + _unit(i, 5) * 0.12).clamp(0.0, 1.0);

      final dx = x0 + vx * local;
      final dy = -20 + vy * local;
      // 最后三成时间淡出
      final alpha = 1 - ((local - 0.7) / 0.3).clamp(0.0, 1.0);

      paint.color = _colors[i % _colors.length].withValues(alpha: alpha * 0.9);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(spin * local);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 5, height: 9),
          const Radius.circular(1.2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  /// 第 [i] 条彩纸的第 [salt] 个参数，落在 [0, 1)。
  ///
  /// 每个参数单独散列，而不是把一个整数切几位出来用 —— 切位会让高位参数
  /// 退化成只有一两个取值，所有彩纸的旋转就变成两个角度了。
  static double _unit(int i, int salt) => (_hash(i * 31 + salt) % 10000) / 10000.0;

  /// 一个够用的整数散列（xorshift 混合），把序号打散成互不相关的初值。
  static int _hash(int i) {
    var x = i * 2654435761;
    x ^= x >> 13;
    x *= 1274126177;
    x ^= x >> 16;
    return x & 0x7FFFFFFF;
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
