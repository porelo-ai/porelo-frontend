import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

/// When a question runs out, held to the contract: absent and empty are different answers.
void main() {
  Prompt promptWith(Map<String, dynamic> fields) => Prompt.from(<String, dynamic>{
        'task': 'porelo-checkout-shell',
        'key': 'tcp/api.example.test:443',
        'destination': 'api.example.test',
        'protocol': 'tcp',
        'port': 443,
        'at': '2026-09-11T05:00:00Z',
        'prefix': 'egress/deny',
        ...fields,
      });

  test('a daemon older than the field says nothing about when it runs out', () {
    final prompt = promptWith(<String, dynamic>{});
    expect(prompt.expiresAt, isNull);
    expect(prompt.neverRunsOut, isFalse);
  });

  test('an empty deadline is one that never runs out, not one nobody sent', () {
    final prompt = promptWith(<String, dynamic>{'deadline': ''});
    expect(prompt.neverRunsOut, isTrue);
    expect(prompt.expiresAt, isNull);
  });

  test('a deadline is read as a moment', () {
    expect(promptWith(<String, dynamic>{'deadline': '2026-09-11T05:03:00Z'}).expiresAt,
        DateTime.utc(2026, 9, 11, 5, 3));
  });

  test('a deadline nobody can read is treated as not said, never as never', () {
    final prompt = promptWith(<String, dynamic>{'deadline': 'soon'});
    expect(prompt.expiresAt, isNull);
    expect(prompt.neverRunsOut, isFalse);
  });
}
