import 'package:daily/data/cover_palette.dart';
import 'package:daily/model/cover.dart';
import 'package:daily/styles/colors.dart';
import 'package:daily/styles/text_style.dart';
import 'package:flutter/material.dart';

import 'cover_view.dart';

/// 表单顶部的封面色块。点开底部弹层：6 套渐变，或从相册挑一张。
///
/// 保留 2020 年那版「顶部整块就是封面，点它换图」的交互，
/// 只是把「只能选相册图」扩成「也能用代码画的渐变」。
class CoverPicker extends StatelessWidget {
  final Cover cover;
  final double height;
  final VoidCallback onPickPhoto;
  final ValueChanged<int> onPickGradient;

  const CoverPicker({
    super.key,
    required this.cover,
    required this.height,
    required this.onPickPhoto,
    required this.onPickGradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openSheet(context),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverView(cover: cover),
            const ColoredBox(color: Color(0x4D000000)),
            // 两个状态沿用 2020 年那版的文案：选了照片显示标语，
            // 还没选就显示「选择一张背景图片」
            if (cover is PhotoCover)
              const Center(
                child: Text('每个日子都值得纪念', style: AppTextStyles.headTextStyle),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(Icons.add, size: 24),
                    ),
                    const SizedBox(height: 5),
                    const Text('选择一张背景图片', style: AppTextStyles.chooseImageStyle),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      builder: (ctx) {
        // 从弹层自己的 ctx 取样式，而不是外面那个：弹层是独立路由，
        // 外面拿到的永远是打开那一刻的主题，翻主题它不会重画
        final styles = AppTextStyles.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选择封面', style: styles.shareTitleStyle),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < kCoverGradients.length; i++)
                      _GradientSwatch(
                        index: i,
                        selected: cover is GradientCover && (cover as GradientCover).index == i,
                        onTap: () {
                          Navigator.pop(ctx);
                          onPickGradient(i);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.of(ctx).onBackground,
                  ),
                  title: Text('从相册选择', style: styles.aboutMiddleStyle),
                  onTap: () {
                    Navigator.pop(ctx);
                    onPickPhoto();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GradientSwatch extends StatelessWidget {
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _GradientSwatch({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 58,
            decoration: BoxDecoration(
              gradient: gradientFor(index),
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: AppColors.of(context).highlight, width: 2)
                  : null,
            ),
            child: selected
                ? const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.check, size: 14, color: Colors.white),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(gradientName(index), style: AppTextStyles.of(context).aboutBottomStyle),
        ],
      ),
    );
  }
}
