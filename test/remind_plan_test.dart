import 'package:daily/data/remind_plan.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/model/repeat_rule.dart';
import 'package:flutter_test/flutter_test.dart';

/// 提醒排班的两个纯判断。
///
/// 「日期已经过去了就跳过」这条最容易被当成 bug 改掉 —— 排一个过去的时间点，
/// 系统会立刻弹一条通知，那不是提醒是惊吓。这里把它钉住。
void main() {
  final now = DateTime(2026, 9, 11, 10, 0);

  Daily make(
    String targetDay, {
    required bool remind,
    int daysBefore = 0,
    int hour = 9,
    int minute = 0,
    RepeatRule rule = RepeatRule.none,
  }) =>
      Daily(
        id: 1,
        title: '结婚纪念日',
        headText: '',
        targetDay: targetDay,
        remark: '',
        repeatRule: rule,
        remindEnabled: remind,
        remindDaysBefore: daysBefore,
        remindHour: hour,
        remindMinute: minute,
      );

  group('remindMoment', () {
    test('没开提醒：不排', () {
      expect(remindMoment(make('2027-01-01', remind: false), now), isNull);
    });

    test('日期坏了：不排', () {
      expect(remindMoment(make('', remind: true), now), isNull);
    });

    test('未来的日期：排在那天的设定时刻', () {
      expect(
        remindMoment(make('2027-01-01', remind: true, hour: 20, minute: 30), now),
        DateTime(2027, 1, 1, 20, 30),
      );
    });

    test('今天但时刻还没到：今天照响', () {
      expect(
        remindMoment(make('2026-09-11', remind: true, hour: 20), now),
        DateTime(2026, 9, 11, 20),
      );
    });

    test('今天但时刻已过：不排 —— 排下去会立刻弹出来', () {
      expect(remindMoment(make('2026-09-11', remind: true, hour: 8), now), isNull);
    });

    test('非重复且日期已过去：不排', () {
      expect(remindMoment(make('2020-01-01', remind: true), now), isNull);
    });

    test('每年重复且今年已过：排到明年那天', () {
      expect(
        remindMoment(make('1998-05-08', remind: true, rule: RepeatRule.yearly), now),
        DateTime(2027, 5, 8, 9),
      );
    });

    test('提前 3 天：往前推 3 天，时刻不变', () {
      expect(
        remindMoment(make('1998-05-08', remind: true, daysBefore: 3, hour: 21, rule: RepeatRule.yearly), now),
        DateTime(2027, 5, 5, 21),
      );
    });

    test('提前的天数把提醒推到了过去：不排（今年这一轮赶不上了）', () {
      // 下次重复日是 2027-05-08，提前 300 天 = 2026-07-12，早于 now
      expect(
        remindMoment(make('1998-05-08', remind: true, daysBefore: 300, rule: RepeatRule.yearly), now),
        isNull,
      );
    });
  });

  group('nearestReminder', () {
    test('空列表：没有可显示的', () {
      expect(nearestReminder(const [], now), isNull);
    });

    test('取未来里最近的一条', () {
      final result = nearestReminder(
        [
          make('2027-01-01', remind: false),
          make('2026-09-20', remind: false),
          make('2026-10-11', remind: false),
        ],
        now,
      );
      expect(result?.days, 9);
      expect(result?.daily.targetDay, '2026-09-20');
    });

    test('今天有就优先今天，不管别的有多近', () {
      final result = nearestReminder(
        [make('2026-09-12', remind: false), make('2026-09-11', remind: false)],
        now,
      );
      expect(result?.days, 0);
    });

    test('全都过去了：取最不远的那个，通知栏里写「已经 N 天」也比空着好', () {
      final result = nearestReminder(
        [make('2020-01-01', remind: false), make('2024-01-01', remind: false)],
        now,
      );
      expect(result?.daily.targetDay, '2024-01-01');
      expect(result?.days, lessThan(0));
    });

    test('重复记录按下一次算，所以永远算「还没到」', () {
      final result = nearestReminder(
        [make('1998-05-08', remind: false, rule: RepeatRule.yearly)],
        now,
      );
      expect(result?.days, 239);
    });

    test('日期坏了的记录不进候选', () {
      expect(nearestReminder([make('', remind: false)], now), isNull);
    });
  });
}
