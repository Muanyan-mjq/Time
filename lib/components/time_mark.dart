import 'package:daily/constants.dart';
import 'package:daily/styles/colors.dart';
import 'package:flutter/material.dart';

/// 「Time / 时光」两行字。
///
/// 启动遮罩和隐私锁共用同一枚 —— 两处都靠它说明「这是哪个 App」，
/// 各写一份迟早会走样成一个大一个小的两张脸。
///
/// 颜色由调用方给，不在这里 `AppColors.of(context)`：启动遮罩恒用浅色那套
/// （native 启动图无从知道用户的深色设置），可它底下压着的有可能是深色首页，
/// 按 context 取色会在淡出的那一瞬间跳一下。
class TimeWordmark extends StatelessWidget {
  final AppColors colors;

  const TimeWordmark({super.key, this.colors = AppColors.light});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kAppName,
          style: TextStyle(
            fontSize: 22,
            letterSpacing: 4,
            fontWeight: FontWeight.bold,
            fontFamily: 'Conspired',
            color: colors.onBackground,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          kAppSubName,
          style: TextStyle(
            fontSize: 24,
            letterSpacing: 10,
            fontWeight: FontWeight.w100,
            fontFamily: 'Dongqing',
            color: colors.onBackgroundMuted,
          ),
        ),
      ],
    );
  }
}
