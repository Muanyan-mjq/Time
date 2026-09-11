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
class PosterPage extends StatefulWidget {
  /// null = 数据库里还没有纪念日，渲染一张只有字标和标语的宣传卡。
  final Daily? daily;

  const PosterPage({super.key, this.daily});

  @override
  State<PosterPage> createState() => _PosterPageState();
}

class _PosterPageState extends State<PosterPage> {
  final GlobalKey _boundaryKey = GlobalKey();

  /// 首次截图前必须把照片解码完，否则打开页面立刻点分享会截到一张没有背景的图。
  /// 这是 Flutter 海报类功能最常见的 bug。
  bool _ready = false;
  bool _busy = false;

  late Cover _cover;
  int? _signedDays;
  ({int years, int months, int days})? _ymd;

  @override
  void initState() {
    super.initState();
    final d = widget.daily;
    _cover = resolveCover(
      coverKey: d?.coverKey,
      imageUrl: d?.imageUrl,
      locate: Covers.instance.locate,
    );
    final date = d?.date;
    if (date != null) {
      // 倒计时指向下一次重复日，年龄指向起始日 —— 和首页卡片、详情页同源
      final next = d?.nextDate;
      if (next != null) _signedDays = signedDaysFromToday(next);
      _ymd = splitYmd(DateTime.now(), date);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prime();
  }

  Future<void> _prime() async {
    if (_ready) return;
    final cover = _cover;
    if (cover is PhotoCover) {
      await precacheImage(FileImage(File(cover.path)), context);
      if (!mounted) return;
    }
    setState(() => _ready = true);
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Center(
                  // FittedBox 是 preview 的缩放，必须放在 RepaintBoundary **外面**：
                  // toImage 光栅化的是 boundary 自己那一层，忽略祖先变换，
                  // 所以不管预览被缩到多小，输出永远是 1080×1920。放里面就会截到缩小版。
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: _buildPoster(),
                  ),
                ),
              ),
            ),
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

  Widget _buildSaveButton() {
    final enabled = _ready && !_busy;
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

  Widget _buildPoster() {
    return RepaintBoundary(
      key: _boundaryKey,
      // 固定尺寸画布上这是不可协商的：用户把系统字体调到 1.3× 时 Column 会撑过
      // 640px，黄黑溢出条纹会被烤进分享出去的图里
      child: MediaQuery.withNoTextScaling(
        child: SizedBox(
          width: kPosterWidth,
          height: kPosterHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackground(),
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
                child: widget.daily == null ? _buildPromoContent() : _buildDailyContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return switch (_cover) {
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
        _buildFooter(),
      ],
    );
  }

  Widget _buildDailyContent() {
    final d = widget.daily!;
    // 不能写成 _signedDays!：老库里的记录、或者从别处导进来的记录，
    // targetDay 可能是空串或写坏的值。首页卡片对这种情况显示「日期待补充」，
    // 海报必须同样兜住 —— 这里抛异常会让整页变成报错屏，连返回按钮都没有
    final days = _signedDays;
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
          d.date == null ? d.targetDay : fmtDisplay(d.date!),
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.65),
            fontFamily: 'Dongqing',
          ),
        ),
        const SizedBox(height: 16),
        if (days == null)
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
          _buildCountRow(days),
          if (days != 0 && _ymd != null) ...[
            const SizedBox(height: 6),
            _buildYmd(_ymd!),
          ],
        ],
        const Spacer(),
        _buildFooter(),
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

  Widget _buildFooter() {
    // 宣传卡模式下中间已经有大标语了，这里再放一遍 remark 就重复了
    final remark = widget.daily?.remark.trim() ?? '';
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

  Future<Uint8List> _capture() async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: kPosterPixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _saveToGallery() async {
    if (!_ready || _busy) return;
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
    if (!_ready) {
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
