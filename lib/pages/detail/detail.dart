import 'dart:async';

import 'package:daily/components/confetti.dart';
import 'package:daily/components/daily_card.dart';
import 'package:daily/data/covers.dart';
import 'package:daily/model/cover.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/pages/daily_form.dart';
import 'package:daily/pages/photo_view.dart';
import 'package:daily/styles/colors.dart';
import 'package:daily/styles/dimens.dart';
import 'package:daily/styles/iconfont.dart';
import 'package:daily/styles/text_style.dart';
import 'package:daily/utils/date_util.dart';
import 'package:daily/utils/haptics.dart';
import 'package:daily/utils/transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HeroDetailPage extends StatefulWidget {
  final Daily daily;

  const HeroDetailPage({super.key, required this.daily});

  @override
  State<HeroDetailPage> createState() => _HeroDetailPageState();
}

class _HeroDetailPageState extends State<HeroDetailPage> {
  late Daily _daily;

  /// 解析一次就存下来：`build` 里每次重新解析会白白走一遍文件存在性检查。
  /// 编辑换过封面之后要重新解析，所以不是 final。
  late Cover _cover;

  /// 年月日在前，和 2020 年的截图一致。
  bool _showYmd = true;

  /// 倒计时天数，由 `Daily.nextDate` 得出：非重复记录就是起始日，
  /// 重复记录是下一个重复日。卡片右下角的「还有 N 天」和「天」视图共用它。
  late int _signedDays;

  /// 年龄天数，由起始日得出，只有「年月日」视图需要。
  ///
  /// 不能拿 [_signedDays] 顶替：重复记录在周年日当天倒计时是 0，但年龄是
  /// 「28年0月0天」—— 那是个有内容的数，不该被「就是今天」盖掉。
  late int _ageDays;

  late ({int years, int months, int days}) _ymd;

  /// 日期解析不了时为 false（老库里的记录、或从别处导进来的）。
  ///
  /// 必须有这个标志：那种记录下面几个数全是 0，直接判 `_signedDays == 0`
  /// 会把它当成「就是今天」，于是放彩纸、亮徽章、写「就是今天」，
  /// 而卡片上明明白白写着「日期待补充」—— 自相矛盾。
  late bool _hasDate;

  /// 倒计时指向过去 → true。等价于老代码的 `todayIsLateTarget`。
  bool get _isPast => _signedDays < 0;

  /// 就是今天。彩纸和呼吸光只在这种情况下出现。
  bool get _isToday => _hasDate && _signedDays == 0;

  @override
  void initState() {
    super.initState();
    _daily = widget.daily;
    _resolveCover();
    _recompute();
  }

  void _resolveCover() {
    _cover = resolveCover(
      coverKey: _daily.coverKey,
      imageUrl: _daily.imageUrl,
      locate: Covers.instance.locate,
    );
  }

