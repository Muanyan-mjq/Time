import 'dart:async';

import 'package:daily/components/custom_dialog.dart';
import 'package:daily/components/daily_card.dart';
import 'package:daily/components/empty_state.dart';
import 'package:daily/constants.dart';
import 'package:daily/data/backup.dart';
import 'package:daily/data/cover_palette.dart';
import 'package:daily/data/covers.dart';
import 'package:daily/data/daily_repository.dart';
import 'package:daily/data/ics.dart';
import 'package:daily/data/settings.dart';
import 'package:daily/data/shortcuts.dart';
import 'package:daily/model/cover.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/model/daily_group.dart';
import 'package:daily/pages/about/about.dart';
import 'package:daily/pages/daily_form.dart';
import 'package:daily/pages/detail/detail.dart';
import 'package:daily/pages/poster.dart';
import 'package:daily/pages/splash.dart';
import 'package:daily/pages/timeline.dart';
import 'package:daily/styles/colors.dart';
import 'package:daily/styles/dimens.dart';
import 'package:daily/styles/iconfont.dart';
import 'package:daily/styles/text_style.dart';
import 'package:daily/utils/haptics.dart';
import 'package:daily/utils/transitions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oktoast/oktoast.dart';

/// 长按菜单能选的动作。
enum _CardAction { edit, poster, calendar, delete }

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  /// 首次加载是否已经结束。只有它为 false 时才显示骨架，之后列表怎么刷新
  /// 都不再闪一下 —— 否则每次从表单/详情页返回都会白屏。
  bool _ready = false;

  /// 视差要读滚动位置，所以列表得有个控制器。
  final ScrollController _scroll = ScrollController();

  /// 已经播过入场动画的记录 id。
  ///
  /// 不记这一笔的话，每次列表刷新（从详情页返回、改个主题、新增一条）
  /// 整屏卡片都会重新淡入一遍 —— 那就不是「入场」而是「闪」了。
  final Set<int> _entered = {};

  @override
  void initState() {
    super.initState();
    AppShortcuts.instance.pending.addListener(_openPendingShortcut);
    _bootstrap();
    // 动作可能在监听挂上之前就到了（initialize 是异步的），补读一次。
    // 放到首帧之后：initState 里推路由会把自己这帧的 build 挤掉
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingShortcut());
  }

  @override
  void dispose() {
    AppShortcuts.instance.pending.removeListener(_openPendingShortcut);
    _scroll.dispose();
    super.dispose();
  }

  /// 桌面图标长按的快捷方式兑现成一次导航。
  ///
  /// 原生只给 `'new'` / `'timeline'` 两个词，认不出来的就丢掉 ——
  /// 它是从外面进来的字符串，不该拿它去猜更多含义。
  void _openPendingShortcut() {
    final action = AppShortcuts.instance.pending.value;
    if (action == null) return;
    AppShortcuts.instance.pending.value = null;
    if (!mounted) return;
    switch (action) {
      case AppShortcuts.kNew:
        _pushScale(context, const DailyFormPage());
      case AppShortcuts.kTimeline:
        _pushScale(context, const TimelinePage());
    }
  }

  Future<void> _bootstrap() async {
    // 读库失败也必须放掉骨架。老版本正是让异常逃出去、loading 永远停在
    // true，首页才会转到天荒地老。
    await DailyRepository.instance.refresh();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.statusBarOf(context),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ValueListenableBuilder<List<Daily>>(
            valueListenable: DailyRepository.instance.items,
            builder: (context, dailies, _) => CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(child: _buildTop()),
                // 遮罩还盖着的时候先不建列表：卡片的错落入场要和遮罩的淡出
                // 接上，否则它们在遮罩底下就演完了，揭开是一屏静止的卡片。
                // 顺带首屏也不用在遮罩底下白算一遍布局。
                if (SplashScope.coveredOf(context))
                  const SliverToBoxAdapter(child: SizedBox.shrink())
                else
                  ..._buildBody(_ready, groupDailies(dailies)),
                const SliverToBoxAdapter(child: SizedBox(height: kListBottomInset)),
              ],
            ),
          ),
        ),
        floatingActionButton: _buildFab(),
      ),
    );
  }

  List<Widget> _buildBody(bool ready, List<DailyGroup> groups) {
    if (!ready) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    }
    if (groups.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            // 空态图标居中时会被 FAB 视觉上压一块，让它整体上移
            padding: EdgeInsets.only(bottom: kListBottomInset),
            child: EmptyState(
              icon: Iconfont.daily,
              title: '还没有纪念日',
              hint: '点右下角的按钮，记下第一个值得纪念的日子',
            ),
          ),
        ),
      ];
    }
    // 错落入场的下标要跨组连续：第二组的第 0 项紧接着第一组的最后一项，
    // 否则每组都会从「第 0 项」重新开始，在组边界上看到一段重播
    final slivers = <Widget>[];
    var index = 0;
    for (final group in groups) {
      slivers.add(SliverToBoxAdapter(child: _buildGroupTitle(group)));
      slivers.add(
        SliverList.builder(
          itemCount: group.items.length,
          itemBuilder: (context, i) => _buildCard(group.items[i], index + i),
        ),
      );
      index += group.items.length;
    }
    return slivers;
  }

  /// 顶部
  Widget _buildTop() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Forever', style: AppTextStyles.of(context).appTitle),
          // FittedBox 只在放不下时等比缩小，够宽时渲染结果和原来一模一样
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(kAppSlogan, style: AppTextStyles.of(context).appTip),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTitle(DailyGroup group) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kCardMarginH, 18, kCardMarginH, 2),
      child: Text(group.label, style: AppTextStyles.of(context).groupTitleStyle),
    );
  }

  Widget _buildCard(DailyEntry entry, int index) {
    final card = _PressableCard(
      scroll: _scroll,
      onTap: () => _openDetail(entry.daily),
      onLongPress: () => _openCardMenu(entry.daily),
      builder: (parallax) => Hero(
        tag: 'hero${entry.daily.id}',
        child: DailyCoverCard(
          cover: resolveCover(
            coverKey: entry.daily.coverKey,
            imageUrl: entry.daily.imageUrl,
            locate: Covers.instance.locate,
          ),
          headText: entry.daily.headText,
          title: entry.daily.title,
          targetDay: entry.daily.targetDay,
          signedDays: entry.signedDays,
          isToday: entry.signedDays == 0,
          parallax: parallax,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kCardMarginH, vertical: kCardMarginV),
      // 只有第一次见到的记录才播入场：Set.add 返回 true 说明是新的。
      // 不记这一笔的话，从详情页返回都会让整屏卡片重播一遍淡入。
      child: _entered.add(entry.daily.id) ? StaggerIn(index: index, child: card) : card,
    );
  }

  Widget _buildFab() {
    final colors = AppColors.of(context);
    return FloatingActionButton(
      heroTag: 'menu',
      backgroundColor: colors.buttonPrimary,
      onPressed: () => _openMenu(context),
      child: Icon(Icons.menu, color: colors.onButtonPrimary),
    );
  }

  /// 每个入口都带文字标签 —— 老版 UnicornDialer 是 hasLabel: false，图标根本猜不出来
  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      // 弹层是独立路由，但配色不用在这儿操心：`showModalBottomSheet` 传的
      // `to` 是 Navigator 的 context，而 MaterialApp 的 Theme 在 Navigator
      // 之上，所以一个主题都没被捕获，弹层里的 `Theme.of` 是**活的**
      // （test/theme_test.dart 里钉着这条）。这里的 ValueListenableBuilder
      // 管的是 Switch 的 value —— 开关拨动后这一层得自己重画一次。
      builder: (sheetContext) => ValueListenableBuilder<bool>(
        valueListenable: Settings.instance.darkMode,
        builder: (sheetContext, dark, _) {
          // 整行和滑块都要给一下触感，否则点滑块没反馈、点行才有
          void toggle(bool value) {
            unawaited(toggleFeedback());
            unawaited(Settings.instance.setDarkMode(value));
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _menuItem(
                  sheetContext,
                  index: 0,
                  icon: Icons.add_circle_outline,
                  title: '新增纪念日',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pushScale(context, const DailyFormPage());
                  },
                ),
                _menuItem(
                  sheetContext,
                  index: 1,
                  icon: Iconfont.share,
                  title: '分享海报',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openPoster(context);
                  },
                ),
                _menuItem(
                  sheetContext,
                  index: 2,
                  icon: Icons.timeline,
                  title: '时光轴',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pushScale(context, const TimelinePage());
                  },
                ),
                _menuItem(
                  sheetContext,
                  index: 3,
                  icon: Icons.brightness_4_outlined,
                  title: '深色模式',
                  // 整行可点：只有那个小滑块能点的话很容易按空
                  onTap: () => toggle(!dark),
                  trailing: Switch(value: dark, onChanged: toggle),
                ),
                _menuItem(
                  sheetContext,
                  index: 4,
                  icon: Icons.settings_backup_restore,
                  title: '备份与恢复',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openBackup(context);
                  },
                ),
                _menuItem(
                  sheetContext,
                  index: 5,
                  icon: Icons.info_outline,
                  title: '关于 $kAppName',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pushScale(context, const About());
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return StaggerIn(
      index: index,
      child: ListTile(
        leading: Icon(icon, color: AppColors.of(context).onBackground),
        title: Text(title, style: AppTextStyles.of(context).aboutMiddleStyle),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Future<void> _pushScale(BuildContext context, Widget page) {
    return Navigator.of(context).push(buildScaleRoute(page: page));
  }

  /// 编辑和删除都会经由 `DailyRepository`，列表自己会更新，这里不需要
  /// 在返回之后再手动重读一遍。
  ///
  /// 返回 Future 是给卡片用的：它要等这条路由走完，才能解冻视差。
  Future<void> _openDetail(Daily daily) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HeroDetailPage(daily: daily),
        fullscreenDialog: true,
      ),
    );
  }

  /// 长按卡片弹出的快捷菜单。
  ///
  /// 编辑和删除都在表单页里也有，但那是「先进详情页、再点编辑」两步。
  /// 长按是给「我就想改这一条」准备的近路。
  Future<void> _openCardMenu(Daily daily) async {
    final action = await showModalBottomSheet<_CardAction>(
      context: context,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuItem(
              sheetContext,
              index: 0,
              icon: Icons.edit_outlined,
              title: '编辑',
              onTap: () => Navigator.pop(sheetContext, _CardAction.edit),
            ),
            _menuItem(
              sheetContext,
              index: 1,
              icon: Iconfont.share,
              title: '分享海报',
              onTap: () => Navigator.pop(sheetContext, _CardAction.poster),
            ),
            _menuItem(
              sheetContext,
              index: 2,
              icon: Icons.event_available_outlined,
              title: '加入系统日历',
              onTap: () => Navigator.pop(sheetContext, _CardAction.calendar),
            ),
            _menuItem(
              sheetContext,
              index: 3,
              icon: Icons.delete_outline,
              title: '删除',
              onTap: () => Navigator.pop(sheetContext, _CardAction.delete),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _CardAction.edit:
        await _pushScale(context, DailyFormPage(daily: daily));
      case _CardAction.poster:
        _openPoster(context, focus: daily);
      case _CardAction.calendar:
        await _addToCalendar(daily);
      case _CardAction.delete:
        await _deleteDaily(daily);
    }
  }

  /// 让系统日历也帮忙提醒。这是对「国产 ROM 杀后台」最实际的兜底 ——
  /// 见 `lib/data/ics.dart` 里那段解释。
  Future<void> _addToCalendar(Daily daily) async {
    // 返回 null = 用户在系统文件选择器里取消了，不该弹任何提示
    final message = await exportToCalendar(daily);
    if (message != null) showToast(message);
  }

  Future<void> _deleteDaily(Daily daily) async {
    if (!await confirmDelete(context) || !mounted) return;
    final ok = await DailyRepository.instance.delete(daily.id);
    if (!ok) {
      if (mounted) showToast('删除失败，请重试');
      return;
    }
    // 数据库删成功之后才动文件 —— 顺序反过来的话，写库失败就永久丢图了。
    // 表单页里的删除走的是同一套顺序。
    final key = daily.coverKey;
    if (key != null && key.startsWith(kPhotoPrefix)) {
      await Covers.instance.remove(key);
    }
    unawaited(successFeedback());
    if (mounted) showToast('删除成功');
  }

  /// 打开分享海报。带 [focus] 就停在那一张，否则停在离今天最近的那张 ——
  /// 列表顺序和「未来 / 已过去」两组一致，最近的那条永远在下标 0。
  ///
  /// 整表都递过去，海报页可以左右滑着换记录，不用退出来重新长按。
  void _openPoster(BuildContext context, {Daily? focus}) {
    final groups = groupDailies(DailyRepository.instance.items.value);
    final dailies = [for (final g in groups) ...g.items.map((e) => e.daily)];
    var index = 0;
    if (focus != null) {
      final at = dailies.indexWhere((d) => d.id == focus.id);
      if (at > 0) index = at;
    }
    _pushScale(context, PosterPage(dailies: dailies, initialIndex: index));
  }

  /// 备份与恢复的二级弹层。
  ///
  /// 两个动作都要弹系统文件选择器，所以点完先把这个弹层收掉 —— 让它留在
  /// 系统面板背后，用户回来时会看到一个「刚才那个菜单怎么还在」的界面。
  void _openBackup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _backupItem(
              sheetContext,
              index: 0,
              icon: Icons.ios_share,
              title: '导出备份',
              hint: '记录和照片打包成一个 zip，可以放进网盘或带到新手机',
              onTap: () {
                Navigator.pop(sheetContext);
                _exportBackup();
              },
            ),
            _backupItem(
              sheetContext,
              index: 1,
              icon: Icons.restore,
              title: '从备份恢复',
              hint: '会清空当前全部记录，再装回 zip 里的内容',
              onTap: () {
                Navigator.pop(sheetContext);
                _restoreBackup();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _backupItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    required String hint,
    required VoidCallback onTap,
  }) {
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);
    return StaggerIn(
      index: index,
      child: ListTile(
        leading: Icon(icon, color: colors.onBackground),
        title: Text(title, style: styles.aboutMiddleStyle),
        subtitle: Text(hint, style: styles.aboutBottomStyle),
        onTap: onTap,
      ),
    );
  }

  /// 导出期间不挂转圈：打包几十条记录是一瞬间的事，真弹个 loading 反而像是
  /// 卡了一下。成败都用 toast 交代。
  Future<void> _exportBackup() async {
    final result = await BackupService.instance.export();
    if (!mounted) return;
    if (result.cancelled) return;
    if (result.ok) unawaited(successFeedback());
    showToast(result.message);
  }

  /// 覆盖是破坏性的，所以确认框必须拿到「现在有几条、要恢复几条」两个数字 ——
  /// `restore` 把问用户的时机留在自己手里，就是为了这两个数字不会算错。
  Future<void> _restoreBackup() async {
    final result = await BackupService.instance.restore(
      confirm: (existing, incoming) => confirmRestore(
        context,
        existing: existing,
        incoming: incoming,
      ),
    );
    if (!mounted) return;
    if (result.cancelled) return;
    if (result.ok) unawaited(successFeedback());
    showToast(result.message);
  }
}

