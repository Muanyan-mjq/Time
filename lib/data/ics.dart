import 'dart:convert';

import 'package:daily/model/daily.dart';
import 'package:daily/model/repeat_rule.dart';
import 'package:daily/utils/external_flow.dart';
import 'package:file_picker/file_picker.dart';

/// 把一条记录导出成 `.ics`，交给系统日历去提醒。
///
/// 为什么要有这条出口：本地通知靠的是 App 自己活着 —— 国产 ROM 一杀后台，
/// 到点就不响，而这是 App 修不好的（要用户去系统设置里手动开自启动）。
/// 系统日历是系统自己管的，谁都杀不掉，所以「真要准时」这件事得有一条
/// 交给系统的路。
///
/// 返回给用户看的一句话；返回 null 表示用户取消了保存，这时候不该弹提示。
Future<String?> exportToCalendar(Daily daily) async {
  final date = daily.date;
  if (date == null) return '这条记录没有日期，导不进日历';

  final plan = calendarPlan(daily, _today());
  final text = buildIcs(
    daily,
    stamp: DateTime.now().toUtc(),
    // 没有闹钟的 VEVENT 在日历里就是个安静的全天事件
    withAlarm: plan.withAlarm,
    past: plan.past,
  );

  final Uri? target;
  try {
    // 和备份一样必须走 bytes：Android 上 `saveFile` 是 SAF，
    // 由插件自己写文件，返回的 content:// 不能拿 dart:io 去写
    target = await ExternalFlow.run(
      () => FilePicker.saveFile(
        fileName: icsFileName(daily),
        bytes: utf8.encode(text),
        mimeType: 'text/calendar',
        dialogTitle: '加入系统日历',
      ),
    );
  } catch (e) {
    return '保存失败：$e';
  }
  if (target == null) return null;

  if (plan.past) return '已导出一份历史记录，日历不会提醒它';
  if (!plan.withAlarm) return '已导出，提醒开关关着，日历不会响';
  return '已导出，打开它就能加进系统日历';
}

/// 导出成日历时两个**纯**决策：要不要带闹钟、要不要标「已过去」。
///
/// 抽出来的理由和提醒排班一样 —— 判断能单测钉死，插件调用那部分不能。
/// 带不带闹钟要跟 App 自己的提醒开关一致：用户在 App 里把提醒关了，
/// 不该从系统日历里冒出来一条；一次性记录又已经过去的话，加了也只是个念想。
({bool withAlarm, bool past}) calendarPlan(Daily daily, DateTime today) {
  final date = daily.date;
  if (date == null) return (withAlarm: false, past: false);
  final past = daily.repeatRule == RepeatRule.none && date.isBefore(today);
  return (withAlarm: !past && daily.remindEnabled, past: past);
}

/// 生成一份只含一条事件的 iCalendar 文本。
///
/// 纯函数（时间由 [stamp] 注入），所以格式能被单测逐字锁住。
/// 用的是 RFC 5545 那一套，注意换行必须是 CRLF —— 有些日历对 LF 直接不认。
String buildIcs(
  Daily daily, {
  required DateTime stamp,
  bool withAlarm = true,
  bool past = false,
}) {
  final date = daily.date;
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Muanyan//Time//CN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    // 同一个 id 反复导出只会在日历里更新同一条，不会越导越多
    'UID:time-${daily.id}@muanyan.daily',
    'DTSTAMP:${_stamp(stamp)}',
    if (date != null) 'DTSTART;VALUE=DATE:${_date(date)}',
    'SUMMARY:${_escape(past ? '${daily.title}（已过去）' : daily.title)}',
    if (daily.headText.trim().isNotEmpty) 'DESCRIPTION:${_escape(daily.headText)}',
    // DTSTART 已经是「第一次发生的那天」了（比如 1998 年的结婚日），
    // 规则交给日历往前滚 —— 我们不排十年后的一次，日历会
    ..._recurrence(daily.repeatRule, date),
    if (withAlarm && date != null) ..._alarm(daily),
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return '${lines.map(_fold).join('\r\n')}\r\n';
}

