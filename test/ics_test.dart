import 'dart:convert';

import 'package:daily/data/ics.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/model/repeat_rule.dart';
import 'package:flutter_test/flutter_test.dart';

Daily _daily({
  int id = 7,
  String title = '结婚纪念',
  String headText = '执子之手',
  String targetDay = '1998-05-08',
  RepeatRule repeatRule = RepeatRule.none,
  int remindDaysBefore = 0,
  int remindHour = 9,
  int remindMinute = 0,
}) =>
    Daily(
      id: id,
      title: title,
      headText: headText,
      targetDay: targetDay,
      remark: '',
      repeatRule: repeatRule,
      remindEnabled: true,
      remindDaysBefore: remindDaysBefore,
      remindHour: remindHour,
      remindMinute: remindMinute,
    );

final DateTime _stamp = DateTime.utc(2026, 9, 11, 14, 30, 5);

String _build(Daily d) => buildIcs(d, stamp: _stamp);

void main() {
  group('结构', () {
    test('换行是 CRLF —— 有些日历不认 LF', () {
      final text = _build(_daily());
      expect(text.contains('\r\n'), isTrue);
      // 除了 CRLF 里的 \n，不该有孤零零的 \n
      expect(RegExp(r'(?<!\r)\n').hasMatch(text), isFalse);
      expect(text.endsWith('\r\n'), isTrue);
    });

    test('首尾分别是 VCALENDAR 的开与闭', () {
      final lines = _build(_daily()).split('\r\n');
      expect(lines.first, 'BEGIN:VCALENDAR');
      expect(lines[lines.length - 2], 'END:VCALENDAR');
    });

    test('DTSTAMP 是 UTC 且补零', () {
      expect(_build(_daily()).contains('DTSTAMP:20260911T143005Z'), isTrue);
    });

    test('全天事件：DTSTART 只有日期，没有时间', () {
      expect(_build(_daily()).contains('DTSTART;VALUE=DATE:19980508'), isTrue);
    });

    test('UID 稳定 —— 反复导出只更新同一条，不会越导越多', () {
      final a = _build(_daily(id: 7));
      final b = _build(_daily(id: 7, title: '改过标题了'));
      expect(a.contains('UID:time-7@muanyan.daily'), isTrue);
      expect(b.contains('UID:time-7@muanyan.daily'), isTrue);
    });
  });

  group('重复规则', () {
    test('每年', () {
      expect(_build(_daily(repeatRule: RepeatRule.yearly)).contains('RRULE:FREQ=YEARLY'), isTrue);
    });

    test('每月', () {
      expect(_build(_daily(repeatRule: RepeatRule.monthly)).contains('RRULE:FREQ=MONTHLY'), isTrue);
    });

    test('不重复就一行 RRULE 都没有', () {
      expect(_build(_daily(repeatRule: RepeatRule.none)).contains('RRULE'), isFalse);
    });
  });

  group('提醒', () {
    // 全天事件的 DTSTART 是当天 00:00，所以「提前 N 天的 H 点」得换算成
    // 相对 DTSTART 的偏移。RFC 5545 里时长的负号作用于**整段** ——
    // `-P3DT9H` 是「提前 3 天零 9 小时」，不是「提前 3 天的 9 点」。
    test('当天 9 点 ＝ DTSTART 之后 9 小时，不该带负号', () {
      final text = _build(_daily(remindDaysBefore: 0, remindHour: 9));
      expect(text.contains('TRIGGER:PT9H'), isTrue);
      expect(text.contains('TRIGGER:-'), isFalse);
    });

    test('提前 3 天的 9 点 ＝ 2 天 15 小时之前', () {
      final text = _build(_daily(remindDaysBefore: 3, remindHour: 9));
      expect(text.contains('TRIGGER:-P2DT15H'), isTrue);
    });

    test('提前 1 天的 0 点 ＝ 整整 1 天之前，不写多余的时间段', () {
      final text = _build(_daily(remindDaysBefore: 1, remindHour: 0));
      expect(text.contains('TRIGGER:-P1D'), isTrue);
      expect(text.contains('0M'), isFalse);
    });

    test('分钟不会被丢掉', () {
      final text = _build(_daily(remindDaysBefore: 1, remindHour: 8, remindMinute: 30));
      expect(text.contains('TRIGGER:-PT15H30M'), isTrue);
    });

    test('只有分钟时也拼得出来', () {
      final text = _build(_daily(remindDaysBefore: 0, remindHour: 0, remindMinute: 45));
      expect(text.contains('TRIGGER:PT45M'), isTrue);
    });

    test('withAlarm=false 时没有 VALARM，标题上标注已过去', () {
      final text = buildIcs(_daily(title: '考试倒计时'), stamp: _stamp, withAlarm: false);
      expect(text.contains('BEGIN:VALARM'), isFalse);
      expect(text.contains('SUMMARY:考试倒计时（已过去）'), isTrue);
    });
  });

  group('转义与折行', () {
    test('逗号、分号、反斜杠要转义', () {
      final text = _build(_daily(title: 'a,b;c\\d'));
      expect(text.contains(r'SUMMARY:a\,b\;c\\d'), isTrue);
    });

    test('换行写成字面量 \\n，不能真的折出空行', () {
      final text = _build(_daily(headText: '第一行\n第二行'));
      expect(text.contains(r'DESCRIPTION:第一行\n第二行'), isTrue);
    });

    test('长中文描述按 75 个八位组折行，且不劈开多字节字符', () {
      // 40 个汉字 = 120 字节，必然要折
      final head = '一二三四五六七八九十' * 4;
      final text = _build(_daily(headText: head));

      final lines = text.split('\r\n');
      for (final line in lines) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: '超宽的行：$line');
      }
      // 续行必须以一个空格开头
      final continued = lines.where((l) => l.startsWith('DESCRIPTION') || l.startsWith(' '));
      expect(continued.length, greaterThan(2));

      // 折行不能破坏内容：把折行还原之后应该一个字不差
      final unfolded = text
          .split('\r\n ')
          .join()
          .split('\r\n')
          .firstWhere((l) => l.startsWith('DESCRIPTION:'));
      expect(unfolded, 'DESCRIPTION:$head');
    });

    test('一行以内的话不做任何折行', () {
      expect(_build(_daily(title: '短')).split('\r\n').where((l) => l.startsWith(' ')), isEmpty);
    });
  });

  group('文件名', () {
    test('非法字符换成下划线', () {
      expect(icsFileName(_daily(title: 'a/b:c*d?e"f<g>h|i')), 'a_b_c_d_e_f_g_h_i.ics');
    });

    test('空白折成一个下划线，首尾不留', () {
      expect(icsFileName(_daily(title: '  结婚  纪念  ')), '结婚_纪念.ics');
    });

    test('标题全是非法字符时退回 id，不会得到空名字', () {
      expect(icsFileName(_daily(id: 42, title: '   ')), 'time-42.ics');
    });

    test('标题过长会截断，给文件系统留余量', () {
      final name = icsFileName(_daily(title: '纪' * 100));
      expect(name, '${'纪' * 40}.ics');
    });
  });
}
