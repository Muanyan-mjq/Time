import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:daily/constants.dart';
import 'package:daily/data/cover_palette.dart';
import 'package:daily/utils/external_flow.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 落库原文 → 磁盘上的相对路径。
///
/// `coverKey` 一律带 `f:` 前缀（见 [Covers.keyFor]），而磁盘操作要的是
/// `covers/xxx.jpg`。少剥这一道就是一个「文件明明在、却说找不到」的坑：
/// 备份因此一张照片都打不进 zip，删除因此删不掉文件。所有入口统一走这里。
String coverStoragePath(String stored) =>
    stored.startsWith(kPhotoPrefix) ? stored.substring(kPhotoPrefix.length) : stored;

/// 照片封面的磁盘生命周期。
///
/// 老代码直接把 image_picker 的 `pickedFile.path` 存进数据库 —— 那是 picker 的
/// 临时目录，系统一清照片就没了，这就是「加了照片过几天变空白」的根因。
/// 现在一律复制进应用自己的文档目录，并且**只存相对路径**：
/// Android 的应用私有目录在多用户下是 `/data/user/0` 还是 `/data/user/10` 会变，
/// 换机恢复也会变，存相对名、读的时候拼 documents 目录，这类 bug 从根上消失。
class Covers {
  Covers._();

  static final Covers instance = Covers._();

  late Directory _root;
  late Directory _dir;

  /// `locate` 结果的缓存。没有它就是 30 条列表每次 build 30 次系统调用。
  final Map<String, String?> _cache = {};

  Future<void> init() async {
    _root = await getApplicationDocumentsDirectory();
    _dir = Directory(p.join(_root.path, kCoversDir));
    if (!_dir.existsSync()) await _dir.create(recursive: true);
  }

  /// 仅供测试：把根目录指到临时目录，绕开 path_provider。
  @visibleForTesting
  void debugUseRoot(Directory root) {
    _root = root;
    _dir = Directory(p.join(root.path, kCoversDir));
    _cache.clear();
  }

  /// 把存储值映射成磁盘上真实存在的绝对路径，找不到返回 null。同步，供 build 期调用。
  ///
  /// 兼容三种历史形态：带 `f:` 前缀的落库原文、`covers/xxx.jpg` 相对路径、
  /// 以及 v1 遗留的 imageUrl（image_picker 给的绝对路径）。
  String? locate(String stored) {
    if (stored.isEmpty) return null;
    if (_cache.containsKey(stored)) return _cache[stored];
    final path = coverStoragePath(stored);
    final abs = p.isAbsolute(path) ? path : p.join(_root.path, path);
    return _cache[stored] = File(abs).existsSync() ? abs : null;
  }

  /// 存进数据库的封面代号。
  String keyFor(String fileName) => '$kPhotoPrefix$kCoversDir/$fileName';

  /// 把外部文件复制进应用目录，返回可落库的存储值。
  Future<String> importFrom(String sourcePath) async {
    final ext = p.extension(sourcePath).toLowerCase();
    final name = 'c_${DateTime.now().millisecondsSinceEpoch}'
        '_${math.Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0')}'
        '${ext.isEmpty ? '.jpg' : ext}';
    await File(sourcePath).copy(p.join(_dir.path, name));
    _cache.clear();
    return keyFor(name);
  }

  /// 备份恢复用：把一个已经在磁盘上的文件按**原名**搬进 `covers/`。
  ///
  /// 不走 [importFrom] 是因为它会重新起名，而恢复出来的 `coverKey` 里存的
  /// 就是备份里那个名字 —— 改了名就对不上，照片会全部读不出来。
  Future<void> adopt(String fileName, String sourcePath) async {
    final name = p.basename(fileName);
    if (name.isEmpty) return;
    await File(sourcePath).rename(p.join(_dir.path, name));
    _cache.clear();
  }

  Future<void> remove(String stored) async {
    final abs = locate(stored);
    _cache.remove(stored);
    if (abs != null) await File(abs).delete();
  }

  /// 冷启动清理：删掉 `covers/` 里没人引用、且超过 24 小时的图片。
  ///
  /// 24 小时是防止删掉正在编辑中的暂存文件 —— 用户可能选了照片然后放着不动。
  /// 这是让整个方案自愈的兜底：任何原因漏删的拷贝最终都会被收走。
  Future<int> sweepOrphans(Set<String> referencedKeys) async {
    final keptNames = {
      for (final k in referencedKeys)
        if (k.startsWith(kPhotoPrefix)) p.basename(k.substring(kPhotoPrefix.length)),
    };
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    var removed = 0;
    await for (final e in _dir.list()) {
      if (e is! File) continue;
      if (keptNames.contains(p.basename(e.path))) continue;
      if ((await e.stat()).modified.isAfter(cutoff)) continue;
      await e.delete();
      removed++;
    }
    if (removed > 0) _cache.clear();
    return removed;
  }
}

/// 表单正在编辑中的一次封面选择。
///
/// 选了新照片会**立刻**拷一份文件进应用目录（不能等保存，picker 的临时文件
/// 随时可能被系统清掉）。所以用户取消表单时必须把这份拷贝删回去，
/// 否则每次取消都漏一份文件。
class StagedCover {
  /// 进表单时那条记录原来的 coverKey。
  final String? initialKey;

  String? _current;
  String? _staged;

  StagedCover(this.initialKey) : _current = initialKey;

  String? get currentKey => _current;

  void selectGradient(int index) {
    _discardStaged();
    _current = '$kGradientPrefix$index';
  }

  /// 从相册挑一张。返回新的 coverKey；用户取消选择时返回 null。
  Future<String?> pickPhoto() async {
    final picked = await ExternalFlow.run(
      () => ImagePicker().pickImage(
        source: ImageSource.gallery,
        // 限长边 + 有损压缩：原始照片动辄 5MB，几十条下去文档目录会很难看
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      ),
    );
    if (picked == null) return null;
    final key = await Covers.instance.importFrom(picked.path);
    _discardStaged();
    _staged = key;
    _current = key;
    return key;
  }

  /// 落库成功：这份拷贝归数据库所有，同时删掉被替换掉的那张旧图。
  Future<void> commit() async {
    final replaced = initialKey;
    _staged = null;
    if (replaced != null &&
        replaced != _current &&
        replaced.startsWith(kPhotoPrefix)) {
      await Covers.instance.remove(replaced);
    }
  }

  /// 表单取消：删掉本次拷进来的文件，原记录一个字没动。
  void rollback() => _discardStaged();

  void _discardStaged() {
    final staged = _staged;
    _staged = null;
    if (staged != null) unawaited(Covers.instance.remove(staged));
  }
}