/// 重复规则。不重复就一行都不写 —— 写了 `FREQ=DAILY` 那种才是灾难。
///
/// 日期不存在的月份/年份，日历是**整次跳过**，而 App 里 `addMonthsClamped`
/// 是「够不着就落到当月最后一天」。两种口径在下面这几种日期上会分叉，
/// 而这份导出正是给「准点响」兜底的 —— 漏掉一次就白兜了，所以翻译成
/// 同样会落到月末的写法：
///
///   · 每月 31 号 → 每月最后一个存在的 28~31 日（`BYSETPOS=-1` 取集合末位）
///   · 每月 29/30 号 → 各月的那一天，再补一条 2 月的「28/29 里的最后一天」；
///     两条 `RRULE` 按并集算（RFC 5545 允许多条），合起来才是 App 的口径
///   · 每年 2 月 29 日 → 每年 2 月的「28/29 里的最后一天」，平年落 28 号
///
/// 29 号那条在闰年会和补的规则重合到同一天，并集里仍然只算一次。
List<String> _recurrence(RepeatRule rule, DateTime? date) {
  if (date == null) return const [];
  switch (rule) {
    case RepeatRule.none:
      return const [];
    case RepeatRule.yearly:
      if (date.month == 2 && date.day == 29) {
        return const ['RRULE:FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=28,29;BYSETPOS=-1'];
      }
      return const ['RRULE:FREQ=YEARLY'];
    case RepeatRule.monthly:
      if (date.day <= 28) return const ['RRULE:FREQ=MONTHLY'];
      if (date.day == 31) {
        return const ['RRULE:FREQ=MONTHLY;BYMONTHDAY=28,29,30,31;BYSETPOS=-1'];
      }
      return [
        'RRULE:FREQ=MONTHLY;BYMONTHDAY=${date.day}',
        'RRULE:FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=28,29;BYSETPOS=-1',
      ];
  }
}

/// 提醒。全天事件的 DTSTART 是当天 00:00，用户要的是「提前 N 天的 H 点」，
/// 换算成相对 DTSTART 的偏移就是 `H*60+M - N*1440` 分钟。
///
/// 不能写成 `-P{N}DT{H}H`：RFC 5545 里时长的负号作用于**整段**，
/// `-P3DT9H` 是「提前 3 天零 9 小时」，不是「提前 3 天的 9 点」。
/// 按那样写，默认的「当天 9:00」会变成前一天的 15:00 —— 恒定早 2×hour 小时，
/// 而这份导出正是给「国产 ROM 杀后台导致提醒不准」兜底用的，
/// 早一天弹出来等于没兜住。
///
/// 偏移为正表示落在 DTSTART 之后（当天 9 点就是这种），这时不能带负号。
List<String> _alarm(Daily daily) {
  final total =
      daily.remindHour * 60 + daily.remindMinute - daily.remindDaysBefore * 1440;
  final sign = total < 0 ? '-' : '';
  final abs = total.abs();
  final days = abs ~/ 1440;
  final hours = (abs % 1440) ~/ 60;
  final mins = abs % 60;

  final spec = StringBuffer(sign)..write('P');
  if (days > 0) spec.write('${days}D');
  final hasTime = hours > 0 || mins > 0;
  if (hasTime) {
    spec.write('T');
    if (hours > 0) spec.write('${hours}H');
    // 有小时就不必再写 0M；没有小时时必须写，否则「T」后面是空的
    if (mins > 0 || hours == 0) spec.write('${mins}M');
  } else if (days == 0) {
    // 偏移恰好是 0（提前 0 天的 0 点整）：PARAM 值不能是裸的 P
    spec.write('T0M');
  }

  return [
    'BEGIN:VALARM',
    'TRIGGER:$spec',
    'ACTION:DISPLAY',
    'DESCRIPTION:${_escape(daily.title)}',
    'END:VALARM',
  ];
}

/// `.ics` 的文件名。用户会在文件管理器里看到它，所以要能认出是哪一条；
/// 但标题里的 `/` `:` 这些在文件名里是非法的，得先换掉。
String icsFileName(Daily daily) {
  final cleaned = daily.title
      .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final stem = cleaned.isEmpty ? 'time-${daily.id}' : cleaned;
  // 文件系统那一关的宽度限制（255 字节）留够余量：中文一个字三个字节
  final capped = stem.length > 40 ? stem.substring(0, 40) : stem;
  return '$capped.ics';
}

/// TEXT 值里这几个字符必须转义，否则会被当成结构符号解析。
String _escape(String value) => value
    .replaceAll('\\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n');

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

String _stamp(DateTime utc) =>
    '${_date(utc)}T${utc.hour.toString().padLeft(2, '0')}'
    '${utc.minute.toString().padLeft(2, '0')}'
    '${utc.second.toString().padLeft(2, '0')}Z';

/// RFC 5545 要求一行最多 75 个**八位组**，超了要折行（续行以一个空格开头）。
///
/// 不能按字符数数：一个汉字是三个字节，按字符数折出来的行早超了。
/// 更不能从多字节字符中间劈开 —— 那会写出一个非法的字节序列，
/// 有的日历会因此拒收整个文件。
String _fold(String line) {
  const max = 75;
  final out = StringBuffer();
  var used = 0;
  for (final rune in line.runes) {
    final size = rune < 0x80
        ? 1
        : rune < 0x800
            ? 2
            : rune < 0x10000
                ? 3
                : 4;
    if (used + size > max) {
      // 续行开头那个空格也占一个八位组
      out.write('\r\n ');
      used = 1;
    }
    out.writeCharCode(rune);
    used += size;
  }
  return out.toString();
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
