import 'package:daily/model/repeat_rule.dart';
import 'package:daily/utils/date_util.dart';

/// 提醒时间的默认值：早上 9 点。定在这儿是为了让新建记录一开开关就有个
/// 合理的时刻，而不是 00:00 那种半夜响的坑。
const int kDefaultRemindHour = 9;

/// 一条纪念日。
///
/// 列名与 v1 数据库保持逐字一致（title / headText / targetDay / imageUrl / remark），
/// v2 之后新增的列都走 `migrateSchema`，迁移契约全靠它。
class Daily {
  final int id;
  final String title;
  final String headText;

  /// `yyyy-MM-dd`。解析不了时为 null，界面按「日期待补充」处理。
  final String targetDay;

  /// v1 遗留的历史存档列：只读不写，新数据一律写 [coverKey]。
  ///
  /// 保留它是因为迁移时并不知道这些路径还能不能解析，清掉就永久失去了
  /// 「照片原本在哪」的唯一记录；顺带还能给老记录当封面回退。
  final String? imageUrl;

  final String remark;

  /// v2 新增。`g:<0-5>` 是代码绘制的渐变，`f:<相对路径>` 是用户照片。
  /// 空 / null 表示老数据，回退去读 [imageUrl]。
  final String? coverKey;

  /// v3 新增。老库升上来时这一列是 null，会解析成 [RepeatRule.none]。
  final RepeatRule repeatRule;

  /// v4 新增。提醒开关。
  final bool remindEnabled;

  /// 提前几天提醒，0 = 当天。
  final int remindDaysBefore;

  /// 提醒时刻，24 小时制的时与分。
  ///
  /// 拆成两列而不是存 `HH:mm` 字符串：每个用到它的地方都要再解析一次，
  /// 还要处理写坏的格式，不如让类型自己保证。
  final int remindHour;
  final int remindMinute;

  const Daily({
    this.id = 0,
    required this.title,
    required this.headText,
    required this.targetDay,
    this.imageUrl,
    required this.remark,
    this.coverKey,
    this.repeatRule = RepeatRule.none,
    this.remindEnabled = false,
    this.remindDaysBefore = 0,
    this.remindHour = kDefaultRemindHour,
    this.remindMinute = 0,
  });

  factory Daily.fromMap(Map<String, Object?> m) => Daily(
        id: (m['id'] as int?) ?? 0,
        title: (m['title'] as String?) ?? '',
        headText: (m['headText'] as String?) ?? '',
        targetDay: (m['targetDay'] as String?) ?? '',
        imageUrl: m['imageUrl'] as String?,
        remark: (m['remark'] as String?) ?? '',
        coverKey: m['coverKey'] as String?,
        repeatRule: RepeatRule.parse(m['repeatRule']),
        remindEnabled: (m['remindEnabled'] as int? ?? 0) == 1,
        remindDaysBefore: (m['remindDaysBefore'] as int?) ?? 0,
        remindHour: (m['remindHour'] as int?) ?? kDefaultRemindHour,
        remindMinute: (m['remindMinute'] as int?) ?? 0,
      );

  /// 插入用：不含 id，交给 SQLite 自增分配。
  Map<String, Object?> toInsertMap() => {
        'title': title,
        'headText': headText,
        'targetDay': targetDay,
        'remark': remark,
        'coverKey': coverKey,
        'repeatRule': repeatRule.name,
        'remindEnabled': remindEnabled ? 1 : 0,
        'remindDaysBefore': remindDaysBefore,
        'remindHour': remindHour,
        'remindMinute': remindMinute,
      };

  /// 更新用：必须带 id，否则 UPDATE 会匹配 0 行然后静默成功。
  Map<String, Object?> toUpdateMap() => {...toInsertMap(), 'id': id};

  DateTime? get date => DateTime.tryParse(targetDay);

  /// 这条记录「下一次」落在哪天。
  ///
  /// 非重复记录就是起始日本身；重复记录是今天起算的第一个重复日。
  /// 全 App 的「还有 N 天」都由它得出 —— 因为 `nextDate == date` 对非重复记录
  /// 恒成立，所以引入它之后首页卡片、详情页、海报三处的行为一个字都不用改。
  DateTime? get nextDate => nextDateFrom(DateTime.now());

  /// [nextDate] 的可注入版本，让日期逻辑能被单测固定住。
  DateTime? nextDateFrom(DateTime today) {
    final d = date;
    if (d == null) return null;
    return nextOccurrence(d, repeatRule, today);
  }

  /// 提醒应该响在哪一天：下一次重复日往前推 [remindDaysBefore] 天。
  /// 日期解析不了、或者压根没开提醒时返回 null。
  DateTime? remindDateFrom(DateTime today) {
    if (!remindEnabled) return null;
    final next = nextDateFrom(today);
    return next == null ? null : addDays(next, -remindDaysBefore);
  }

  /// 详情页右下角那行状态：「重复规则 · 提醒」。
  ///
  /// 这两件事以前只有编辑页看得到，而点开一条记录最想确认的恰恰是
  /// 「它到底会不会提醒我」。以前占着这个位置的是倒计时，而它和中间
  /// 那排大数字说的是同一件事。
  ///
  /// 文案刻意比表单里紧凑（`提前3天` 不是 `提前 3 天`）：这一行要和左边的
  /// 日期挤在同一行里，多两个空格就会把日期顶到省略号上去。
  String get scheduleLabel {
    final rule = repeatRule.label;
    if (!remindEnabled) return '$rule · 不提醒';
    final when = remindDaysBefore == 0 ? '当天' : '提前$remindDaysBefore天';
    return '$rule · $when ${fmt2(remindHour)}:${fmt2(remindMinute)}';
  }

  Daily copyWith({
    int? id,
    String? title,
    String? headText,
    String? targetDay,
    String? imageUrl,
    String? remark,
    String? coverKey,
    RepeatRule? repeatRule,
    bool? remindEnabled,
    int? remindDaysBefore,
    int? remindHour,
    int? remindMinute,
  }) =>
      Daily(
        id: id ?? this.id,
        title: title ?? this.title,
        headText: headText ?? this.headText,
        targetDay: targetDay ?? this.targetDay,
        imageUrl: imageUrl ?? this.imageUrl,
        remark: remark ?? this.remark,
        coverKey: coverKey ?? this.coverKey,
        repeatRule: repeatRule ?? this.repeatRule,
        remindEnabled: remindEnabled ?? this.remindEnabled,
        remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
        remindHour: remindHour ?? this.remindHour,
        remindMinute: remindMinute ?? this.remindMinute,
      );
}
