import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

void main() {
  // Harm: a task that may push is taken as one that only reads, so its gate and builds are not said.
  test('a task is read only only where the machine lists it so', () {
    expect(Task.from({'name': 'a', 'readOnly': true}).readOnly, isTrue);
    expect(Task.from({'name': 'a', 'readOnly': false}).readOnly, isFalse);
    expect(Task.from({'name': 'a'}).readOnly, isFalse, reason: 'an older daemon omits it, read as false');
    expect(Task.from({'name': 'a', 'readOnly': 'yes'}).readOnly, isFalse, reason: 'only a true bool says it');
  });
}
