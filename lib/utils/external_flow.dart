/// 「正开着一个外部界面」的标记：相册选择器、系统文件选择器、分享面板。
///
/// 这些界面会把 App 压到后台，而用户挑照片、挑目录花掉的时间完全可能超过
/// `kLockGrace`（30 秒）—— 不豁免的话，选完回来正好撞上隐私锁：路由被清到
/// 首页，刚填的表单连同已经拷进 `covers/` 的照片一起没了。
///
/// [timeout] 是兜底：流程因为插件异常没能收尾时，不能让锁一直失效下去。
class ExternalFlow {
  ExternalFlow._();

  static const Duration timeout = Duration(minutes: 10);

  static int _depth = 0;
  static DateTime? _startedAt;

  /// 当前是否正处在外部界面里。[lockIfAway] 据此让路。
  static bool get active {
    if (_depth == 0) return false;
    final since = _startedAt;
    if (since != null && DateTime.now().difference(since) > timeout) {
      // 那次流程没收尾。清干净，让下一次进后台重新按正常规则计时
      _depth = 0;
      _startedAt = null;
      return false;
    }
    return true;
  }

  /// 把一次外部界面调用包起来 —— 选择器/分享面板必须在 [body] 里发起。
  static Future<T> run<T>(Future<T> Function() body) async {
    _depth++;
    _startedAt ??= DateTime.now();
    try {
      return await body();
    } finally {
      _depth--;
      if (_depth <= 0) {
        _depth = 0;
        _startedAt = null;
      }
    }
  }
}