/// 按下轻微缩小，长按起菜单，并给封面算一个随滚动变化的视差位移。
///
/// 老版本在 build 里给每个 item 新建 AnimationController 且从不 dispose，
/// 这里改成有状态组件，控制器管一辈子。
///
/// 视差放在这一层而不是首页里，是因为它需要「这张卡自己在屏幕上的位置」——
/// 只有卡片自己拿得到。首页只需要把共享的 `ScrollController` 递下来。
class _PressableCard extends StatefulWidget {
  /// 列表的滚动控制器。null 表示不参与视差。
  final ScrollController? scroll;

  /// 用 builder 而不是 child：视差位移要交给卡片的封面层，而它是 child 里的
  /// 一个远端节点。
  final Widget Function(ValueListenable<double> parallax) builder;

  final Future<void> Function() onTap;
  final Future<void> Function()? onLongPress;

  const _PressableCard({
    required this.scroll,
    required this.builder,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1, end: 0.98).animate(_controller);

  final ValueNotifier<double> _parallax = ValueNotifier(0);

  double _screenHeight = 0;

  /// Hero 在飞的时候不许再动视差。
  ///
  /// 起飞那一刻卡片还在原地，但如果这段时间里列表动了一下、位移变了，
  /// 落地的位置就会和起飞时对不上，回来时会看到一下跳变。
  bool _frozen = false;

  @override
  void initState() {
    super.initState();
    widget.scroll?.addListener(_syncParallax);
    // 首帧时还没有布局，量不到自己的位置
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncParallax());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenHeight = MediaQuery.sizeOf(context).height;
    _syncParallax();
  }

