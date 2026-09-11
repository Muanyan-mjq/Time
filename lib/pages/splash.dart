import 'package:daily/components/time_mark.dart';
import 'package:daily/styles/colors.dart';
import 'package:daily/utils/transitions.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// 手写的启动动画，见 assets/lottie/splash.json。
const String kSplashAsset = 'assets/lottie/splash.json';

/// 动画时长，和 JSON 里的 72 帧 / 60fps 对应。
const Duration kSplashDuration = Duration(milliseconds: 1200);

/// 淡出时长。够短，让人感觉是「露出来」而不是「又等了一下」。
const Duration kSplashFade = Duration(milliseconds: 420);

/// 启动遮罩：压在首页上把动画完整播一遍，再淡出。
///
/// 做成覆盖层而不是一个独立路由 —— 独立路由得先把首页建出来再 push 上去，
/// 中间那一帧用户会看见首页闪一下。盖在上面则是首帧就在播动画，首页在底下
/// 安静地布局好，淡出时是「显出来」的。
///
/// 底色**恒为浅色**，不跟 App 的深色设置走：native 的 `launch_background`
/// 在 Dart 起来之前无从知道这个设置，只能是浅色底，遮罩要是走暗色，
/// 冷启动就会先浅后暗闪一下。深色用户看到的是「浅色启动 → 淡入深色首页」，
/// 衔接处有淡出过渡兜着。
///
/// 「至少播完一遍」是**结构上保证**的：列表在 `runApp` 之前就已经读完
/// （见 main.dart），所以这里不存在「数据先好了、动画被截断」的竞态。
class SplashGate extends StatefulWidget {
  final Widget child;

  const SplashGate({super.key, required this.child});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

/// 让底下的页面知道「遮罩还盖着」。
///
/// 首页的入场动画要等它 —— 否则卡片在遮罩底下就把错落入场演完了，
/// 揭开看到的是一屏静止的卡片。用 InheritedWidget 而不是全局变量：谁需要谁
/// 自己 `of(context)`，测试里没有这一层就当遮罩已经走了。
class SplashScope extends InheritedWidget {
  final bool covered;

  const SplashScope({super.key, required this.covered, required super.child});

  static bool coveredOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SplashScope>()?.covered ?? false;

  @override
  bool updateShouldNotify(SplashScope oldWidget) => covered != oldWidget.covered;
}

class _SplashGateState extends State<SplashGate> with TickerProviderStateMixin {
  /// 驱动 Lottie 的进度，顺带驱动那两行字的淡入。
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: kSplashDuration);

  /// 淡出用的进度：1 = 遮罩还实着，0 = 全透明。
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: kSplashFade, value: 1);

  bool _started = false;

  /// 是否还盖着画面。动画一播完就置 false —— 底下的入场动画和这里的淡出
  /// 因此是同时开演的一段连续动作，而不是「先淡出、再入场」两段。
  bool _covered = true;

  /// 淡出结束，遮罩可以从树上摘掉了。
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _anim.addStatusListener((status) {
      if (status == AnimationStatus.completed) _retire();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // 系统里关掉了动画：这层遮罩就只剩「让人干等」这一个作用了，跳过
    if (MediaQuery.disableAnimationsOf(context)) {
      _covered = false;
      _gone = true;
      return;
    }
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _fade.dispose();
    super.dispose();
  }

  Future<void> _retire() async {
    if (!mounted) return;
    setState(() => _covered = false);
    // 淡出期间不用再 setState：透明度由 `_fade` 自己驱动，走完再重建一次
    await _fade.reverse();
    if (!mounted) return;
    setState(() => _gone = true);
  }

  @override
  Widget build(BuildContext context) {
    return SplashScope(
      covered: _covered,
      // 结构必须稳定：`widget.child` 始终是 Stack 的第 0 个孩子。
      // 让它换个位置（比如去掉 Stack）会重建整棵子树，首页的状态和已经
      // 播了一半的入场动画都会被丢掉。
      child: Stack(
        children: [
          widget.child,
          if (!_gone)
            Positioned.fill(
              // 遮罩还看得见的时候，底下的卡片一下都不该被点到
              child: AbsorbPointer(
                absorbing: _covered,
                child: FadeTransition(
                  opacity: _fade,
                  child: ColoredBox(
                    color: AppColors.light.background,
                    child: Center(child: _buildMark()),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMark() {
    // 字比图形晚出场：先看见弧线画出来，再看见名字落下来
    final textIn = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.45, 1, curve: kTransitionCurve),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 168,
          height: 168,
          // 认不出这个文件时 Lottie 会画空白，不抛异常 —— 空白就是空白，
          // 这里不额外兜底，免得把「动画文件坏了」这件事藏起来
          child: Lottie.asset(kSplashAsset, controller: _anim, fit: BoxFit.contain),
        ),
        const SizedBox(height: 4),
        FadeTransition(
          opacity: textIn,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.22),
              end: Offset.zero,
            ).animate(textIn),
            child: const TimeWordmark(),
          ),
        ),
      ],
    );
  }
}
