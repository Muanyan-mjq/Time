import 'dart:async';

import 'package:daily/components/cover_view.dart';
import 'package:daily/components/empty_state.dart';
import 'package:daily/data/covers.dart';
import 'package:daily/data/daily_repository.dart';
import 'package:daily/model/cover.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/pages/daily_form.dart';
import 'package:daily/pages/detail/detail.dart';
import 'package:daily/styles/colors.dart';
import 'package:daily/styles/dimens.dart';
import 'package:daily/styles/iconfont.dart';
import 'package:daily/styles/text_style.dart';
import 'package:daily/utils/date_util.dart';
import 'package:daily/utils/haptics.dart';
import 'package:daily/utils/timeline_layout.dart';
import 'package:daily/utils/transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 时光轴：一条以今天为原点的横轴，过去在左、未来在右。
///
/// 首页回答「最近有什么事」，这一页回答「我这一段时间都攒了些什么」——
/// 所以它是独立一页，不是首页里的一段。首页一屏只放得下三条，
/// 三十条要滑十屏才看得完，那不叫「看大局」。
///
/// 默认整轴铺满一屏、今天钉在正中；双指放大后才谈得上「滑离今天」，
/// 那时顶部会浮出「回到今天」，底部那条细进度条告诉你视口在大局里的哪一段。
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> with SingleTickerProviderStateMixin {
  static const double _minScale = 1;
  static const double _maxScale = 8;

  /// 「回到今天」的定义：视口退到能看见整条轴。
  static const double _homeScale = 1;

  /// 当前缩放，以及屏幕正中落在轴的哪个坐标上（0 = 今天）。
  double _scale = 1;
  double _pan = 0;

  /// 手势开始时的值，用来把 `details.scale` 这类累计量换算成绝对值。
  double _scaleAtStart = 1;
  double _panAtStart = 0;
  double _drag = 0;

  /// 轴的半宽（最远那枚的偏移量），由布局约束决定。
  double _halfWidth = 1;

  /// 回位动画，只服务「回到今天」。
  late final AnimationController _reset = AnimationController(
    vsync: this,
    duration: kTransitionDuration,
  );

  @override
  void dispose() {
    _reset.dispose();
    super.dispose();
  }

  /// 视口半宽换算到轴坐标：放大 N 倍，能看见的轴区间就短 N 倍。
  double get _visibleHalf => _halfWidth / _scale;

  /// 不许把轴拖出视口 —— 缩放为 1 时能看见整条轴，这个上限自然是 0，
  /// 也就是「默认状态下拖不动」，这是对的：整条轴已经在屏幕上了。
  double _clampPan(double pan) {
    final limit = (_halfWidth - _visibleHalf).clamp(0.0, _halfWidth);
    return pan.clamp(-limit, limit);
  }

  bool get _atHome => _pan.abs() < 1 && (_scale - _homeScale).abs() < 0.01;

  void _onScaleStart(ScaleStartDetails details) {
    _scaleAtStart = _scale;
    _panAtStart = _pan;
    _drag = 0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final scale = (_scaleAtStart * details.scale).clamp(_minScale, _maxScale);
    _drag += details.focalPointDelta.dx;
    // 屏幕上的位移换算回轴坐标要除以缩放：放得越大，手指划过一根轴的
    // 比例越小。不除的话放大后一拖就飞出去了。
    final pan = _clampPan(_panAtStart - _drag / scale);
    if (scale == _scale && pan == _pan) return;
    setState(() {
      _scale = scale;
      _pan = pan;
    });
  }

  Future<void> _goHome() async {
    if (_atHome) return;
    unawaited(tapFeedback());
    final fromScale = _scale;
    final fromPan = _pan;
    void tick() {
      final t = kTransitionCurve.transform(_reset.value);
      setState(() {
        _scale = fromScale + (1 - fromScale) * t;
        _pan = fromPan * (1 - t);
      });
    }

    _reset.addListener(tick);
    await _reset.forward(from: 0);
    _reset.removeListener(tick);
    setState(() {
      _scale = 1;
      _pan = 0;
    });
  }

  Future<void> _openDetail(Daily daily) async {
    unawaited(tapFeedback());
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HeroDetailPage(daily: daily),
        fullscreenDialog: true,
      ),
    );
  }

  void _addFirst() {
    Navigator.of(context).pushReplacement(
      buildScaleRoute(page: const DailyFormPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.statusBarOf(context),
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildBar(context),
              Expanded(
                child: ValueListenableBuilder<List<Daily>>(
                  valueListenable: DailyRepository.instance.items,
                  builder: (context, dailies, _) => _buildAxis(context, dailies),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back_ios_new, size: 18, color: colors.onBackground),
            ),
          ),
          Text('时光轴', style: AppTextStyles.of(context).aboutMiddleStyle),
          const Spacer(),
          // 默认状态就在今天，这个按钮只在放大并滑走之后才有意义
          AnimatedOpacity(
            opacity: _atHome ? 0 : 1,
            duration: kTransitionDuration,
            curve: kTransitionCurve,
            child: IgnorePointer(
              ignoring: _atHome,
              child: TextButton(
                onPressed: _goHome,
                style: TextButton.styleFrom(foregroundColor: colors.onBackground),
                child: Text('回到今天', style: AppTextStyles.of(context).aboutStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAxis(BuildContext context, List<Daily> dailies) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _halfWidth = ((constraints.maxWidth - 2 * kTimelineSideMargin) / 2).clamp(1.0, 100000.0);
        final slots = timelineLayout(
          dailies,
          today: DateTime.now(),
          halfWidth: _halfWidth,
        );
        if (slots.isEmpty) return _buildEmpty(context);

        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;
        final todayX = centerX + (0 - _pan) * _scale;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildTodayLine(context, todayX, centerY),
                for (var i = 0; i < slots.length; i++)
                  _buildSlot(context, slots[i], i, centerX, centerY),
                _buildLegend(context),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: _buildViewportBar(context, constraints.maxWidth),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 今天那根竖线。它跟着缩放和平移走 —— 一旦放大，「今天」就不再落在屏幕
  /// 正中，这正是「回到今天」存在的理由。
  Widget _buildTodayLine(BuildContext context, double x, double centerY) {
    final colors = AppColors.of(context);
    return Positioned(
      left: x - 0.5,
      top: 0,
      bottom: 0,
      width: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.divider.withValues(alpha: 0),
              colors.divider,
              colors.divider.withValues(alpha: 0),
            ],
            stops: const [0, 0.5, 1],
          ),
        ),
      ),
    );
  }

  /// 轴上一枚：圆点压在轴上，一根短线牵到标签。
  ///
  /// 上下交错 + 同侧两档高度，是为了压住对数刻度的副作用 —— 越靠近今天
  /// 越挤。只交错不分档的话，1998 和 1999 两条的标题会叠在一起。
  Widget _buildSlot(
    BuildContext context,
    TimelineSlot slot,
    int index,
    double centerX,
    double centerY,
  ) {
    final styles = AppTextStyles.of(context);
    final screenX = centerX + (slot.x - _pan) * _scale;
    // 抽到屏幕外围的就不用建树了，三十条记录不至于每帧都画一遍
    final margin = kTimelineLabelWidth;
    if (screenX < -margin || screenX > centerX * 2 + margin) return const SizedBox.shrink();

    final above = index.isEven;
    final stem = kTimelineStem + (index ~/ 2) % 2 * kTimelineStemStep;
    final dot = kTimelineDot * slot.scale;
    final cover = resolveCover(
      coverKey: slot.daily.coverKey,
      imageUrl: slot.daily.imageUrl,
      locate: Covers.instance.locate,
    );

    final label = SizedBox(
      height: kTimelineLabelHeight,
      child: Column(
        mainAxisAlignment: above ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Text(
            slot.daily.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: styles.aboutStyle,
          ),
          Text(
            countdownLabel(slot.signedDays),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: styles.groupTitleStyle,
          ),
        ],
      ),
    );

    final content = [
      if (above) label else _buildDot(context, cover, dot),
      SizedBox(height: stem),
      if (above) _buildDot(context, cover, dot) else label,
    ];

    return Positioned(
      left: screenX - kTimelineLabelWidth / 2,
      // 圆点心必须落在轴上：上面那支的圆点在最后、下面那支的在最前，
      // 所以整盒的顶边各自退让半个圆
      top: above ? centerY - stem - kTimelineLabelHeight - dot / 2 : centerY - dot / 2,
      width: kTimelineLabelWidth,
      child: Opacity(
        opacity: slot.opacity,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openDetail(slot.daily),
          child: Column(mainAxisSize: MainAxisSize.min, children: content),
        ),
      ),
    );
  }

  Widget _buildDot(BuildContext context, Cover cover, double size) {
    // 圆点只有 15dp 上下，按它真正占的物理像素解码，别为这点大的圆圈
    // 把整张照片（最长边 1600）读进内存
    final decodeWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // 和底色同色的一圈，圆点压在轴线上时把那截线断开，像打了个孔
        border: Border.all(color: AppColors.of(context).background, width: 2),
      ),
      child: ClipOval(child: CoverView(cover: cover, decodeWidth: decodeWidth)),
    );
  }

  /// 左下角的图例。轴是抽象出来的，第一次看未必知道左边是过去。
  Widget _buildLegend(BuildContext context) {
    return Positioned(
      left: kTimelineSideMargin / 2,
      bottom: 34,
      child: Text('← 已过去　　未来 →', style: AppTextStyles.of(context).emptyHintStyle),
    );
  }

  /// 视口在大局里的位置：整条轨道就是 `[-halfWidth, +halfWidth]`，
  /// 高亮那一段是当前看得见的部分。放大之后它会缩成一个滑块。
  Widget _buildViewportBar(BuildContext context, double width) {
    final colors = AppColors.of(context);
    const trackWidth = 120.0;
    final scale = width <= 0 ? 1.0 : trackWidth / (2 * _halfWidth);
    final left = (trackWidth / 2 + (_pan - _visibleHalf) * scale).clamp(0.0, trackWidth);
    final right = (trackWidth / 2 + (_pan + _visibleHalf) * scale).clamp(0.0, trackWidth);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: trackWidth,
          height: 2,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: colors.divider)),
              Positioned(
                left: left,
                width: (right - left).clamp(0.0, trackWidth),
                top: 0,
                bottom: 0,
                child: ColoredBox(color: colors.onBackgroundMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return EmptyState(
      icon: Iconfont.daily,
      title: '还没有值得纪念的日子',
      hint: '记下第一天，这条轴就有了起点',
      action: TextButton(
        onPressed: _addFirst,
        style: TextButton.styleFrom(foregroundColor: colors.onBackground),
        child: Text('添加第一条', style: styles.aboutMiddleStyle),
      ),
    );
  }
}
