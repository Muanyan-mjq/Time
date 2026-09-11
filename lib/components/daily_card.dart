import 'package:daily/model/cover.dart';
import 'package:daily/styles/dimens.dart';
import 'package:daily/styles/text_style.dart';
import 'package:daily/utils/date_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'cover_view.dart';

/// 首页和详情页共用的封面卡片。
///
/// 老代码这两处的结构不一样（首页 `ClipRRect` + `Column`，详情 `Container(400)`
/// + `Stack`），所以 Hero 飞行时像在变形。同一个组件两种尺寸，
/// 飞起来就是一次干净的尺寸插值。
class DailyCoverCard extends StatelessWidget {
  final Cover cover;
  final String headText;
  final String title;

  /// `yyyy-MM-dd`；空串或解析失败时显示「日期待补充」。
  final String targetDay;

  /// 距今天数，来自 `signedDaysFromToday`。null 表示日期解析不了。
  final int? signedDays;

  final double height;

  /// 内容层额外躲开的高度，用来避开顶部的系统状态栏和悬浮按钮。
  ///
  /// 首页卡片在「Forever」头部下方，传 0；详情页卡片从 y=0 开始铺满全屏，
  /// 必须把状态栏和左上角返回按钮的高度让出来，否则标题会压在状态栏上、
  /// 并且和 44×44 的返回按钮水平重叠 32px。
  final double contentTopInset;

  /// 列表滚动时的视差位移，单位逻辑像素。null 表示这张卡不参与视差。
  ///
  /// 只传一个 `ValueListenable` 而不是 double：视差每帧都在变，传值会让整张
  /// 卡片每帧重建，传可监听对象就只重建封面那一层。
  final ValueListenable<double>? parallax;

  /// 这条记录的下一次就在今天。加一枚小标记和一圈很缓的呼吸光。
  final bool isToday;

  /// 右上角，详情页放「编辑」。
  final Widget? trailing;

  /// 右下角。给了它就不再画倒计时 —— 详情页用它放「重复 · 提醒」状态行。
  ///
  /// 它按自身宽度摆放，不参与伸缩：地方不够时先挤左边的日期。
  final Widget? bottomTrailing;

  /// 中间区域，详情页放可点按的计数。
  final Widget? middle;

  const DailyCoverCard({
    super.key,
    required this.cover,
    required this.headText,
    required this.title,
    required this.targetDay,
    required this.signedDays,
    this.height = kCardHeight,
    this.contentTopInset = 0,
    this.parallax,
    this.isToday = false,
    this.trailing,
    this.bottomTrailing,
    this.middle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(kCardRadius),
            child: parallax == null
                ? CoverView(cover: cover, decodeWidth: kCoverDecodeWidth)
                : _ParallaxCover(shift: parallax!, cover: cover),
          ),
          // 压暗层只加在照片上：用户照片亮度不可控，不加白字就看不见。
          // 渐变色是代码画的，本身已经够暗，保持 2020 年的原样。
          if (cover is PhotoCover)
            ClipRRect(
              borderRadius: BorderRadius.circular(kCardRadius),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x73000000), Color(0x14000000), Color(0x73000000)],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ),
          if (isToday) const Positioned.fill(child: IgnorePointer(child: _TodayAura())),
          Padding(
            padding: EdgeInsets.fromLTRB(
              kCardPadding,
              kCardPadding + contentTopInset,
              kCardPadding,
              kCardPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        headText,
                        style: AppTextStyles.headTextStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 徽章放在行内而不是绝对定位：行里有「编辑」按钮时行高会
                    // 变大，绝对定位得靠猜一个纵向偏移才能对齐
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      const _TodayBadge(),
                    ],
                    ?trailing,
                  ],
                ),
                // 标题是用户输入，必须限行 —— 老代码一行限制都没有，
                // 60 个字的标题会直接在框里画出黄黑溢出条纹
                Text(
                  title,
                  style: AppTextStyles.titleTextStyle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                Expanded(child: middle ?? const SizedBox()),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        targetDay.isEmpty ? '日期待补充' : targetDay,
                        style: AppTextStyles.targetDayStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 不能包 Flexible：那样它和左边的日期会各分到一半宽度
                    // （两个 flex:1），「每年 · 提前3天 09:00」在 360 宽的屏上
                    // 直接被省略号截掉半句。让它按自身宽度摆，日期负责伸缩
                    if (bottomTrailing != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: bottomTrailing!,
                      )
                    // 当天那句「就是今天」由右上角徽章说，这里不再重复第二遍
                    else if (signedDays != null && signedDays != 0)
                      Text(countdownLabel(signedDays!), style: AppTextStyles.countdownStyle),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 把封面画得比卡片高出两倍最大位移，再在里面平移。
///
/// 不做「画得正好、平移时靠 `Alignment` 兜住」是因为那样子像素计算会漂，
/// 顶部照样会露出一条底色。索性留足余量，让裁切来收边。
class _ParallaxCover extends StatelessWidget {
  final ValueListenable<double> shift;
  final Cover cover;

  const _ParallaxCover({required this.shift, required this.cover});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -kParallaxMax,
          bottom: -kParallaxMax,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: shift,
            builder: (_, dy, child) => Transform.translate(
              offset: Offset(0, dy),
              child: child,
            ),
            child: CoverView(cover: cover, decodeWidth: kCoverDecodeWidth),
          ),
        ),
      ],
    );
  }
}

/// 「就是今天」小徽章。做成实心白底黑字，是为了在浅色照片上也能一眼看见 ——
/// 卡片上其他文字都是白的，这枚要是也用白色半透明，正好会和封面糊在一起。
class _TodayBadge extends StatelessWidget {
  const _TodayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '就是今天',
        style: TextStyle(
          fontSize: 11,
          height: 1.1,
          color: Color(0xFF1A1A1A),
          fontWeight: FontWeight.w500,
          fontFamily: 'Dongqing',
        ),
      ),
    );
  }
}

/// 一圈极缓的呼吸白光。只挂在当天那张卡上，一年里绝大多数时候是 0~1 张。
class _TodayAura extends StatefulWidget {
  const _TodayAura();

  @override
  State<_TodayAura> createState() => _TodayAuraState();
}

class _TodayAuraState extends State<_TodayAura> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Padding(
          // 往里收一点，不然描边正好压在圆角上会被裁掉半条
          padding: const EdgeInsets.all(2.5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kCardRadius - 2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1 + 0.45 * t)),
            ),
          ),
        );
      },
    );
  }
}