  /// 只在数据变化时算一次。build 里只读不重算，也没有定时器。
  void _recompute() {
    final date = _daily.date;
    final next = _daily.nextDate;
    if (date == null || next == null) {
      _hasDate = false;
      _signedDays = 0;
      _ageDays = 0;
      _ymd = (years: 0, months: 0, days: 0);
      return;
    }
    _hasDate = true;
    final now = DateTime.now();
    _signedDays = signedDaysFromToday(next, now: now);
    _ageDays = signedDaysFromToday(date, now: now);
    _ymd = splitYmd(now, date);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 详情页继承首页的 dark 后会在深色照片上画深灰状态栏图标，基本看不见
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: Stack(
          children: [
            SingleChildScrollView(
              // 详情页没有底部栏，备注一长最后一行就压在手势条底下 ——
              // 自己让开底部安全区
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewPaddingOf(context).bottom + 10,
              ),
              child: Column(
                children: [
                  GestureDetector(
                    // 只有真照片才值得点开看大图；渐变是代码画的，放大没有信息量。
                    // 用 opaque 而不是默认的 deferToChild：卡片里大片是空白
                    // 封面，deferToChild 会让中间那块点不动
                    behavior: _cover is PhotoCover
                        ? HitTestBehavior.opaque
                        : HitTestBehavior.deferToChild,
                    onTap: _cover is PhotoCover ? _openPhoto : null,
                    child: Hero(
                      tag: 'hero${_daily.id}',
                      child: DailyCoverCard(
                        height: kDetailHeroHeight,
                        // 详情页的卡片从屏幕最顶部开始铺，必须自己让开状态栏，
                        // 并且把标题整体落到左上角那枚 44×44 返回按钮的下方
                        contentTopInset: MediaQuery.paddingOf(context).top + 44,
                        cover: _cover,
                        headText: _daily.headText,
                        title: _daily.title,
                        targetDay: _daily.targetDay,
                        signedDays: _signedDays,
                        isToday: _isToday,
                        trailing: _buildEditButton(),
                        middle: _buildCounter(width),
                      ),
                    ),
                  ),
                  _buildRemark(),
                ],
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 4,
              left: 6,
              child: _buildBackButton(),
            ),
            // 彩纸压在最上层，不然会被卡片的内容层盖住
            if (_isToday) const Positioned.fill(child: ConfettiBurst()),
          ],
        ),
      ),
    );
  }

  /// 老版本整个页面套了个 onTap: pop，点在编辑按钮旁边 4px 就静默退页，
  /// 滚动时的慢拖也会被识别成点击退页，而且根本没有可见的返回入口。
  Widget _buildBackButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: const SizedBox(
        width: 44,
        height: 44,
        child: DecoratedBox(
          // 一点径向暗底，保证在亮图上也能看清白色箭头
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0x73000000), Color(0x00000000)],
            ),
          ),
          child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openEdit,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text('编辑', style: AppTextStyles.headTextStyle),
      ),
    );
  }

  /// 点按切换年月日 / 总天数。原来的 3 秒自动轮播 + 每秒一次 setState
  /// 已经删掉 —— 静置一分钟白烧 60 帧。
  Widget _buildCounter(double sceneWidth) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        unawaited(toggleFeedback());
        setState(() => _showYmd = !_showYmd);
      },
      child: Center(
        child: RollIn(
          // 值一变就重播一次滚入
          value: _showYmd ? 'ymd' : 'days',
          child: _showYmd ? _buildYmd(sceneWidth) : _buildTotalDays(sceneWidth),
        ),
      ),
    );
  }

  /// 年月日：从起始日算起的年龄。重复记录看的是「多久了」，
  /// 倒计时看的是「还有多久」，两边由不同的数得出。
  Widget _buildYmd(double sceneWidth) {
    if (!_hasDate) return _buildMissingDate(sceneWidth);
    // 满 0 天时不显示 00年00月00日。这里用年龄天数而不是倒计时天数：
    // 一条 1998 年起每年重复的记录，在周年日当天倒计时是 0，年龄是 28 年。
    if (_ageDays == 0) {
      return SizedBox(
        width: (sceneWidth - 36) * 0.6,
        height: 80,
        child: const Center(
          child: Text('就是今天', style: AppTextStyles.countTitleStyle),
        ),
      );
    }
    return SizedBox(
      width: (sceneWidth - 36) * 0.6,
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCountColumn(_ymd.years, '年'),
          _buildCountColumn(_ymd.months, '月'),
          _buildCountColumn(_ymd.days, '日'),
        ],
      ),
    );
  }

  Widget _buildCountColumn(int value, String unit) {
    return SizedBox(
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(fmt2(value), style: AppTextStyles.countTitleStyle),
          Positioned(top: 50, child: Text(unit, style: AppTextStyles.countBottomTipStyle)),
        ],
      ),
    );
  }

  /// 距离目标日的总天数
  Widget _buildTotalDays(double sceneWidth) {
    if (!_hasDate) return _buildMissingDate(sceneWidth);
    return SizedBox(
      width: (sceneWidth - 36) * 0.6,
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(fmt2(_signedDays.abs()), style: AppTextStyles.countTitleStyle),
          const SizedBox(width: 2),
          const Text('天', style: AppTextStyles.countBottomTipStyle),
          Icon(_isPast ? Iconfont.up2 : Iconfont.down1, color: Colors.white, size: 14),
        ],
      ),
    );
  }

  /// 没有可用日期时，两个视图都落到这里，说法和首页卡片保持一致。
  Widget _buildMissingDate(double sceneWidth) {
    return SizedBox(
      width: (sceneWidth - 36) * 0.6,
      height: 80,
      child: const Center(
        child: Text('日期待补充', style: AppTextStyles.countTitleStyle),
      ),
    );
  }

  /// 底部内容
  Widget _buildRemark() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.all(10),
      width: MediaQuery.sizeOf(context).width - 20,
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(_daily.remark, style: AppTextStyles.of(context).contentStyle),
    );
  }

  /// 全屏看大图。
  ///
  /// 复用卡片那枚 Hero tag 是**故意的**：框架明令禁止 Hero 套 Hero
  /// （"A Hero widget cannot be the descendant of another Hero widget"），
  /// 而卡片本身已经是 Hero 了。好在这两枚永远不在同一条路由子树里同时挂着 ——
  /// 全屏页盖上来的时候，详情页那枚只剩占位符。tag 一样，飞行才接得上。
  Future<void> _openPhoto() async {
    final cover = _cover;
    if (cover is! PhotoCover) return;
    unawaited(tapFeedback());
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewPage(path: cover.path, heroTag: 'hero${_daily.id}'),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _openEdit() async {
    final result = await Navigator.of(context).push<FormResult>(
      buildScaleRoute(
        page: DailyFormPage(daily: _daily),
        alignment: Alignment.topRight,
      ),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case FormSaved(:final daily):
        unawaited(successFeedback());
        setState(() {
          _daily = daily;
          _resolveCover();
          _recompute();
        });
      case FormDeleted():
        // 删完直接退回首页，让首页自己去重读
        Navigator.pop(context);
    }
  }
}
