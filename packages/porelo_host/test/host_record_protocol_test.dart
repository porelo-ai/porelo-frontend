import 'dart:convert';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

import 'server_contract_test.dart' show hostValues;

void main() {
  // Harm: losing a host record prevents verified setup completion and can misdirect admin access.
  test('the step protocol carries the checked public host values', () {
    final json = {'v': 1, 'state': 'host', 'host': hostValues()};
    final step = Step.fromLine(jsonEncode(json));
    expect(step, isNotNull, reason: 'host values use the existing step protocol');
    expect(jsonDecode(step!.toLine()), json);
    final output = StringBuffer();
    final errors = StringBuffer();
    writeHostStep(step, output: output, errors: errors);
    expect((jsonDecode(output.toString()) as Map)['host'], hostValues());
    expect(errors.toString(), isEmpty, reason: 'public metadata has no synthetic progress sentence');
  });

  for (final field in hostValues().keys) {
    test('a host protocol line refuses a missing $field by name', () {
      final host = hostValues()..remove(field);
      expect(
        () => Step.fromLine(jsonEncode({'v': 1, 'state': 'host', 'host': host})),
        throwsA(isA<FormatException>().having((error) => error.message, 'field', contains(field))),
      );
    });
  }
}
