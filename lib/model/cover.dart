import 'package:daily/data/cover_palette.dart';

/// 一条纪念日最终能渲染出什么封面。
sealed class Cover {
  const Cover();
}

/// 代码绘制的渐变。
final class GradientCover extends Cover {
  final int index;

  const GradientCover(this.index);
}

/// 磁盘上的照片。
final class PhotoCover extends Cover {
  /// 可直接交给 `FileImage` 的绝对路径。
  final String path;

  const PhotoCover(this.path);
}

/// 把 `coverKey` / `imageUrl` 解析成一个一定能渲染的 [Cover]。
///
/// 任何输入都不抛异常 —— 这些值来自用户可能手改过的数据库。
///
/// [locate] 负责把存储值映射成磁盘上真实存在的绝对路径，找不到返回 null。
/// 传进来而不是在内部读全局状态，是为了让这个函数保持纯的、可单元测试。
Cover resolveCover({
  required String? coverKey,
  required String? imageUrl,
  required String? Function(String stored) locate,
}) {
  final key = coverKey ?? '';
  if (key.startsWith(kGradientPrefix)) {
    final index = int.tryParse(key.substring(kGradientPrefix.length));
    return GradientCover(index ?? 0);
  }
  if (key.startsWith(kPhotoPrefix)) {
    final stored = key.substring(kPhotoPrefix.length);
    final path = locate(stored);
    // 文件被清掉了：渐变兜底，不是错误
    return path == null ? const GradientCover(0) : PhotoCover(path);
  }
  if (key.isNotEmpty) {
    // 认不出的值一律夹取，不崩
    return const GradientCover(0);
  }

  // 老数据没有 coverKey，只有 v1 的 imageUrl：路径还活着就继续显示那张照片。
  // http 开头的只可能来自从没落库过的假欢迎卡，当坏的。
  final legacy = imageUrl ?? '';
  if (legacy.isNotEmpty && !legacy.startsWith('http')) {
    final path = locate(legacy);
    if (path != null) return PhotoCover(path);
  }
  return const GradientCover(0);
}
