import 'package:daily/styles/colors.dart';
import 'package:daily/styles/dimens.dart';
import 'package:daily/styles/iconfont.dart';
import 'package:daily/styles/text_style.dart';
import 'package:flutter/material.dart';

/// 删除纪念日的确认文案。表单页和首页长按菜单共用一份 ——
/// 两处各写一遍的话，改文案时一定漏一个。
const String kDeleteDailyConfirm = '确定删除该纪念日吗？';

/// 弹一个确认框，用户点了「确定」才返回 true。
///
/// 用 `CustomDialog` 的 `pop(1)` 做返回值，而不是它的 `confirmCallback`：
/// 那个回调是在关闭动画之后才触发的，包成 Future 才好 await。
Future<bool> _confirm(
  BuildContext context, {
  required String content,
  required IconData icon,
  required String confirmContent,
}) async {
  // 确认框经常是 await 完外部界面（选择器、分享面板）之后才弹的，
  // 这中间发起它的页面可能已经被换掉（比如隐私锁）—— 那时 showDialog
  // 会直接抛，恢复流程断在半路。当作「用户取消」处理，让它干净收场
  if (!context.mounted) return false;
  final result = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => CustomDialog(
      content: Center(
        child: Column(
          children: [
            Icon(icon, size: 36),
            Container(
              padding: const EdgeInsets.only(top: 20),
              child: Text(content, style: AppTextStyles.of(dialogContext).deleteStyle),
            ),
          ],
        ),
      ),
      confirmContent: confirmContent,
      cancelContent: '取消',
      isCancel: true,
    ),
  );
  return result == 1;
}

/// 弹一个删除确认框。
Future<bool> confirmDelete(
  BuildContext context, {
  String content = kDeleteDailyConfirm,
}) =>
    _confirm(
      context,
      content: content,
      icon: Iconfont.comfirm,
      confirmContent: '确定',
    );

/// 恢复备份前的二次确认。
///
/// 「覆盖」这件事用户只有这一次机会看明白，所以两个数字都要摆出来 ——
/// 会清掉现有几条、会恢复几条。确认键写「恢复」而不是「确定」，
/// 让最后一下点下去之前还能再看一眼自己按的是什么。
Future<bool> confirmRestore(
  BuildContext context, {
  required int existing,
  required int incoming,
}) =>
    _confirm(
      context,
      content: '将清空现有 $existing 条记录，恢复 $incoming 条，确定吗？',
      icon: Icons.warning_amber_rounded,
      confirmContent: '恢复',
    );

/// 自定义 Dialog。取值沿用 2020 年那版，只把已经移除的
/// `FlatButton` 换成 `TextButton`、`WillPopScope` 换成 `PopScope`。
class CustomDialog extends StatelessWidget {
  final String? title;
  final TextStyle? titleStyle;
  final Widget content;
  final String? confirmContent;
  final String? cancelContent;
  final Color? confirmTextColor;
  final bool isCancel;
  final Color? confirmColor;
  final Color? cancelColor;
  final Color? cancelTextColor;
  final bool outsideDismiss;
  final VoidCallback? confirmCallback;
  final VoidCallback? dismissCallback;

  const CustomDialog({
    super.key,
    this.title,
    required this.content,
    this.confirmContent,
    this.confirmTextColor,
    this.isCancel = true,
    this.confirmColor,
    this.outsideDismiss = false,
    this.confirmCallback,
    this.dismissCallback,
    this.titleStyle,
    this.cancelContent,
    this.cancelTextColor,
    this.cancelColor,
  });

  void _confirm(BuildContext context) {
    Navigator.of(context).pop(1);
    // 等关闭动画走完再回调，老代码是 250ms，保持不变
    Future.delayed(const Duration(milliseconds: 250), () => confirmCallback?.call());
  }

  void _dismiss(BuildContext context) {
    Navigator.of(context).pop(0);
    Future.delayed(const Duration(milliseconds: 250), () => dismissCallback?.call());
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final colors = AppColors.of(context);

    return PopScope(
      canPop: outsideDismiss,
      child: GestureDetector(
        onTap: () {
          if (outsideDismiss) _dismiss(context);
        },
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: Container(
              width: width - kDialogInsetH * 2,
              height: kDialogHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(kDialogRadius),
              ),
              child: Column(
                children: <Widget>[
                  SizedBox(height: title == null ? 0 : 15.0),
                  SizedBox(
                    height: kDialogTitleHeight,
                    child: Text(title ?? '', style: titleStyle),
                  ),
                  SizedBox(
                    height: kDialogContentHeight,
                    child: Center(child: content),
                  ),
                  SizedBox(height: 0.5, child: ColoredBox(color: colors.divider)),
                  SizedBox(
                    height: kDialogButtonHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: isCancel ? 1 : 0,
                          child: isCancel
                              ? _button(
                                  context: context,
                                  label: cancelContent ?? '取消',
                                  color: cancelColor,
                                  textColor: cancelColor == null
                                      ? (cancelTextColor ?? colors.onBackground)
                                      // 调用方给了底色就用配对的「底上的字」，
                                      // 不能写死白色 —— 暗色下 buttonPrimary 本身
                                      // 已经是接近白的，白字就看不见了
                                      : (cancelTextColor ?? colors.onButtonPrimary),
                                  radius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(kDialogRadius),
                                  ),
                                  onTap: () => _dismiss(context),
                                )
                              : const Text(''),
                        ),
                        SizedBox(
                          width: isCancel ? 1.0 : 0,
                          child: ColoredBox(color: colors.divider),
                        ),
                        Expanded(
                          flex: 1,
                          child: _button(
                            context: context,
                            label: confirmContent ?? '确定',
                            color: confirmColor,
                            textColor: confirmColor == null
                                ? (confirmTextColor ?? colors.onBackground)
                                : (confirmTextColor ?? colors.onButtonPrimary),
                            radius: isCancel
                                ? const BorderRadius.only(
                                    bottomRight: Radius.circular(kDialogRadius),
                                  )
                                : const BorderRadius.only(
                                    bottomLeft: Radius.circular(kDialogRadius),
                                    bottomRight: Radius.circular(kDialogRadius),
                                  ),
                            onTap: () => _confirm(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _button({
    required BuildContext context,
    required String label,
    required Color? color,
    required Color textColor,
    required BorderRadius radius,
    required VoidCallback onTap,
  }) {
    final bg = color ?? AppColors.of(context).surface;
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: textColor,
          // 老代码把 splash / highlight 设成按钮自己的底色，等于不要水波
          overlayColor: Colors.transparent,
          shape: const RoundedRectangleBorder(),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w100,
            fontFamily: 'Dongqing',
            color: textColor,
          ),
        ),
      ),
    );
  }
}
