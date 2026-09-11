import 'dart:async';
import 'dart:io';

import 'package:daily/constants.dart';
import 'package:daily/data/daily_repository.dart';
import 'package:daily/data/remind_plan.dart';
import 'package:daily/data/settings.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/utils/date_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// 提醒排班。
///
/// 策略是**全量取消 + 全量重排**，不做增量 diff。数据量只有几十条，全量重排
/// 一次是毫秒级的；而增量要维护「这条改了什么、上次排的是哪一号」，一次对不上
/// 就永久少一条提醒 —— 用户不会发现，直到那个日子安安静静地过去。
///
/// 重复记录**只排下一次**，不排十年后的。每次冷启动 / 改数据 / 回前台都重排，
/// 等于让下一次自己往前滚。
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// 常驻倒计时固定用这个 id，重排时整条替换。
  static const int kOngoingId = 1;

  /// 每条记录的提醒 id 从这儿往上分配，避开常驻那条。
  static const int _dailyIdBase = 1000;

  static const String _channelId = 'daily_remind';
  static const String _channelName = '纪念日提醒';
  static const String _ongoingChannelId = 'daily_ongoing';
  static const String _ongoingChannelName = '倒计时常驻';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// 上一次真正排下去的记录 id。用来在记录被删掉之后，把**已经弹出来**的
  /// 那条也从通知栏撤掉 —— `pendingNotificationRequests` 只看得到还没响的。
  final Set<int> _scheduledIds = <int>{};

  /// 通知被点开时要跳到哪条记录。null 表示没有待处理的目标。
  ///
  /// 用 notifier 而不是直接 push 路由：点通知可能发生在 App 还没起来的时候，
  /// 那时既没有 Navigator 也还没读到数据。挂在这儿，等两边都就绪了再消费。
  final ValueNotifier<int?> pendingOpen = ValueNotifier(null);

  /// 精确闹钟权限被系统收回了。设置页据此如实提示，不假装还能准时。
  final ValueNotifier<bool> exactAlarmDenied = ValueNotifier(false);

  /// 通知权限被拒。同上，提示一次就够，不反复弹窗。
  final ValueNotifier<bool> notificationDenied = ValueNotifier(false);

  /// 冷启动时调一次。之后 `sync()` 由仓库的 items 变化驱动，不用手动记。
  Future<void> initialize() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: _onTap,
      );
      _ready = true;

      // 冷启动那次点按不走上面的回调：进程已经被系统杀掉时，是靠 launch
      // details 把这次点击带回来的（插件文档写明了这个分工）。不读它，
      // 点提醒进来就只会停在首页
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
        _onTap(response);
      }
    } catch (e, st) {
      // 通知用不了不该拦住启动：App 其余部分完全用不着它
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'daily',
        context: ErrorDescription('初始化本地通知'),
      ));
      return;
    }

    // 仓库每次写完自动刷新，列表一变就重排 —— 于是「新增 / 编辑 / 删除 /
    // 备份导入」四条路径全都自动覆盖，不用在每处记得补一次重排
    DailyRepository.instance.items.addListener(_onDataChanged);
    Settings.instance.ongoingNotification.addListener(_onOngoingToggled);
    await sync();
  }

  void _onDataChanged() => unawaited(sync());

  void _onOngoingToggled() => unawaited(syncOngoing());

  void _onTap(NotificationResponse response) {
    final id = int.tryParse(response.payload ?? '');
    if (id != null) pendingOpen.value = id;
  }

  /// 申请通知权限与精确闹钟权限。返回通知权限是否拿到。
  ///
  /// 只在用户第一次打开某条记录的提醒开关时调用 —— 一进 App 就弹权限框
  /// 是最容易被拒绝的时机。
  Future<bool> requestPermissions() async {
    final android = _android;
    if (android == null) return true;

    final granted = await android.requestNotificationsPermission() ?? false;
    notificationDenied.value = !granted;
    if (!granted) return false;

    // Android 14 起这条会跳到系统设置页。放在通知权限之后：前面那道都拒了，
    // 再把人拽去设置页要精确闹钟就纯属骚扰
    final exact = await android.requestExactAlarmsPermission() ?? false;
    exactAlarmDenied.value = !exact;
    return true;
  }

  /// 重读一遍系统给的权限状态，不弹框。
  Future<void> refreshPermissionState() async {
    final android = _android;
    if (android == null) return;
    notificationDenied.value = !(await android.areNotificationsEnabled() ?? true);
    exactAlarmDenied.value = !(await android.canScheduleExactNotifications() ?? true);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      Platform.isAndroid
          ? _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          : null;

  bool _syncing = false;
  bool _syncQueued = false;

  /// 全量重排。任何写操作、冷启动、回到前台、设置变更都会走到这儿。
  ///
  /// 串行 + 合并：列表一变就喊一次重排，而两次重排的「取消旧提醒」与「重新排」
  /// 之间隔着一串 await。交叉执行时，后启动的那次会拿着旧列表把前一次刚取消的
  /// 闹钟重新排上，`_scheduledIds` 也会被后写覆盖 —— 记录删了提醒却照响。
  /// 所以正在跑就只记一个「还要再跑」，等这一轮结束补跑一次最新的。
  Future<void> sync() async {
    if (!_ready) return;
    if (_syncing) {
      _syncQueued = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncQueued = false;
        await _syncOnce();
      } while (_syncQueued);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOnce() async {
    await refreshPermissionState();

    try {
      // 只取消「排着还没响」的，不用 cancelAll() —— 后者会把常驻倒计时一起抹掉
      for (final p in await _plugin.pendingNotificationRequests()) {
        if (p.id != kOngoingId) await _plugin.cancel(id: p.id);
      }
    } catch (e, st) {
      // 取消失败不该带走下面的排班：宁可重复响一次，也别一条都不响
      _report('取消旧提醒', e, st);
    }

    final now = DateTime.now();
    final live = <int>{};
    for (final daily in DailyRepository.instance.items.value) {
      final at = remindMoment(daily, now);
      if (at == null) continue;
      live.add(daily.id);
      // 每条单独兜异常：排一条失败（权限被临时收回、时间点被判在过去）
      // 不能让后面所有条一起消失 —— 取消那一步已经跑完了，整批抛出
      // 的结果是「全部取消、一条没排」，用户一条提醒都收不到
      try {
        await _plugin.zonedSchedule(
          id: _dailyIdBase + daily.id,
          scheduledDate: _instant(at),
          notificationDetails: _reminderDetails,
          // 权限被系统收回时自动降级成非精确 —— 晚几分钟也比不响强，
          // 而设置页已经如实写了「当前不是精确提醒」
          androidScheduleMode: exactAlarmDenied.value
              ? AndroidScheduleMode.inexactAllowWhileIdle
              : AndroidScheduleMode.exactAllowWhileIdle,
          title: daily.headText.isEmpty ? daily.title : daily.headText,
          body: _fireBody(daily),
          payload: '${daily.id}',
        );
      } catch (e, st) {
        _report('排期提醒「${daily.title}」', e, st);
      }
    }

    // 记录被删掉、或者提醒被关掉之后，已经弹出来的那条还挂在通知栏里，
    // 点它又跳不到任何地方（pendingNotificationRequests 只看得到没响的，
    // 所以上面那圈取消扫不到它）。这里把「上次排过、这次不在名单里」的撤掉
    for (final gone in _scheduledIds.difference(live)) {
      try {
        await _plugin.cancel(id: _dailyIdBase + gone);
      } catch (e, st) {
        _report('撤下已删除记录的提醒', e, st);
      }
    }
    _scheduledIds
      ..clear()
      ..addAll(live);

    await syncOngoing();
  }

  void _report(String what, Object e, StackTrace st) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: e,
      stack: st,
      library: 'daily',
      context: ErrorDescription(what),
    ));
  }

  /// 把设备本地时刻交给插件。
  ///
  /// 用固定的 UTC 时区而不是 `tz.local`：插件把「墙上时间字符串 + 时区名」原样
  /// 交给原生，由原生用 `ZoneId.of(名称)` 自己算出绝对时刻（见插件的
  /// tz_datetime_mapper.dart 与 FlutterLocalNotificationsPlugin.java）。
  /// `TZDateTime.from` 保留的是绝对时刻，所以拿 UTC 走一圈回来分毫不差，
  /// 而 `tz.local` 需要先加载整个时区数据库、还得猜准本机的 IANA 名字 ——
  /// 猜错（比如把 +08:00 猜成 Asia/Chongqing 之外的东西）就是提醒错几个小时。
  ///
  /// 代价是用户跨时区旅行时已排的闹钟仍按原绝对时刻响。提醒本来每次
  /// 回到 App 就会重排，这个代价落不到实处。
  tz.TZDateTime _instant(DateTime local) => tz.TZDateTime.from(local, tz.UTC);

  /// 定时提醒的正文。
  ///
  /// 必须由**响的那一刻**得出，不能拿排班时刻的 now 去算：每年重复的记录
  /// 可能提前一年就排下去了，用 now 算出来的「还有 239 天」会被原样冻进
  /// 通知里，到点弹出来就是这么一句 —— 用户看到的是三百多天前的旧账。
  /// 而响的那天离纪念日恒等于「提前 N 天」，所以直接拿它当数，
  /// 排班时算和响铃时算是同一个值。
  String _fireBody(Daily daily) =>
      '${countdownLabel(daily.remindDaysBefore)} · ${daily.title}';

  /// 常驻倒计时的正文。它是当场显示出来的，所以就该用当下这一刻算。
  String _liveBody(Daily daily, DateTime now) {
    final next = daily.nextDateFrom(now);
    if (next == null) return daily.remark;
    return '${countdownLabel(signedDaysFromToday(next, now: now))} · ${daily.title}';
  }

  NotificationDetails get _reminderDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '纪念日当天（或提前几天）提醒你',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      );

  /// 通知栏常驻倒计时：离今天最近的那条。
  ///
  /// 刻意**不开前台服务** —— 那要多一条 FOREGROUND_SERVICE 权限，而它做的事
  /// 只是把一行字钉在通知栏。代价是 Android 14+ 用户可以手动划掉，这是对的：
  /// 我们只在回到 App 或数据变化时重新贴上去，不做「划不掉」的流氓行为。
  Future<void> syncOngoing() async {
    if (!_ready) return;
    try {
      // 先撤掉旧的：开关刚被关掉时也得走这条路
      await _plugin.cancel(id: kOngoingId);
      if (!Settings.instance.ongoingNotification.value) return;

      final now = DateTime.now();
      final nearest = nearestReminder(DailyRepository.instance.items.value, now);
      if (nearest == null) return;

      await _plugin.show(
        id: kOngoingId,
        title: _liveBody(nearest.daily, now),
        body: '打开 $kAppName 看全部',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _ongoingChannelId,
            _ongoingChannelName,
            channelDescription: '把最近一个纪念日的倒计时钉在通知栏',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            showWhen: false,
            onlyAlertOnce: true,
            silent: true,
            category: AndroidNotificationCategory.status,
            visibility: NotificationVisibility.public,
          ),
        ),
        payload: '${nearest.daily.id}',
      );
    } catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'daily',
        context: ErrorDescription('更新常驻倒计时'),
      ));
    }
  }
}
