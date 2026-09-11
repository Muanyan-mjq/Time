import 'dart:async';

import 'package:daily/components/time_mark.dart';
import 'package:daily/data/settings.dart';
import 'package:daily/styles/colors.dart';
import 'package:daily/styles/text_style.dart';
import 'package:daily/utils/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// 从后台回到前台，超过这么久才重新上锁。
///
/// 30 秒是刻意的宽松值：切出去回一条微信、看一眼日历就回来，不该被再挡一次。
/// 真正要防的是「手机离手一段时间」。
const Duration kLockGrace = Duration(seconds: 30);

/// 解锁遮挡页。
///
/// 它顶的是 `MaterialApp.home` 的位置（见 app.dart），**不是盖在首页上的
/// 一层半透明图**。两者看着差不多，但最近任务列表里的缩略图是照着实际画面
/// 截的：盖一层的话，那个缩略图仍然是首页内容，遮了个寂寞。
///
/// 说清楚边界：这是**遮罩**，不是加密。数据库和照片都是明文，连上电脑
/// 照样读得到。它挡的是「别人拿起你手机随手一翻」。
class LockPage extends StatefulWidget {
  /// 解锁成功。参数是「跳过」——设备上没有可用的锁屏凭据、系统弹不出验证框
  /// 这类没法靠重试解决的问题，用户选了跳过，本次启动就别再锁了。
  final void Function({required bool skipped}) onDone;

  const LockPage({super.key, required this.onDone});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  static final LocalAuthentication _auth = LocalAuthentication();

  bool _busy = false;

  /// 给用户看的一句原因。null = 没什么可说的（比如用户自己按了取消）。
  String? _hint;

  /// 是否已经出现「靠重试解决不了」的状况，需要给一条退路。
  bool _canSkip = false;

  @override
  void initState() {
    super.initState();
    // 等首帧画出来再弹系统验证框：不然用户先看到的是一片空白，
    // 然后验证框凭空蹦出来，不知道是谁弹的
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _hint = null;
    });

    try {
      final ok = await _auth.authenticate(
        localizedReason: '解锁 Time',
        // 不逼用户录指纹：没录就走系统锁屏密码，一样能挡住随手翻
        biometricOnly: false,
        // 验证框弹出来的这一下本身会让 App 短暂失焦，回来了接着验，
        // 别把它当成「被系统中断」
        persistAcrossBackgrounding: true,
      );
      if (!mounted) return;
      if (ok) {
        unawaited(successFeedback());
        widget.onDone(skipped: false);
        return;
      }
      setState(() {
        _busy = false;
        _hint = '没有通过验证';
        _canSkip = true;
      });
    } on LocalAuthException catch (e) {
      if (!mounted) return;
      _handleFailure(e);
    } catch (_) {
      // 平台通道层面的意外（插件没注册、Activity 不对之类）。
      // 宁可漏锁一次，也不能把人关在自己 App 外面。
      if (!mounted) return;
      setState(() {
        _busy = false;
        _hint = '验证没能启动';
        _canSkip = true;
      });
    }
  }

  void _handleFailure(LocalAuthException e) {
    final (hint, skippable) = switch (e.code) {
      // 用户自己按了取消，不用解释，也不用留后门
      LocalAuthExceptionCode.userCanceled ||
      LocalAuthExceptionCode.systemCanceled =>
        (null, false),
      LocalAuthExceptionCode.timeout || LocalAuthExceptionCode.authInProgress => (
          '验证没能完成，再试一次',
          false,
        ),
      LocalAuthExceptionCode.temporaryLockout => (
          '验证被系统暂时锁住了，用锁屏密码试试',
          true,
        ),
      LocalAuthExceptionCode.biometricLockout => (
          '指纹被锁住了，先用锁屏密码解锁一次',
          true,
        ),
      LocalAuthExceptionCode.noCredentialsSet => (
          '这台设备没有设置锁屏密码，隐私锁用不了',
          true,
        ),
      LocalAuthExceptionCode.noBiometricHardware ||
      LocalAuthExceptionCode.noBiometricsEnrolled => (
          '这台设备没有可用的指纹或人脸',
          true,
        ),
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable => (
          '指纹硬件暂时用不了',
          true,
        ),
      LocalAuthExceptionCode.uiUnavailable => ('系统没能弹出验证窗口', true),
      LocalAuthExceptionCode.deviceError ||
      LocalAuthExceptionCode.unknownError => ('验证出错了', true),
      // 插件以后新增的错误码不该变成一道打不开的门
      _ => ('验证没能完成', true),
    };

    if (e.code == LocalAuthExceptionCode.noCredentialsSet) {
      // 这台设备根本没有锁屏凭据，再锁一万次也过不去。把开关关掉，
      // 免得用户每次回来都撞在同一堵墙上 —— 设置里那句提示会告诉他为什么
      unawaited(Settings.instance.setLockEnabled(false));
    }

    setState(() {
      _busy = false;
      _hint = hint;
      _canSkip = skippable;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.statusBarOf(context),
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 34, color: colors.onBackgroundFaint),
              const SizedBox(height: 22),
              TimeWordmark(colors: colors),
              const SizedBox(height: 34),
              _buildUnlockButton(colors, styles),
              // 提示行的高度固定住，出不出文字都不带动上面的按钮
              SizedBox(
                height: 34,
                child: Center(
                  child: Text(
                    _hint ?? '',
                    textAlign: TextAlign.center,
                    style: styles.appTip.copyWith(color: colors.onBackgroundMuted),
                  ),
                ),
              ),
              if (_canSkip)
                TextButton(
                  onPressed: () {
                    unawaited(tapFeedback());
                    widget.onDone(skipped: true);
                  },
                  child: Text(
                    '先跳过',
                    // 用 muted 而不是 faint：这是验证失败时唯一的退路，
                    // faint 在浅底上只有 1.8:1 的对比度，读不出来就成了事故
                    style: styles.appTip.copyWith(color: colors.onBackgroundMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockButton(AppColors colors, AppTextStyles styles) {
    return SizedBox(
      width: 168,
      height: 46,
      child: Material(
        color: colors.buttonPrimary,
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: _busy ? null : _authenticate,
          child: Center(
            child: Text(
              _busy ? '验证中…' : '解锁',
              style: styles.primaryButtonStyle,
            ),
          ),
        ),
      ),
    );
  }
}
