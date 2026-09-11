import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:daily/components/bottom_button.dart';
import 'package:daily/constants.dart';
import 'package:daily/data/cover_palette.dart';
import 'package:daily/data/covers.dart';
import 'package:daily/model/cover.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/styles/colors.dart';
import 'package:daily/styles/dimens.dart';
import 'package:daily/styles/text_style.dart';
import 'package:daily/utils/date_util.dart';
import 'package:daily/utils/external_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// 分享海报。
///
/// 老版本那条 CustomPainter 管线不可救：背景层往 `(W-60)×(H-300)` 的矩形里画图、
/// 头像层 `scale(0.35)`、二维码层 `scale(0.25)`，坐标是硬编码的 1080 宽虚拟网格，
/// 能落对位置纯属巧合；而且三层的图源全是死链，海报上的大字还烤在背景图里。
/// 现在改成真正的 Flutter 布局，文字全部由代码画，天数/日期/标题自动填。
///
/// 一页一张，可以左右滑 —— 几十条记录的时候，「先关掉再去长按另一条」那种
/// 找法太笨了。
class PosterPage extends StatefulWidget {
  /// 可以左右滑动切换的记录。空列表 = 只渲染一张宣传卡
  /// （关于页的「分享给好友」走这条路）。
  final List<Daily> dailies;

  /// 打开时停在第几张。越界会被夹回合法范围。
  final int initialIndex;

  const PosterPage({super.key, this.dailies = const [], this.initialIndex = 0});

  @override
  State<PosterPage> createState() => _PosterPageState();
}

class _PosterPageState extends State<PosterPage> {
  /// 每页一个边界 key：截图截的是当前这张自己的 RepaintBoundary。
  final Map<int, GlobalKey> _boundaries = {};

  /// 每页解析好的封面。`resolveCover` 会走一次文件存在性检查，build 里
  /// 每次重算不值得，而且滑回来时对象还得是同一个。
  final Map<int, Cover> _covers = {};

  /// 封面已经解码完的页。
  ///
  /// 首次截图前必须把照片解码完，否则打开页面立刻点分享会截到一张没有背景的图。
  /// 这是 Flutter 海报类功能最常见的 bug。
  final Set<int> _ready = {};

  late final PageController _controller = PageController(initialPage: _clamp(widget.initialIndex));

  late int _index = _clamp(widget.initialIndex);

  bool _busy = false;

  int get _pageCount => widget.dailies.isEmpty ? 1 : widget.dailies.length;

  int _clamp(int index) => index.clamp(0, _pageCount - 1);

