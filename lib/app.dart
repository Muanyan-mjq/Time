import 'dart:async';

import 'package:daily/constants.dart';
import 'package:daily/data/daily_repository.dart';
import 'package:daily/data/notifications.dart';
import 'package:daily/data/settings.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/pages/detail/detail.dart';
import 'package:daily/pages/home/home.dart';
import 'package:daily/pages/lock.dart';
import 'package:daily/pages/splash.dart';
import 'package:daily/styles/colors.dart';
import 'package:daily/utils/date_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:oktoast/oktoast.dart';

class DailyApp extends StatefulWidget {
  const DailyApp({super.key});

  @override
  State<DailyApp> createState() => _DailyAppState();
}

class _DailyAppState extends State<DailyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  /// 上次算「今天」时用的是哪一天。
  ///
  /// App 在后台放一夜再回来，「还有 N 天」还是昨天的数 —— 首页卡片、详情页
  /// 大数字、通知栏常驻倒计时会一起差一天。这里盯住日历日，跨了才重算。
  String _today = fmtStorage(DateTime.now());

  /// 隐私锁是否正盖着。为 true 时首页**整个不被构建**。
  final ValueNotifier<bool> _locked = ValueNotifier(false);

  /// 退到后台的时刻，回来时拿它和 [kLockGrace] 比。
  DateTime? _backgroundedAt;

  /// 本次启动里用户按过「先跳过」。锁本身出了问题（设备没锁屏凭据、
  /// 系统弹不出验证框）时才可能出现 —— 与其每次回到前台都撞一次墙，
  /// 不如这次启动就不再锁；下次冷启动会重新按设置走。
  bool _skippedThisSession = false;

  bool get _lockWanted =>
      Settings.instance.lockEnabled.value && !_skippedThisSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 冷启动就开着锁的话，首页从第一帧起就不该存在 —— 见 build 里的分支
    _locked.value = _lockWanted;
    NotificationService.instance.pendingOpen.addListener(_openPending);
    // 通知可能是在 App 没起来的时候点的，那时列表还是空的；等数据到了再试一次
    DailyRepository.instance.items.addListener(_openPending);
    // 解锁之后再把「点通知进来」这件事兑现：锁着的时候跳页面等于把内容
    // 摆在锁页底下的路由里，那才是真正的泄露
    _locked.addListener(_openPending);
  }

  @override
  void dispose() {
    NotificationService.instance.pendingOpen.removeListener(_openPending);
    DailyRepository.instance.items.removeListener(_openPending);
    _locked.removeListener(_openPending);
    _locked.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 把「点通知」这件事兑现成一次导航。
  ///
  /// 数据还没到就先留着（items 变化时会再调一次）；数据到了却查不到这条，
  /// 说明记录已经被删了，放弃 —— 否则每次列表刷新都会重试一次没有结果的事。
  void _openPending() {
    final id = NotificationService.instance.pendingOpen.value;
    if (id == null) return;
    if (_locked.value) return;
    final dailies = DailyRepository.instance.items.value;
    if (dailies.isEmpty) return;

    final navigator = _navigator.currentState;
    if (navigator == null) return;
    NotificationService.instance.pendingOpen.value = null;

    Daily? target;
    for (final d in dailies) {
      if (d.id == id) target = d;
    }
    if (target == null) return;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => HeroDetailPage(daily: target!),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    // 先落锁：回来的第一帧就不该是内容
    _lockIfAway();

    // 回来就重排一次：系统可能在后台清掉了闹钟，常驻通知也可能被用户划掉了。
    // 和跨零点重算共用一个入口，不另开 observer。
    unawaited(NotificationService.instance.sync());

    final today = fmtStorage(DateTime.now());
    if (today == _today) return;
    _today = today;
    // refresh 会推给所有监听 items 的界面，它们各自用新的「今天」重算
    unawaited(DailyRepository.instance.refresh());
  }

  /// 只在 `paused` 打点、只在 `resumed` 判断。
  ///
  /// `inactive` 那种一过性的失焦（拉下通知栏、系统验证框自己弹出来）不能算
  /// 「手机离手」—— 否则用户刚验完指纹，系统验证框导致的那次失焦就够让他
  /// 再验一次。
  void _lockIfAway() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || !_lockWanted || _locked.value) return;
    if (DateTime.now().difference(since) < kLockGrace) return;
    _lockNow();
  }

  void _lockNow() {
    // 先把压在上面的详情页/表单页弹回首页：`home` 换成锁页只换得掉栈底
    // 那一层，上面的路由照样盖在锁页上，等于没锁
    _navigator.currentState?.popUntil((route) => route.isFirst);
    _locked.value = true;
  }

  void _onUnlocked({required bool skipped}) {
    if (skipped) _skippedThisSession = true;
    _locked.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return OKToast(
      child: ValueListenableBuilder<bool>(
        valueListenable: Settings.instance.darkMode,
        builder: (context, dark, _) => MaterialApp(
          title: kAppName,
          navigatorKey: _navigator,
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(AppColors.light, Brightness.light),
          darkTheme: _buildTheme(AppColors.dark, Brightness.dark),
          // 不跟系统走：暗色是用户手动开的，而启动图恒为浅色底（系统主题
          // 在 native 那边无法预知），跟系统会让「启动图 → 首帧」对不上
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          // 不写 localeResolutionCallback：老代码那个函数无条件返回设备 locale，
          // 正是日期选择器文案不中文化的原因
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          // 锁页和首页是**同一个位置上的两个可能**，不是「首页 + 一层遮罩」：
          // 锁着的时候首页根本没被建出来，最近任务列表里的缩略图因此不可能是内容。
          // 外面套 SplashGate 而不是把它塞进分支里 —— 塞进去的话每次解锁
          // 都会重播一遍启动动画。
          home: SplashGate(
            child: ValueListenableBuilder<bool>(
              valueListenable: _locked,
              builder: (context, locked, _) =>
                  locked ? LockPage(onDone: _onUnlocked) : const Home(),
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData _buildTheme(AppColors colors, Brightness brightness) {
  return ThemeData(
    brightness: brightness,
    // 所有没显式指定字体的 Text 都会用上自带字体，包括 showDatePicker
    // 里的 —— 不设的话日期选择器是一副原生安卓脸
    fontFamily: 'Dongqing',
    scaffoldBackgroundColor: colors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.buttonPrimary,
      brightness: brightness,
    ),
    // 弹层、日期选择器、对话框的底色统一在这儿给，
    // 省得每个 showModalBottomSheet / showDatePicker 都传一遍
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.sheet,
      modalBackgroundColor: colors.sheet,
    ),
    datePickerTheme: DatePickerThemeData(backgroundColor: colors.surface),
    dialogTheme: DialogThemeData(backgroundColor: colors.surface),
    // 水波纹默认是浅色主题里的深色，暗色下会糊成一团灰
    splashColor: colors.onBackground.withValues(alpha: 0.08),
    highlightColor: colors.onBackground.withValues(alpha: 0.04),
  );
}
