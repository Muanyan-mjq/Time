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
/// 每条记录是一张卡片：左边封面缩略图，右边标题、日期和倒计时；年份是
/// 左对齐的分节标题（`2027 · 3`）。缩略图代替了上一版那颗 30px 的圆点，
/// 轴也从 1px 加粗到 2px —— 一行里有东西可看，轴也看得见了。
///
/// 顶上压一条概览带，把全部记录按时间摊成一把尺子：一生有多长、哪几年密、
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
        // 一屏装得下就不摆概览带：那把尺子的全部意义是「你在整段里的哪儿」，
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
  ///
  /// 它画的不是分割线，是这条轴本身，所以比 `divider` 深一档、也粗一档：
  /// 上一版那根 1px 的浅线在浅底上基本看不见。
  Widget _buildAxisLine(BuildContext context) {
    final colors = AppColors.of(context);
    return Positioned(
      left: kTimelineAxisX - kTimelineAxisWidth / 2,
      top: 0,
      bottom: 0,
      width: kTimelineAxisWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kTimelineAxisWidth / 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.onBackgroundFaint.withValues(alpha: 0),
              colors.onBackgroundFaint,
              colors.onBackgroundFaint,
              colors.onBackgroundFaint.withValues(alpha: 0),
            ],
            stops: const [0, 0.05, 0.95, 1],
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
      // 让最后一条不必贴着屏幕底边（手势条那截 SafeArea 已经让过了）。
      // 行与行之间的空当不在这儿，在每一行自己的下半截里。
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: plan.rows.length,
      itemBuilder: (context, i) => _buildRow(context, plan.rows[i]),
    );
  }

  Widget _buildRow(BuildContext context, TimelineRow row) => switch (row) {
        YearRow() => _buildYearRow(context, row),
        TodayRow() => _buildTodayRow(context),
        RecordRow() => _buildRecordRow(context, row),
      };

  /// 一条记录：一张卡片，左边封面缩略图，右边标题和「日期 · 倒计时」。
  ///
  /// 卡片左边那截空当里有一枚小结节，落在竖轴上、对着卡片的竖直中心 ——
  /// 卡片就是从那儿挂出去的。用 Stack 而不是 Row 摆它：结点要对齐的是
  /// 「轴」那条线，不是左边那截空当的中心，差值 6px 一眼就能看出来。
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
      child: Stack(
        children: [
          Positioned(
            left: kTimelineContentLeft,
            right: kTimelineContentRight,
            top: 0,
            height: kTimelineCardHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openDetail(row.daily),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(kTimelineCardRadius),
                  border: Border.all(color: colors.divider),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(kTimelineCardPadding),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(kTimelineThumbRadius),
                        child: SizedBox(
                          width: kTimelineThumbSize,
                          height: kTimelineThumbSize,
                          // 缩略图只有 72dp 见方，按它真正占的物理像素解码。
                          // 相册照片最长边 1600，一屏十来张全尺寸进内存就是
                          // 上百 MB，滚动时还会反复冲 ImageCache。
                          child: CoverView(
                            cover: cover,
                            decodeWidth:
                                (kTimelineThumbSize * MediaQuery.devicePixelRatioOf(context))
                                    .round(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.daily.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: styles.aboutMiddleStyle.copyWith(fontWeight: FontWeight.w400),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // 年份由上面那行分节标题交代，这里只写月日
                                Text(
                                  fmtMonthDay(row.day),
                                  style: styles.aboutBottomStyle
                                      .copyWith(color: colors.onBackgroundMuted),
                                ),
                                const SizedBox(width: 8),
                                // 倒计时按自身宽度摆不下时收成省略号，而不是
                                // 在卡片边上画黄黑条纹：它撑满剩下的地方、
                                // 右对齐，所以平常看着就是贴着卡片右边缘
                                Expanded(
                                  child: Text(
                                    countdownLabel(row.signedDays),
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: styles.aboutStyle.copyWith(
                                      color: row.isToday
                                          ? colors.onBackground
                                          : colors.onBackgroundMuted,
                                      fontWeight:
                                          row.isToday ? FontWeight.w500 : FontWeight.w100,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: kTimelineAxisX - 3,
            top: kTimelineCardHeight / 2 - 3,
            child: _buildNode(colors, isToday: row.isToday),
          ),
        ],
      ),
    );
  }

  /// 卡片挂在轴上的那枚小结节。
  Widget _buildNode(AppColors colors, {required bool isToday}) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isToday ? colors.onBackground : colors.onBackgroundFaint,
      ),
    );
  }

  /// 年份分节标题：`2027 · 3 ————————`。
  ///
  /// 左边缘和卡片对齐，右边一截横线一直拉到屏幕边 —— 它是一节的开头，
  /// 不该长得像一条记录。
  Widget _buildYearRow(BuildContext context, YearRow row) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return SizedBox(
      height: kTimelineYearRowHeight,
      child: Padding(
        padding: const EdgeInsets.only(right: kTimelineContentRight),
        child: Row(
          children: [
            const SizedBox(width: kTimelineContentLeft),
            Text(
              '${row.year}',
              style: styles.aboutMiddleStyle.copyWith(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            Text(
              '· ${row.count}',
              style: styles.aboutBottomStyle.copyWith(color: colors.onBackgroundMuted),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: colors.divider)),
          ],
        ),
      ),
    );
  }

  /// 「今天」那道横标：轴上一枚实心点，一条线拉到屏幕尽头，线上坐着「今天」。
  ///
  /// 文字背后垫了一层底色，把线断开 —— 不然线会从「今天」两个字中间穿过去。
  Widget _buildTodayRow(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    const midY = kTimelineTodayRowHeight / 2;
    return SizedBox(
      height: kTimelineTodayRowHeight,
      child: Stack(
        children: [
          Positioned(
            left: kTimelineAxisX,
            right: kTimelineContentRight,
            top: midY - 0.5,
            height: 1,
            child: ColoredBox(color: colors.divider),
          ),
          Positioned(
            left: kTimelineAxisX - 5,
            top: midY - 5,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: colors.onBackground),
            ),
          ),
          Positioned(
            left: kTimelineContentLeft,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                color: colors.background,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '今天',
                  style: styles.aboutMiddleStyle.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
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

/// 顶部概览带：把全部记录按时间摊成一把尺子。
///
/// 横轴是**时间本身**，不是列表位置 —— 三年没有记录就真的空出一段，
/// 点的疏密就是那些年攒下的东西。高亮的那块是「现在看着的这几条落在
/// 时间上的哪一段」，所以它滚动的速度并不均匀，那是尺子的实话。
///
/// 尺子上还刻着年份：一年一枚短刻度，挤得下就写数字，写不下就只留刻度。
class _OverviewBand extends StatelessWidget {
  final TimelinePlan plan;
  final ValueListenable<({double offset, double viewport})> view;
  final ValueChanged<int> onSeek;

  const _OverviewBand({required this.plan, required this.view, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: kTimelineBandHeight,
      // LayoutBuilder 在外、ValueListenableBuilder 在内：点的位置只跟宽度有关，
      // 没理由跟着每一帧的滚动重算一遍（照片封面那条路要查文件系统）
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inner = (constraints.maxWidth - 2 * kTimelineBandPadding)
              .clamp(1.0, double.infinity);
          final dots = _buildDots(context, inner);
          final years = _buildYearTicks(inner);
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
                  years: years,
                  highlight: _visibleSpan(v, inner),
                  todayX: todayX,
                  colors: colors,
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

  /// 尺子上的年刻度：一年一枚，落在 1 月 1 日的位置上。
  List<({double x, int year})> _buildYearTicks(double inner) => [
        for (var year = plan.from.year + 1; year <= plan.to.year; year++)
          (x: kTimelineBandPadding + plan.xOf(DateTime.utc(year, 1, 1), inner), year: year),
      ];

  /// 视口里那几条记录占掉的时间段。一条记录都看不见（只看见年份标题）时
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

/// 那把尺子。从上到下四层：年份数字、年份刻度、轨道与记录点、今天指针。
class _BandPainter extends CustomPainter {
  /// 记录点落在哪儿、什么颜色。
  final List<({double x, Color color})> dots;

  /// 一年一枚的刻度，以及它要写的年份。
  final List<({double x, int year})> years;

  /// 现在看着的那一段，null 表示没画出高亮。
  final ({double start, double end})? highlight;

  final double todayX;
  final AppColors colors;

  const _BandPainter({
    required this.dots,
    required this.years,
    required this.highlight,
    required this.todayX,
    required this.colors,
  });

  /// 轨道的中线。整条带子 64 高，就围着它分层。
  static const double _trackY = 32.5;

  /// 只有高亮块需要知道自己的半高。
  static const double _highlightHalf = 11.5;

  /// 两个年份数字之间至少留这么多像素，挤不下就跳过 —— 一把尺子宁可
  /// 少写几个数，也不能糊成一团。
  static const double _yearLabelGap = 12;

  static const double _yearLabelTop = 5;
  static const double _todayLabelTop = 46;

  @override
  void paint(Canvas canvas, Size size) {
    final startX = kTimelineBandPadding;
    final endX = size.width - kTimelineBandPadding;
    if (endX <= startX) return;

    _paintHighlight(canvas, startX, endX);
    _paintTrack(canvas, startX, endX);
    _paintYears(canvas, startX, endX);
    for (final dot in dots) {
      canvas.drawCircle(Offset(dot.x, _trackY), kTimelineBandDot / 2, Paint()..color = dot.color);
    }
    _paintToday(canvas, size);
  }

  /// 高亮：现在看着的那一段。至少留 12px 宽，不然只剩一条记录时它会细成一根线。
  void _paintHighlight(Canvas canvas, double startX, double endX) {
    final span = highlight;
    if (span == null) return;
    final left = span.start < startX ? startX : span.start;
    final right = span.end > endX ? endX : span.end;
    final rect = Rect.fromLTRB(
      left,
      _trackY - _highlightHalf,
      right < left + 12 ? left + 12 : right,
      _trackY + _highlightHalf,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(_highlightHalf));
    canvas.drawRRect(rrect, Paint()..color = colors.highlight.withValues(alpha: 0.08));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.highlight.withValues(alpha: 0.16),
    );
  }

  /// 轨道自己：两端渐隐，和下面那条竖轴是同一种颜色、同一种语气。
  ///
  /// 不用 `divider`：高亮那块底色本身就接近分割线，轨道压上去正好糊在一起。
  void _paintTrack(Canvas canvas, double startX, double endX) {
    final track = colors.onBackgroundFaint;
    canvas.drawLine(
      Offset(startX, _trackY),
      Offset(endX, _trackY),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(startX, _trackY),
          Offset(endX, _trackY),
          [
            track.withValues(alpha: 0),
            track,
            track,
            track.withValues(alpha: 0),
          ],
          const [0, 0.03, 0.97, 1],
        )
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintYears(Canvas canvas, double startX, double endX) {
    final tickPaint = Paint()
      ..color = colors.onBackgroundMuted
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      fontSize: 11,
      color: colors.onBackgroundMuted,
      fontFamily: 'Dongqing',
    );
    var lastRight = startX - _yearLabelGap;
    for (final tick in years) {
      if (tick.x < startX - 0.5 || tick.x > endX + 0.5) continue;
      canvas.drawLine(
        Offset(tick.x, _trackY - _highlightHalf),
        Offset(tick.x, _trackY - 5),
        tickPaint,
      );
      final label = TextPainter(
        text: TextSpan(text: '${tick.year}', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final left = tick.x - label.width / 2;
      if (left < lastRight + _yearLabelGap) continue;
      if (left + label.width > endX) continue;
      label.paint(canvas, Offset(left, _yearLabelTop));
      lastRight = left + label.width;
    }
  }

  /// 今天那枚指针：竖线压在轨道上，数字挂在带子下半截。
  void _paintToday(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(todayX, _trackY - _highlightHalf),
      Offset(todayX, _trackY + 13),
      Paint()
        ..color = colors.onBackground
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final label = TextPainter(
      text: TextSpan(
        text: '今天',
        style: TextStyle(
          fontSize: 11,
          color: colors.onBackground,
          fontWeight: FontWeight.w500,
          fontFamily: 'Dongqing',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final maxLeft = size.width - label.width;
    final left = maxLeft <= 0 ? 0.0 : (todayX - label.width / 2).clamp(0.0, maxLeft);
    label.paint(canvas, Offset(left, _todayLabelTop));
  }

  @override
  bool shouldRepaint(_BandPainter oldDelegate) => true;
}