  Daily? _dailyAt(int index) => widget.dailies.isEmpty ? null : widget.dailies[index];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_prime(_index));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _prime(int index) async {
    if (_ready.contains(index)) return;
    final cover = _coverAt(index);
    if (cover is PhotoCover) {
      await precacheImage(FileImage(File(cover.path)), context);
      if (!mounted) return;
    }
    setState(() => _ready.add(index));
  }

  Cover _coverAt(int index) {
    return _covers.putIfAbsent(index, () {
      final d = _dailyAt(index);
      return resolveCover(
        coverKey: d?.coverKey,
        imageUrl: d?.imageUrl,
        locate: Covers.instance.locate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.statusBarOf(context),
      child: Scaffold(
        backgroundColor: AppColors.of(context).background,
        appBar: AppBar(
          backgroundColor: AppColors.of(context).background,
          elevation: 0,
          centerTitle: true,
          title: Text('分享海报', style: AppTextStyles.of(context).shareTitleStyle),
        ),
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pageCount,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  unawaited(_prime(i));
                },
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Center(
                    // FittedBox 是 preview 的缩放，必须放在 RepaintBoundary **外面**：
                    // toImage 光栅化的是 boundary 自己那一层，忽略祖先变换，
                    // 所以不管预览被缩到多小，输出永远是 1080×1920。放里面就会截到缩小版。
                    child: FittedBox(fit: BoxFit.contain, child: _buildPoster(i)),
                  ),
                ),
              ),
            ),
            if (_pageCount > 1) _buildPagerHint(),
            const SizedBox(height: 12),
          ],
        ),
        bottomNavigationBar: Row(
          children: [
            Expanded(child: _buildSaveButton()),
            Expanded(child: BottomButton(text: '分享', height: 60, handleOk: _share)),
          ],
        ),
      ),
    );
  }

  /// 页码提示。列表短的时候用圆点 —— 「还能往右滑」这件事一眼就能看出来；
  /// 长了换成一串数字，十几个圆点会糊成一条虚线。
  Widget _buildPagerHint() {
    final colors = AppColors.of(context);
    if (_pageCount <= 8) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _pageCount; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _index ? colors.onBackground : colors.divider,
                ),
                child: const SizedBox(width: 6, height: 6),
              ),
            ),
        ],
      );
    }
    return Text(
      '${_index + 1} / $_pageCount',
      style: AppTextStyles.of(context).aboutStyle.copyWith(color: colors.onBackgroundMuted),
    );
  }

  Widget _buildSaveButton() {
    final enabled = _ready.contains(_index) && !_busy;
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: enabled ? _saveToGallery : null,
      child: Container(
        height: 60,
        margin: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom,
          left: 10,
          right: 10,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? colors.onBackgroundMuted : colors.onBackgroundFaint,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Center(
          child: Text(
            _busy ? '处理中…' : '保存到相册',
            style: TextStyle(
              color: enabled ? colors.onBackground : colors.onBackgroundMuted,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoster(int index) {
    final daily = _dailyAt(index);
    return RepaintBoundary(
      key: _boundaries.putIfAbsent(index, () => GlobalKey()),
      // 固定尺寸画布上这是不可协商的：用户把系统字体调到 1.3× 时 Column 会撑过
      // 640px，黄黑溢出条纹会被烤进分享出去的图里
      child: MediaQuery.withNoTextScaling(
        child: SizedBox(
          width: kPosterWidth,
          height: kPosterHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackground(_coverAt(index)),
              // 上下压暗保文字可读，中间透出照片
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x8C000000), Color(0x26000000), Color(0xB8000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                child: daily == null ? _buildPromoContent() : _buildDailyContent(daily),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(Cover cover) {
    return switch (cover) {
      PhotoCover(:final path) => Image.file(File(path), fit: BoxFit.cover),
      GradientCover(:final index) => DecoratedBox(decoration: BoxDecoration(gradient: gradientFor(index))),
    };
  }

  /// 宣传卡模式下标语要放到中间放大显示，这里就不再重复一遍。
  Widget _buildBrand({bool withSlogan = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          kAppName,
          style: TextStyle(
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 5,
            fontFamily: 'Dongqing',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          withSlogan ? '$kAppSubName · $kAppSlogan' : kAppSubName,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.7),
            fontFamily: 'Dongqing',
          ),
        ),
      ],
    );
  }

  /// 数据库空的时候只有字标和标语
  Widget _buildPromoContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBrand(withSlogan: false),
        const Spacer(),
        Align(
          alignment: Alignment.center,
          child: Text(
            kAppSlogan,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              height: 1.6,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontFamily: 'Dongqing',
            ),
          ),
        ),
        const Spacer(),
        _buildFooter(null),
      ],
    );
  }

  Widget _buildDailyContent(Daily d) {
    // 不能写成「一定有位」：老库里的记录、或者从别处导进来的记录，
    // targetDay 可能是空串或写坏的值。首页卡片对这种情况显示「日期待补充」，
    // 海报必须同样兜住 —— 这里抛异常会让整页变成报错屏，连返回按钮都没有
    final date = d.date;
    int? signedDays;
    ({int years, int months, int days})? ymd;
    if (date != null) {
      // 倒计时指向下一次重复日，年龄指向起始日 —— 和首页卡片、详情页同源
      final next = d.nextDate;
      if (next != null) signedDays = signedDaysFromToday(next);
      ymd = splitYmd(DateTime.now(), date);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBrand(),
        const Spacer(),
        Text(
          d.headText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.72),
            fontFamily: 'Dongqing',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          d.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 34,
            height: 1.25,
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontFamily: 'Dongqing',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          date == null ? d.targetDay : fmtDisplay(date),
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.65),
            fontFamily: 'Dongqing',
          ),
        ),
        const SizedBox(height: 16),
        if (signedDays == null)
          Text(
            '日期待补充',
            style: TextStyle(
              fontSize: 26,
              height: 1.0,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
              fontFamily: 'Dongqing',
            ),
          )
        else ...[
          _buildCountRow(signedDays),
          if (signedDays != 0 && ymd != null) ...[
            const SizedBox(height: 6),
            _buildYmd(ymd),
          ],
        ],
        const Spacer(),
        _buildFooter(d),
      ],
    );
  }

  Widget _buildCountRow(int days) {
    final labelStyle = TextStyle(
      fontSize: 13,
      color: Colors.white.withValues(alpha: 0.7),
      fontFamily: 'Dongqing',
    );
    if (days == 0) {
      return const Text(
        '就是今天',
        style: TextStyle(
          fontSize: 32,
          height: 1.0,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontFamily: 'Dongqing',
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(days > 0 ? '还有' : '已经', style: labelStyle),
        const SizedBox(width: 6),
        Text(
          '${days.abs()}',
          style: const TextStyle(
            fontSize: 46,
            height: 1.0,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'Dongqing',
          ),
        ),
        const SizedBox(width: 4),
        Text('天', style: labelStyle),
      ],
    );
  }

  Widget _buildYmd(({int years, int months, int days}) ymd) {
    return Text(
      '${ymd.years}年${ymd.months}个月${ymd.days}天',
      style: TextStyle(
        fontSize: 10.5,
        color: Colors.white.withValues(alpha: 0.5),
        fontFamily: 'Dongqing',
      ),
    );
  }

  Widget _buildFooter(Daily? daily) {
    // 宣传卡模式下中间已经有大标语了，这里再放一遍 remark 就重复了
    final remark = daily?.remark.trim() ?? '';
    final showRow = remark.isNotEmpty || kPosterShareUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showRow) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  remark,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.62),
                    fontFamily: 'Dongqing',
                  ),
                ),
              ),
              // 留空就必须什么都不画 —— qr_flutter 收到空 data 会断言失败。
              // 二维码和 remark 并排，所以留空时 remark 自动占满，没有幽灵边距。
              if (kPosterShareUrl.isNotEmpty) ...[
                const SizedBox(width: 14),
                _buildQr(),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text(
          '由「$kAppName」生成',
          style: TextStyle(
            fontSize: 9.5,
            color: Colors.white.withValues(alpha: 0.35),
            fontFamily: 'Dongqing',
          ),
        ),
      ],
    );
  }

  Widget _buildQr() {
    return ClipRRect(
      // 二维码底下必须垫白板，直接画在照片上扫不出来
      borderRadius: BorderRadius.circular(6),
      child: QrImageView(
        data: kPosterShareUrl,
        version: QrVersions.auto,
        size: 62,
        padding: const EdgeInsets.all(4),
        backgroundColor: Colors.white,
      ),
    );
  }

  /// 截当前这张。滑走的那张不截 —— 用户按的是眼前这张的「保存 / 分享」。
  Future<Uint8List> _capture() async {
    final boundaryContext = _boundaries[_index]?.currentContext;
    if (boundaryContext == null) {
      // 只可能是「当前页还没被建出来」，正常滑不到这种状态
      throw StateError('海报还没准备好');
    }
    final boundary = boundaryContext.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: kPosterPixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _saveToGallery() async {
    if (_busy || !_ready.contains(_index)) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      await Gal.putImageBytes(bytes, name: 'shiguang_${DateTime.now().millisecondsSinceEpoch}');
      showToast('成功保存到相册！');
    } catch (e) {
      showToast('保存失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    // 照片还没解码完就截图，得到的是一张没有背景的图
    if (!_ready.contains(_index)) {
      showToast('图片还在加载，请稍候…');
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      // 写真实临时文件再交给 SharePlus，比传内存 XFile 在各版本间更稳
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'shiguang_${DateTime.now().millisecondsSinceEpoch}.png'));
      await file.writeAsBytes(bytes, flush: true);
      // 分享面板是外部界面，用户可能在里面翻半天，别让它把表单顶掉
      await ExternalFlow.run(
        () => SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: kAppSlogan),
        ),
      );
      await _cleanOldTempFiles(dir);
    } catch (e) {
      showToast('分享失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 免得分享面板里堆一串候选图
  Future<void> _cleanOldTempFiles(Directory dir) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    await for (final e in dir.list()) {
      if (e is! File || !p.basename(e.path).startsWith('shiguang_')) continue;
      if ((await e.stat()).modified.isAfter(cutoff)) continue;
      await e.delete();
    }
  }
}
