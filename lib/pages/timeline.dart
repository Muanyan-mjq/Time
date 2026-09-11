import 'dart:async';
import 'dart:ui' as ui;

import 'package:daily/components/cover_view.dart';
import 'package:daily/components/empty_state.dart';
import 'package:daily/data/cover_palette.dart';
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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 时光轴：一条竖着的时间轴，未来在上、今天一道横标、过去在下。
///
/// 首页回答「最近有什么事」，这一页回答「我这一段时间都攒了些什么」——
/// 所以它是独立一页，不是首页里的一段。首页一屏只放得下三条，
/// 三十条要滑十屏才看得完，那不叫「看大局」。
///
/// 顶上压一条概览带，把全部记录压成一条点带：一辈子有多长、哪几年密、
/// 现在看的是哪一段，一眼就有。带子和下面的列表是同一份数据的两面 ——
/// 滚动时带上高亮跟着走，点带上任意一处就跳过去。
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  final ScrollController _scroll = ScrollController();

  /// 视口状态（滚动到哪儿 + 有多高）。概览带的高亮和「回到今天」的显隐都
  /// 读它。做成 ValueNotifier 是为了只重建那一小块 —— 跟着滚动每帧重建
  /// 整个列表（还带着解析封面）是没必要的。
  final ValueNotifier<({double offset, double viewport})> _view =
      ValueNotifier((offset: 0, viewport: 0));

  /// 打开时自动滚到今天，只做一次 —— 之后用户滚到哪儿就是哪儿。
  bool _didJumpToToday = false;

  bool _frameScheduled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncView);
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncView);
    _scroll.dispose();
    _view.dispose();
    super.dispose();
  }

  void _syncView() {
    if (!_scroll.hasClients) return;
    _view.value = (
      offset: _scroll.offset,
      viewport: _scroll.position.viewportDimension,
    );
  }

  /// 布局完再做事。行号和滚动位置的对照表要等第一帧结束才成立，
  /// 在 build 里直接读 `maxScrollExtent` 拿到的是上一帧的数。
  void _scheduleAfterFrame(VoidCallback action) {
    if (_frameScheduled) return;
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted) return;
      action();
    });
  }

  /// 这一行应该滚到哪儿：让它落在视口偏上的三分之一处 —— 打开时能同时
  /// 看见「今天」上面那几条未来的，和下面刚过去的几条。
  double _scrollTargetFor(TimelinePlan plan, int index, double viewport) {
    if (index < 0 || !_scroll.hasClients) return 0;
    return (plan.topOf(index) - viewport * 0.35)
        .clamp(0.0, _scroll.position.maxScrollExtent);
  }

  void _jumpToToday(TimelinePlan plan, double viewport) {
    if (_didJumpToToday || !_scroll.hasClients) return;
    _didJumpToToday = true;
    final target = _scrollTargetFor(plan, plan.todayIndex, viewport);
    if (target > 0.5) _scroll.jumpTo(target);
  }

  Future<void> _scrollToRow(TimelinePlan plan, int index, double viewport) async {
    if (index < 0 || !_scroll.hasClients) return;
    await _scroll.animateTo(
      _scrollTargetFor(plan, index, viewport),
      duration: kTransitionDuration,
      curve: kTransitionCurve,
    );
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
          child: ValueListenableBuilder<List<Daily>>(
            valueListenable: DailyRepository.instance.items,
            builder: (context, dailies, _) {
              final plan = planTimeline(dailies, today: DateTime.now());
              return Column(
                children: [
                  _buildBar(context, plan),
                  Expanded(
                    child: plan.rows.isEmpty
                        ? _buildEmpty(context)
                        : _buildAxis(context, plan),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context, TimelinePlan plan) {
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
          // 默认停在今天，这个按钮只在滚走之后才有意义
          ValueListenableBuilder<({double offset, double viewport})>(
            valueListenable: _view,
            builder: (context, view, _) {
              final away = !_todayInView(plan, view);
              return AnimatedOpacity(
                opacity: away ? 1 : 0,
                duration: kTransitionDuration,
                curve: kTransitionCurve,
                child: IgnorePointer(
                  ignoring: !away,
                  child: TextButton(
                    onPressed: () {
                      unawaited(tapFeedback());
                      unawaited(_scrollToRow(plan, plan.todayIndex, view.viewport));
                    },
                    style: TextButton.styleFrom(foregroundColor: colors.onBackground),
                    child: Text('回到今天', style: AppTextStyles.of(context).aboutStyle),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 「今天」那道横标完整地待在视口里吗。视口还没量出来（第一帧之前）时
  /// 当作看得见 —— 否则按钮会先闪一下再消失。
  bool _todayInView(TimelinePlan plan, ({double offset, double viewport}) view) {
    final index = plan.todayIndex;
    if (index < 0 || view.viewport <= 0) return true;
    return plan.topOf(index) >= view.offset - 0.5 &&
        plan.topOf(index + 1) <= view.offset + view.viewport + 0.5;
  }

  Widget _buildAxis(BuildContext context, TimelinePlan plan) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 一屏装得下就不摆概览带：那条带子的全部意义是「你在整段里的哪儿」，
        // 内容还没一屏长的时候，它只会是一块占地方的装饰
        final scrolls = plan.height > constraints.maxHeight - kTimelineBandHeight;
        final viewport = constraints.maxHeight - (scrolls ? kTimelineBandHeight : 0);
        _scheduleAfterFrame(() {
          _jumpToToday(plan, viewport);
          _syncView();
        });

        return Column(
          children: [
            if (scrolls)
              _OverviewBand(
                plan: plan,
                view: _view,
                onSeek: (index) {
                  unawaited(tapFeedback());
                  unawaited(_scrollToRow(plan, index, viewport));
                },
              ),
            Expanded(
              child: Stack(
                children: [
                  _buildAxisLine(context),
                  _buildList(context, plan),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 那条竖轴。整条固定不动地铺满视口，只有两端渐隐 —— 轴在视口之外还长着，
  /// 断在屏幕边上比断在某条记录上更像话。
  Widget _buildAxisLine(BuildContext context) {
    final colors = AppColors.of(context);
    return Positioned(
      left: kTimelineAxisX - 0.5,
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
              colors.divider,
              colors.divider.withValues(alpha: 0),
            ],
            stops: const [0, 0.06, 0.94, 1],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, TimelinePlan plan) {
    return ListView.builder(
      controller: _scroll,
      // 顶上不留 padding：行的 y 必须和 `TimelinePlan.topOf` 逐像素对上，
      // 概览带的高亮和点按跳转全靠这个等式。底下留一点空地，
      // 让最后一条不必贴着屏幕底边（手势条那截 SafeArea 已经让过了）
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: plan.rows.length,
      itemBuilder: (context, i) => _buildRow(context, plan.rows[i]),
    );
  }

  Widget _buildRow(BuildContext context, TimelineRow row) => switch (row) {
        YearRow(:final year) => _buildYearRow(context, year),
        TodayRow() => _buildTodayRow(context),
        RecordRow() => _buildRecordRow(context, row),
      };

  Widget _buildRecordRow(BuildContext context, RecordRow row) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final cover = resolveCover(
      coverKey: row.daily.coverKey,
      imageUrl: row.daily.imageUrl,
      locate: Covers.instance.locate,
    );
    return SizedBox(
      height: kTimelineRowHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openDetail(row.daily),
        child: Row(
          children: [
            SizedBox(
              width: kTimelineAxisX * 2,
              child: Center(child: _buildDot(context, cover)),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.daily.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.aboutMiddleStyle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fmtMonthDay(row.day),
                    style: styles.aboutBottomStyle.copyWith(color: colors.onBackgroundMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              countdownLabel(row.signedDays),
              style: styles.groupTitleStyle.copyWith(
                color: row.isToday ? colors.onBackground : colors.onBackgroundMuted,
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(BuildContext context, Cover cover) {
    // 圆点只有 30dp 上下，按它真正占的物理像素解码，别为这点大的圆圈
    // 把整张照片（最长边 1600）读进内存
    final decodeWidth = (kTimelineDotSize * MediaQuery.devicePixelRatioOf(context)).round();
    return Container(
      width: kTimelineDotSize,
      height: kTimelineDotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // 和底色同色的一圈：圆点压在竖轴上时把那截线断开，像打了个孔
        border: Border.all(color: AppColors.of(context).background, width: 2),
      ),
      child: ClipOval(child: CoverView(cover: cover, decodeWidth: decodeWidth)),
    );
  }

  /// 年份刻度。数字写在轴的左边，刻度压在轴上 —— 盒子从
  /// `kTimelineAxisX - 6` 起、宽 12，正中正好落在轴线上。
  Widget _buildYearRow(BuildContext context, int year) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: kTimelineYearRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: kTimelineAxisX - 6,
            child: Text(
              '$year',
              textAlign: TextAlign.right,
              maxLines: 1,
              style: AppTextStyles.of(context).aboutStyle.copyWith(color: colors.onBackgroundMuted),
            ),
          ),
          SizedBox(
            width: 12,
            child: Center(
              child: Container(
                // 宽度要写死：Container 没有子节点时会被压成 0 宽，
                // 刻度就成了一条看不见的线
                width: 12,
                height: 2,
                decoration: BoxDecoration(
                  color: colors.onBackgroundMuted,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 「今天」那道横标：轴上换成一枚实心点，右边拉一条线到屏幕尽头。
  Widget _buildTodayRow(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: kTimelineTodayRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: kTimelineAxisX * 2,
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.onBackground),
              ),
            ),
          ),
          Text(
            '今天',
            style: AppTextStyles.of(context).aboutMiddleStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Container(height: 1, color: colors.divider),
            ),
          ),
        ],
      ),
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

/// 顶部概览带：把全部记录按时间摊成一条点带。
///
/// 横轴是**时间本身**，不是列表位置 —— 三年没有记录就真的空出一段，
/// 点带的疏密就是那些年攒下的东西。高亮的那块是「现在看着的这几条落在
/// 时间上的哪一段」，所以它滚动的速度并不均匀，那是尺度的实话。
class _OverviewBand extends StatelessWidget {
  final TimelinePlan plan;
  final ValueListenable<({double offset, double viewport})> view;
  final ValueChanged<int> onSeek;

  const _OverviewBand({required this.plan, required this.view, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kTimelineBandHeight,
      // LayoutBuilder 在外、ValueListenableBuilder 在内：点的位置只跟宽度有关，
      // 没理由跟着每一帧的滚动重算一遍（照片封面那条路要查文件系统）
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inner = (constraints.maxWidth - 2 * kTimelineBandPadding)
              .clamp(1.0, double.infinity);
          final dots = _buildDots(context, inner);
          final todayX = kTimelineBandPadding + plan.xOf(plan.today, inner);
          return ValueListenableBuilder<({double offset, double viewport})>(
            valueListenable: view,
            builder: (context, v, _) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final index = plan.nearestRecordIndex(
                  details.localPosition.dx - kTimelineBandPadding,
                  inner,
                );
                if (index != null) onSeek(index);
              },
              child: CustomPaint(
                size: Size(constraints.maxWidth, kTimelineBandHeight),
                painter: _BandPainter(
                  dots: dots,
                  highlight: _visibleSpan(v, inner),
                  todayX: todayX,
                  lineColor: AppColors.of(context).divider,
                  dotColors: AppColors.of(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 带子上的点用封面的颜色：那六套渐变本来就是这套 App 的分类色，
  /// 一眼能看出「哪一段是工作、哪一段是生日」。照片封面取不出颜色，给中性灰。
  List<({double x, Color color})> _buildDots(BuildContext context, double inner) {
    final colors = AppColors.of(context);
    final dots = <({double x, Color color})>[];
    for (final row in plan.rows) {
      if (row is! RecordRow) continue;
      final cover = resolveCover(
        coverKey: row.daily.coverKey,
        imageUrl: row.daily.imageUrl,
        locate: Covers.instance.locate,
      );
      dots.add((
        x: kTimelineBandPadding + plan.xOf(row.day, inner),
        color: switch (cover) {
          GradientCover(:final index) => gradientFor(index).colors.first,
          PhotoCover() => colors.onBackgroundFaint,
        },
      ));
    }
    return dots;
  }

  /// 视口里那几条记录占掉的时间段。一条记录都看不见（只看见年份刻度）时
  /// 返回 null，那时不画高亮 —— 画哪儿都是错的。
  ({double start, double end})? _visibleSpan(
    ({double offset, double viewport}) v,
    double inner,
  ) {
    final visible = plan.visibleRows(v.offset, v.viewport);
    if (visible == null) return null;
    DateTime? first;
    DateTime? last;
    for (var i = visible.first; i <= visible.last; i++) {
      final row = plan.rows[i];
      if (row is! RecordRow) continue;
      first ??= row.day;
      last = row.day;
    }
    if (first == null || last == null) return null;
    final a = kTimelineBandPadding + plan.xOf(first, inner);
    final b = kTimelineBandPadding + plan.xOf(last, inner);
    return a <= b ? (start: a, end: b) : (start: b, end: a);
  }
}

class _BandPainter extends CustomPainter {
  final List<({double x, Color color})> dots;
  final ({double start, double end})? highlight;
  final double todayX;
  final Color lineColor;
  final AppColors dotColors;

  const _BandPainter({
    required this.dots,
    required this.highlight,
    required this.todayX,
    required this.lineColor,
    required this.dotColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;

    // 高亮：现在看着的那一段。至少留 6px 宽，不然只剩一条记录时它会细成一根线
    final span = highlight;
    if (span != null) {
      final rect = Rect.fromLTRB(
        span.start,
        6,
        span.end < span.start + 6 ? span.start + 6 : span.end,
        size.height - 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = dotColors.onBackground.withValues(alpha: 0.06),
      );
    }

    // 带子自己那条轴：两端渐隐，和下面那条竖轴是同一种语气
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, midY),
          Offset(size.width, midY),
          [
            lineColor.withValues(alpha: 0),
            lineColor,
            lineColor,
            lineColor.withValues(alpha: 0),
          ],
          const [0, 0.04, 0.96, 1],
        )
        ..strokeWidth = 1,
    );

    for (final dot in dots) {
      canvas.drawCircle(
        Offset(dot.x, midY),
        kTimelineBandDot / 2,
        Paint()..color = dot.color.withValues(alpha: 0.85),
      );
    }

    // 今天那枚刻线。数字写在带子顶上，右边放不下就翻到左边去
    canvas.drawLine(
      Offset(todayX, 4),
      Offset(todayX, size.height - 4),
      Paint()
        ..color = dotColors.onBackground
        ..strokeWidth = 1.5,
    );
    final label = TextPainter(
      text: TextSpan(
        text: '今天',
        style: TextStyle(fontSize: 10, color: dotColors.onBackground, fontFamily: 'Dongqing'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final left = todayX + 6 + label.width > size.width ? todayX - 6 - label.width : todayX + 6;
    label.paint(canvas, Offset(left, 2));
  }

  @override
  bool shouldRepaint(_BandPainter oldDelegate) => true;
}
