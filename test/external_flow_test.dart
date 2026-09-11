import 'package:daily/utils/external_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('平时不生效，run 期间生效', () async {
    expect(ExternalFlow.active, isFalse);

    var seen = false;
    await ExternalFlow.run(() async {
      seen = ExternalFlow.active;
    });

    expect(seen, isTrue);
    expect(ExternalFlow.active, isFalse);
  });

  test('嵌套时内层先退出也仍然算生效', () async {
    await ExternalFlow.run(() async {
      await ExternalFlow.run(() async {});
      expect(ExternalFlow.active, isTrue);
    });
    expect(ExternalFlow.active, isFalse);
  });

  test('抛异常也一定复位：不然锁就永远失效了', () async {
    await expectLater(
      ExternalFlow.run(() async => throw StateError('picker 炸了')),
      throwsStateError,
    );
    expect(ExternalFlow.active, isFalse);
  });
}
