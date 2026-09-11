import 'package:daily/model/daily.dart';
import 'package:daily/model/daily_group.dart';
import 'package:flutter_test/flutter_test.dart';

Daily _d(int id, String day) => Daily(
      id: id,
      title: '标题$id',
      headText: '描述$id',
      targetDay: day,
      remark: '备注$id',
    );

List<int> _ids(DailyGroup g) => [for (final e in g.items) e.daily.id];

void main() {
  final now = DateTime(2026, 9, 10);

  test('今天归未来，分组顺序是 [未来, 已过去]', () {
    final groups = groupDailies(
      [_d(1, '2026-09-08'), _d(2, '2026-09-10'), _d(3, '2026-09-13')],
      now: now,
    );
    expect(groups.map((g) => g.name), [kGroupFuture, kGroupPast]);
    // 今天(0天) 在 还有3天 前面
    expect(_ids(groups[0]), [2, 3]);
    expect(_ids(groups[1]), [1]);
  });

  test('组内按离今天的远近升序，最近的在最上面', () {
    final groups = groupDailies(
      [_d(1, '2026-09-13'), _d(2, '2026-09-11'), _d(3, '2026-10-10')],
      now: now,
    );
    expect(groups.single.name, kGroupFuture);
    expect(_ids(groups.single), [2, 1, 3]); // +1, +3, +30
  });

  test('已过去组也是最近的在最上面', () {
    final groups = groupDailies(
      [_d(1, '2019-05-08'), _d(2, '2026-09-09'), _d(3, '2026-08-11')],
      now: now,
    );
    expect(groups.single.name, kGroupPast);
    expect(_ids(groups.single), [2, 3, 1]); // -1, -30, -2317
  });

  test('同一天的两条按 id 排，和输入顺序无关', () {
    // List.sort 不稳定，只比天数的话两条「还有 3 天」会在重建之间互相换位
    final a = _d(7, '2026-09-13');
    final b = _d(2, '2026-09-13');
    expect(_ids(groupDailies([a, b], now: now).single), [2, 7]);
    expect(_ids(groupDailies([b, a], now: now).single), [2, 7]);
  });

  test('日期解析不了的不崩，沉在最后', () {
    final groups = groupDailies(
      [_d(1, ''), _d(2, '2026-09-11'), _d(3, '随便写点什么')],
      now: now,
    );
    expect(groups.single.name, kGroupFuture);
    expect(_ids(groups.single), [2, 1, 3]);
    expect(groups.single.items.first.signedDays, 1);
    expect(groups.single.items.last.signedDays, isNull);
  });

  test('只有一组时只输出那一组', () {
    expect(groupDailies([_d(1, '2026-09-11')], now: now).single.name, kGroupFuture);
    expect(groupDailies([_d(1, '2026-09-09')], now: now).single.name, kGroupPast);
  });

  test('空列表不产生任何分组', () {
    expect(groupDailies(const [], now: now), isEmpty);
  });

  test('分组标题带计数', () {
    final groups = groupDailies(
      [_d(1, '2026-09-11'), _d(2, '2026-09-12'), _d(3, '2026-09-01')],
      now: now,
    );
    expect(groups[0].label, '未来 · 2');
    expect(groups[1].label, '已过去 · 1');
  });

  test('列表要求的六条场景', () {
    // 今天 / 今天+3 / 今天-3 / 今天+400 / 今天-1826 / 2019-05-08
    final groups = groupDailies(
      [
        _d(1, '2026-09-10'),
        _d(2, '2026-09-13'),
        _d(3, '2026-09-07'),
        _d(4, '2027-10-15'),
        _d(5, '2021-09-10'),
        _d(6, '2019-05-08'),
      ],
      now: now,
    );
    expect(groups[0].name, kGroupFuture);
    expect(_ids(groups[0]), [1, 2, 4]);
    expect([for (final e in groups[0].items) e.signedDays], [0, 3, 400]);
    expect(groups[1].name, kGroupPast);
    expect(_ids(groups[1]), [3, 5, 6]);
    expect([for (final e in groups[1].items) e.signedDays], [-3, -1826, -2682]);
  });
}
