import 'package:daily/styles/colors.dart';
import 'package:daily/styles/text_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 阶段 1 的守卫。
///
/// 双套调色板最容易出的错不是「暗色不好看」，而是：
/// ① 亮色被顺手改掉了一个值 —— 那版配色是 2020 年定下来的设计语言，不该动；
/// ② 暗色是复制亮色改的，漏改了某几个 token —— 肉眼很难发现；
/// ③ 贴在照片上的白字被一起主题化了 —— 在深色照片上直接读不出来。
/// 这三条都靠测试钉住。
void main() {
  group('亮色 = 2020 年那版，取值不许变', () {
    test('页面底色是不透明的 #FBFBFC，和 native 的 @color/app_background 逐字一致', () {
      expect(AppColors.light.background, const Color(0xFFFBFBFC));
      expect(
        AppColors.light.background.a,
        1.0,
        reason: '半透明底会叠在 Flutter 画布的黑底上，首页会整片发黑',
      );
    });

    test('其余 token 保持原样', () {
      expect(AppColors.light.surface, const Color(0xFFFFFFFF));
      expect(AppColors.light.sheet, const Color(0xFFF5F5F5));
      expect(AppColors.light.buttonPrimary, const Color(0xFF000000));
      expect(AppColors.light.onButtonPrimary, const Color(0xFFFFFFFF));
    });
  });

  group('暗色', () {
    test('底色 #121212，主按钮反过来', () {
      expect(AppColors.dark.background, const Color(0xFF121212));
      expect(AppColors.dark.buttonPrimary, const Color(0xFFEDEDED));
      expect(AppColors.dark.onButtonPrimary, const Color(0xFF121212));
    });

    test('每个 token 都和亮色不一样，逐个点名防漏改', () {
      expect(AppColors.light.background, isNot(AppColors.dark.background), reason: 'background');
      expect(AppColors.light.surface, isNot(AppColors.dark.surface), reason: 'surface');
      expect(AppColors.light.sheet, isNot(AppColors.dark.sheet), reason: 'sheet');
      expect(AppColors.light.buttonPrimary, isNot(AppColors.dark.buttonPrimary), reason: 'buttonPrimary');
      expect(AppColors.light.onButtonPrimary, isNot(AppColors.dark.onButtonPrimary), reason: 'onButtonPrimary');
      expect(AppColors.light.onBackground, isNot(AppColors.dark.onBackground), reason: 'onBackground');
      expect(
        AppColors.light.onBackgroundMuted,
        isNot(AppColors.dark.onBackgroundMuted),
        reason: 'onBackgroundMuted',
      );
      expect(
        AppColors.light.onBackgroundFaint,
        isNot(AppColors.dark.onBackgroundFaint),
        reason: 'onBackgroundFaint',
      );
      expect(AppColors.light.divider, isNot(AppColors.dark.divider), reason: 'divider');
      expect(AppColors.light.highlight, isNot(AppColors.dark.highlight), reason: 'highlight');
      expect(AppColors.light.aboutArc, isNot(AppColors.dark.aboutArc), reason: 'aboutArc');
      expect(AppColors.light.aboutBlob, isNot(AppColors.dark.aboutBlob), reason: 'aboutBlob');
    });

    test('关于页那两块装饰原样保留亮色的 2020 取值', () {
      expect(AppColors.light.aboutArc, const Color.fromRGBO(93, 92, 238, 0.9));
      expect(AppColors.light.aboutBlob, const Color(0xFF21FFD9));
      // 暗色是同一组色相压过饱和度的版本，不是换个颜色
      expect(AppColors.dark.aboutArc.r, AppColors.light.aboutArc.r);
      expect(AppColors.dark.aboutArc.g, AppColors.light.aboutArc.g);
      expect(AppColors.dark.aboutArc.b, AppColors.light.aboutArc.b);
      expect(AppColors.dark.aboutBlob.r, AppColors.light.aboutBlob.r);
      expect(AppColors.dark.aboutBlob.g, AppColors.light.aboutBlob.g);
      expect(AppColors.dark.aboutBlob.b, AppColors.light.aboutBlob.b);
    });
  });

  group('贴在封面上的 8 个样式永远白色', () {
    test('它们在照片和渐变上，主题化成灰字就读不出来了', () {
      const onCover = <String, TextStyle>{
        'titleTextStyle': AppTextStyles.titleTextStyle,
        'headTextStyle': AppTextStyles.headTextStyle,
        'targetDayStyle': AppTextStyles.targetDayStyle,
        'countTitleStyle': AppTextStyles.countTitleStyle,
        'countBottomTipStyle': AppTextStyles.countBottomTipStyle,
        'cateGoryTextStyle': AppTextStyles.cateGoryTextStyle,
        'chooseImageStyle': AppTextStyles.chooseImageStyle,
        'countdownStyle': AppTextStyles.countdownStyle,
      };
      onCover.forEach((name, style) {
        expect(style.color, Colors.white, reason: '$name 必须永远是白色');
      });
    });

    test('跟随主题的那 15 个都在两个实例里都给了值', () {
      for (final styles in [AppTextStyles.light, AppTextStyles.dark]) {
        expect(styles.appTitle.fontSize, 30);
        expect(styles.appTip.fontSize, 14);
        expect(styles.contentStyle.fontSize, 16);
        expect(styles.inputLabelStyle.fontSize, 16);
        expect(styles.inputHintStyle.fontSize, 15);
        expect(styles.inputValueStyle.fontSize, 16);
        expect(styles.deleteStyle.fontSize, 14);
        expect(styles.aboutStyle.fontSize, 14);
        expect(styles.aboutMiddleStyle.fontSize, 16);
        expect(styles.aboutBottomStyle.fontSize, 12);
        expect(styles.shareTitleStyle.fontSize, 16);
        expect(styles.groupTitleStyle.fontSize, 13);
        expect(styles.emptyTitleStyle.fontSize, 17);
        expect(styles.emptyHintStyle.fontSize, 13);
      }
    });
  });

  testWidgets('of(context) 跟着 Theme 的 brightness 走', (tester) async {
    final colors = <Brightness, AppColors>{};
    final styles = <Brightness, AppTextStyles>{};

    Widget probe() => Builder(
          builder: (context) {
            final brightness = Theme.of(context).brightness;
            colors[brightness] = AppColors.of(context);
            styles[brightness] = AppTextStyles.of(context);
            return const SizedBox.shrink();
          },
        );

    // 直接驱动 Theme，不绕 MaterialApp —— 这里要验的是 of(context) 的取法
    await tester.pumpWidget(Theme(data: ThemeData.light(), child: probe()));
    await tester.pumpWidget(Theme(data: ThemeData.dark(), child: probe()));

    expect(colors[Brightness.light], same(AppColors.light));
    expect(colors[Brightness.dark], same(AppColors.dark));
    expect(styles[Brightness.light]?.appTitle.color, Colors.black87);
    expect(styles[Brightness.dark]?.appTitle.color, const Color(0xFFEDEDED));
  });

  testWidgets('底部弹层读到的 Theme 是实时的 —— 翻主题时它跟着重画', (tester) async {
    // 这条钉的是 FAB 菜单那个弹层：深色模式的开关就摆在弹层里，开关一拨
    // 弹层必须立刻换成暗色，否则用户眼前是一个亮色弹层配一个暗色首页。
    //
    // 结论来自 Flutter 的实现：`showModalBottomSheet` 传的 `to` 是
    // **Navigator 的 context**，而 MaterialApp 的 `AnimatedTheme` 在
    // Navigator 之上，所以一个主题都没捕获到（`_themes` 为空），弹层里的
    // `Theme.of` 于是直通上面那个活的 Theme。哪天 Flutter 改成连
    // MaterialApp 的 Theme 一起捕获，这条会红 —— 那时就得在弹层内部
    // 自己拿 `Settings.darkMode` 重新盖一层 Theme。
    final mode = ValueNotifier<ThemeMode>(ThemeMode.light);
    final seen = <Brightness>[];

    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: mode,
        builder: (context, m, _) => MaterialApp(
          themeMode: m,
          theme: ThemeData(brightness: Brightness.light),
          darkTheme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (page) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: page,
                    builder: (sheetContext) => Builder(
                      builder: (inner) {
                        seen.add(AppColors.of(inner) == AppColors.dark
                            ? Brightness.dark
                            : Brightness.light);
                        return const SizedBox(width: 40, height: 40);
                      },
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(seen.last, Brightness.light);

    mode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    expect(seen.last, Brightness.dark, reason: '弹层没跟着主题重画，会停在旧配色上');
  });
}
