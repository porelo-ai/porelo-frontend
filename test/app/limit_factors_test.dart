import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/wire/limit_factors.dart';

void main() {
  // The cases Porelo publishes beside its own reader of the limits line, copied unchanged.
  final cases = jsonDecode(File('test/fixtures/limit-factors-cases.json').readAsStringSync()) as Map<String, Object?>;
  final good = (cases['good']! as List).cast<Map<String, Object?>>();
  final refused = (cases['refused']! as List).cast<Map<String, Object?>>();

  // Harm: the window reads a line Porelo writes otherwise than every other program does, or applies a factor no
  // program applies.
  test('every good line reads to its four factors and is written back as Porelo writes it', () {
    expect(good, hasLength(7));
    for (final each in good) {
      final line = each['line']! as String;
      final factors = LimitFactors.parse(line);
      expect(factors.services, double.parse(each['services']! as String), reason: line);
      expect(factors.machines, double.parse(each['machines']! as String), reason: line);
      expect(factors.polling, double.parse(each['polling']! as String), reason: line);
      expect(factors.retries, double.parse(each['retries']! as String), reason: line);
      expect(factors.line, each['written'], reason: line);
    }
  });

  // Harm: a line Porelo refuses is taken, so the window waits for a factor no other program would.
  test('every refused line is refused, naming what Porelo names', () {
    expect(refused, hasLength(19));
    for (final each in refused) {
      final line = each['line']! as String;
      expect(
        () => LimitFactors.parse(line),
        throwsA(isA<FormatException>().having((error) => error.message, 'message', each['names'])),
        reason: line,
      );
    }
  });

  // Harm: a setting the machine gave wrong is taken, or replaced by its default unsaid.
  test('account settings out of whole days from 1 to 3650, or missing, are refused', () {
    final good = <String, dynamic>{
      'certificateDays': 7,
      'cardDays': 30,
      'renewNoticeDays': 7,
      'askedAboutDays': 7,
      'keptDays': 30,
    };
    expect(
      AccountSettings.from(good),
      const AccountSettings(certificateDays: 7, cardDays: 30, renewNoticeDays: 7, askedAboutDays: 7, keptDays: 30),
    );
    for (final wrong in <Object?>[0, 3651, 7.5, '7', null]) {
      expect(
        () => AccountSettings.from(<String, dynamic>{...good, 'keptDays': wrong}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('keptDays'))),
        reason: '$wrong',
      );
    }
  });

  // Harm: a factor of 2 does not double a wait, or a wait rounds down to nothing.
  test('a factor applies to its own kind of limit, rounded up to a millisecond', () {
    final factors = LimitFactors.parse('services=2.0,machines=1.5,polling=0.25,retries=0.1');
    expect(factors.service(const Duration(seconds: 30)), const Duration(seconds: 60));
    expect(factors.machine(const Duration(seconds: 10)), const Duration(seconds: 15));
    expect(factors.poll(const Duration(seconds: 2)), const Duration(milliseconds: 500));
    expect(factors.retryPause(const Duration(milliseconds: 1)), const Duration(milliseconds: 1));
    expect(factors.tries(3), 1, reason: 'never less than one try');
    expect(LimitFactors.parse('retries=1.5').tries(3), 5, reason: 'rounded up');
    expect(LimitFactors.standard.service(const Duration(milliseconds: 1500)), const Duration(milliseconds: 1500));
  });
}
