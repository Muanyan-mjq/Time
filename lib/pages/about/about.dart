import 'dart:async';
import 'dart:math';

import 'package:daily/constants.dart';
import 'package:daily/data/notifications.dart';
import 'package:daily/data/settings.dart';
import 'package:daily/pages/poster.dart';
import 'package:daily/styles/colors.dart';
import 'package:daily/styles/dimens.dart';
import 'package:daily/styles/text_style.dart';
import 'package:daily/utils/haptics.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:oktoast/oktoast.dart';
import 'package:url_launcher/url_launcher.dart';

/// 仓库首页就是 README，功能介绍在那里
const String _urlFeatures = kRepoUrl;
const String _urlIssues = '$kRepoUrl/issues/new';
const String _urlProfile = 'https://github.com/Muanyan-mjq';
const String _urlAgreement = kRepoUrl;

class About extends StatelessWidget {
  const About({super.key});

  /// 只用来问一句「这台设备有没有可用的验证方式」，真正的验证在锁页里做
  static final LocalAuthentication _auth = LocalAuthentication();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Scaffold(
      body: Container(
        color: colors.background,
        child: Stack(
          children: [
            Positioned(
              top: MediaQuery.paddingOf(context).top,
              left: kAboutBackInset,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.pop(context, false),
                child: SizedBox(
                  height: kAboutBackSize,
                  width: kAboutBackSize,
                  child: Icon(Icons.arrow_back, color: colors.onBackground),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(kAboutArcSize, kAboutArcSize),
                painter: MyPainterTopRight(
                  MediaQuery.sizeOf(context).width,
                  MediaQuery.sizeOf(context).height,
                ),
              ),
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              child: CustomPaint(
                size: Size(kAboutBlobSize, kAboutBlobSize),
                painter: MyPainterBottomLeft(),
              ),
            ),
            const Positioned(
              top: kAboutMarkTop,
              left: kAboutMarkLeft,
              child: SizedBox(
                width: kAboutMarkSize,
                height: kAboutMarkSize,
                child: Image(image: AssetImage('assets/images/app.png'), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: kAboutVersionTop,
              left: kAboutVersionLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kAppVersion, style: styles.aboutStyle),
                  const SizedBox(height: kAboutRowGap),
                  Text('这是一款能够留住时光的APP', style: styles.aboutStyle),
                ],
              ),
            ),
            Positioned(
              left: kAboutSettingsLeft,
              // 上下都钉。屏幕够高时是下边那条线说了算，位置和原来一样；
              // 矮屏上顶边会把这一栏拦住，让它自己滚。只钉底边的话，
              // 这一栏是后画的，会正好盖住上面那两行版本号。
              top: kAboutSettingsTop,
              bottom: MediaQuery.paddingOf(context).bottom + kAboutSettingsBottom,
              child: SizedBox(
                width: kAboutSettingsWidth,
                child: SingleChildScrollView(
                  // reverse 让它永远贴着底边：内容比视口矮时，不 reverse 会
                  // 贴着顶边摆，那一栏就浮到屏幕中间去了
                  reverse: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMiddleItem(
                        context: context,
                        title: '功能介绍',
                        asset: 'assets/images/list.png',
                        size: 36,
                        action: () => _openUrl(context, _urlFeatures),
                      ),
                      _buildMiddleItem(
                        context: context,
                        title: '与作者联系',
                        asset: 'assets/images/email.png',
                        size: 30,
                        action: () => _openUrl(context, _urlIssues),
                      ),
                      _buildMiddleItem(
                        context: context,
                        title: '分享给好友',
                        asset: 'assets/images/air.png',
                        size: 30,
                        action: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const PosterPage(),
                        )),
                      ),
                      _buildThemeItem(),
                      _buildOngoingItem(),
                      _buildLockItem(),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: kAboutFooterInset,
              bottom: MediaQuery.paddingOf(context).bottom + kAboutFooterInset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => _openUrl(context, _urlProfile),
                    child: Text('Muanyan 温情出品', style: styles.aboutBottomStyle),
                  ),
                  const SizedBox(height: kAboutFooterGap),
                  GestureDetector(
                    onTap: () => _openUrl(context, _urlAgreement),
                    child: Text('隐私协议 软件使用协议 官方地址', style: styles.aboutBottomStyle),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiddleItem({
    required BuildContext context,
    required String asset,
    required String title,
    required double size,
    required VoidCallback action,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: action,
      child: Row(
        children: [
          Image.asset(asset, width: size, height: size),
          const SizedBox(width: kAboutRowGap),
          Text(title, style: AppTextStyles.of(context).aboutMiddleStyle),
        ],
      ),
    );
  }

  /// 首页 FAB 弹层里那个开关之外，关于页也留一个入口 ——
  /// 关于页是最像「设置」的地方，找主题的人第一反应会来这里
  Widget _buildThemeItem() {
    return ValueListenableBuilder<bool>(
      valueListenable: Settings.instance.darkMode,
      builder: (context, dark, _) {
        void toggle(bool value) {
          unawaited(toggleFeedback());
          unawaited(Settings.instance.setDarkMode(value));
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          // 整行都能点，不然只有那小滑块可点，很容易按空
          onTap: () => toggle(!dark),
          child: Row(
            children: [
              Icon(
                dark ? Icons.brightness_2 : Icons.brightness_5,
                size: kAboutSwitchIcon,
                color: AppColors.of(context).onBackground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('深色模式', style: AppTextStyles.of(context).aboutMiddleStyle),
              ),
              Switch(value: dark, onChanged: toggle),
            ],
          ),
        );
      },
    );
  }

  /// 通知栏常驻倒计时。默认关，开关一拨就由 `NotificationService` 自己贴上去 / 撤下来。
  ///
  /// 关于页是 App 里最像「设置」的地方，所以第二档设置也放这儿，
  /// 不为两个布尔值再开一页。
  Widget _buildOngoingItem() {
    return ValueListenableBuilder<bool>(
      valueListenable: Settings.instance.ongoingNotification,
      builder: (context, on, _) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _toggleOngoing(!on),
        child: Row(
          children: [
            Icon(
              on ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
              size: kAboutSwitchIcon,
              color: AppColors.of(context).onBackground,
            ),
            const SizedBox(width: kAboutRowGap),
            Expanded(
              child: Text('通知栏倒计时', style: AppTextStyles.of(context).aboutMiddleStyle),
            ),
            Switch(value: on, onChanged: _toggleOngoing),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleOngoing(bool value) async {
    unawaited(toggleFeedback());
    // 打开得先有通知权限，否则贴上去也看不见
    if (value) await NotificationService.instance.requestPermissions();
    await Settings.instance.setOngoingNotification(value);
  }

  /// 隐私锁。第三档设置，和上面两个开关同一套写法。
  ///
  /// 名字叫「锁」，但它是**遮罩不是加密** —— 挡的是「别人拿起你手机随手翻」，
  /// 数据库和照片仍是明文，连上电脑照样读得到。这个说法要和 README 一致。
  Widget _buildLockItem() {
    return ValueListenableBuilder<bool>(
      valueListenable: Settings.instance.lockEnabled,
      builder: (context, on, _) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _toggleLock(!on),
        child: Row(
          children: [
            Icon(
              on ? Icons.lock_outline : Icons.lock_open_outlined,
              size: kAboutSwitchIcon,
              color: AppColors.of(context).onBackground,
            ),
            const SizedBox(width: kAboutRowGap),
            Expanded(
              child: Text('隐私锁', style: AppTextStyles.of(context).aboutMiddleStyle),
            ),
            Switch(value: on, onChanged: _toggleLock),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLock(bool value) async {
    unawaited(toggleFeedback());
    if (!value) {
      await Settings.instance.setLockEnabled(false);
      return;
    }
    // 开启前先确认这台设备有东西可以验。没有锁屏密码也没有指纹的话，
    // 开了就是把自己关在 App 外面 —— 这一步只查询、不弹框，
    // 弹框留给真正上锁的时候
    final supported = await _auth.isDeviceSupported();
    if (!supported) {
      showToast('这台设备没有设置锁屏密码，开了就没法解锁');
      return;
    }
    await Settings.instance.setLockEnabled(true);
    showToast('下次进入 $kAppName 需要验证');
  }

  /// 交给系统浏览器，App 里就不用再背一个 webview_flutter，
  /// 也就不用申请 INTERNET 权限
  Future<void> _openUrl(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) showToast('打不开这个链接');
  }
}

class MyPainterTopRight extends CustomPainter {
  final double screenWitdh;
  final double screenHeight;

  const MyPainterTopRight(this.screenWitdh, this.screenHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = const Color.fromRGBO(93, 92, 238, 0.9)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 80
      ..style = PaintingStyle.stroke;

    final center = Offset(screenWitdh - 30, 0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width / 2),
      pi / 2,
      2 * pi * 0.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class MyPainterBottomLeft extends CustomPainter {
  const MyPainterBottomLeft();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = const Color.fromRGBO(33, 255, 217, 1)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 100
      ..style = PaintingStyle.fill;
    // 圆心落在方框底边的左端点上，所以 y 读 size.height 而不是写死 ——
    // 改画布大小的时候圆跟着底边走，不会跟画布脱开
    canvas.drawCircle(Offset(0, size.height), 140, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
