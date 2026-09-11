/// 重复规则。
///
/// `name` 就是落库的字符串（`none` / `yearly` / `monthly`），改名等于改 schema，
/// 没有配套迁移就别动。用枚举而不是裸字符串，是为了让「每个月跨几个月」
/// 这个只对重复有意义的量有个明确的归属。
enum RepeatRule {
  none('不重复'),
  yearly('每年'),
  monthly('每月');

  const RepeatRule(this.label);

  /// 界面上的文案。
  final String label;

  /// 每次重复跨多少个月。`none` 是 0，也就是「不重复」。
  int get monthsPerStep => switch (this) {
        RepeatRule.none => 0,
        RepeatRule.yearly => 12,
        RepeatRule.monthly => 1,
      };

  /// 落库字符串 → 规则。
  ///
  /// 不认识的取值（包括 null，老库升上来时这一列全是 null）一律当不重复 ——
  /// 迁移期宁可少提醒一次，也不能让一条记录因为读不懂而整条打不开。
  static RepeatRule parse(Object? stored) {
    if (stored is String) {
      for (final rule in RepeatRule.values) {
        if (rule.name == stored) return rule;
      }
    }
    return RepeatRule.none;
  }
}