  @override
  void dispose() {
    widget.scroll?.removeListener(_syncParallax);
    _parallax.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 卡片中心越靠下，封面越往上顶，看起来就是「封面比卡片本体慢半拍」。
  ///
  /// 用屏幕内的相对位置而不是滚动偏移量：这样列表无论滚到哪儿，位移都自动
  /// 落在 ±kParallaxMax 之间，不需要给每张卡算一个基准点。
  void _syncParallax() {
    if (_frozen || !mounted || _screenHeight <= 0) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final center = box.localToGlobal(Offset.zero).dy + box.size.height / 2;
    final t = ((center - _screenHeight / 2) / _screenHeight).clamp(-1.0, 1.0);
    final target = -t * kParallaxMax;
    if ((_parallax.value - target).abs() > 0.01) _parallax.value = target;
  }

  Future<void> _handleTap() async {
    // 先把缩放和视差都归零：Hero 起飞时源卡片还缩着、还偏着的话会看到跳变
    _controller.value = 0;
    _parallax.value = 0;
    _frozen = true;
    unawaited(tapFeedback());
    try {
      await widget.onTap();
    } finally {
      // 路由回来后重新解冻，并把位移算回它该在的位置
      _frozen = false;
      _syncParallax();
    }
  }

  Future<void> _handleLongPress() async {
    unawaited(warningFeedback());
    await widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: _controller.reverse,
      onTap: _handleTap,
      onLongPress: widget.onLongPress == null ? null : _handleLongPress,
      child: ScaleTransition(scale: _scale, child: widget.builder(_parallax)),
    );
  }
}
