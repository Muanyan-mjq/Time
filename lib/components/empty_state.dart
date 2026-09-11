import 'package:daily/styles/colors.dart';
import 'package:daily/styles/text_style.dart';
import 'package:flutter/material.dart';

/// 空态与加载态。
///
/// 抽出来是因为「图标 + 主文案 + 一句引导」这套排版首页和时光轴各有一份，
/// 两处各写一遍的话早晚会一处改了、另一处没改 —— 这种不一致单看每一屏
/// 都不觉得，来回切两次就露馅了。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;

  /// 可选的下一步入口（比如「添加第一条」）。
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final action = this.action;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: colors.onBackgroundFaint),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: styles.emptyTitleStyle),
          const SizedBox(height: 8),
          Text(hint, textAlign: TextAlign.center, style: styles.emptyHintStyle),
          if (action != null) ...[const SizedBox(height: 26), action],
        ],
      ),
    );
  }
}

/// 加载态。22 像素、2 像素线宽是 2020 年的取值，那会儿首页就长这样。
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.of(context).onBackgroundFaint,
        ),
      ),
    );
  }
}
