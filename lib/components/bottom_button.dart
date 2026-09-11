import 'package:daily/styles/colors.dart';
import 'package:daily/styles/text_style.dart';
import 'package:flutter/material.dart';

class BottomButton extends StatelessWidget {
  final String text;
  final double height;
  final VoidCallback handleOk;

  const BottomButton({
    super.key,
    required this.handleOk,
    required this.text,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: handleOk,
      child: Container(
        // Android 15 起强制 edge-to-edge，底部安全区要算进去，
        // 否则保存按钮会被手势条盖住
        margin: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom,
          left: 10,
          right: 10,
        ),
        height: height,
        decoration: BoxDecoration(
          color: colors.buttonPrimary,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Center(
          child: Text(text, style: AppTextStyles.of(context).primaryButtonStyle),
        ),
      ),
    );
  }
}
