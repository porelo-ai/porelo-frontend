// openssl makes the certificates; the forge's CA is kept on Linux only, where the stop is fed from the file.
@TestOn('linux')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_vpn.dart';

/// A certificate made by this computer's openssl, ending in [days], and the end openssl itself reads from it.
Future<(String, DateTime)> _made(Directory scratch, int days) async {
  final made = await Process.run('openssl', [
    'req', '-x509', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:P-256', '-nodes', '-days', '$days', //
    '-subj', '/CN=forge-ca-test', '-keyout', '${scratch.path}/key-$days.pem', '-out', '${scratch.path}/ca-$days.pem',
  ]);
  expect(made.exitCode, 0, reason: '${made.stderr}');
  final pem = File('${scratch.path}/ca-$days.pem').readAsStringSync();
  final read = await Process.run('openssl', [
    'x509', '-noout', '-enddate', '-dateopt', 'iso_8601', '-in', '${scratch.path}/ca-$days.pem', //
  ]).then((result) => '${result.stdout}'.trim());
  // notAfter=2036-10-25 03:40:12Z
  return (pem, DateTime.parse(read.substring('notAfter='.length).replaceFirst(' ', 'T')));
}

void main() {
  late Directory scratch;
  setUp(() => scratch = Directory.systemTemp.createTempSync('forge-ca-ends-'));
  tearDown(() => scratch.deleteSync(recursive: true));

  // Harm: a lasting CA that ends unseen, so every forge stops opening in the browser on one day, or a warning that
  // comes for a CA with years left.
  test('the end is read as openssl reads it, in either of its two time forms', () async {
    // Ten years ends in UTCTime; past 2049 it is GeneralizedTime.
    for (final days in [3650, 30000]) {
      final (pem, ends) = await _made(scratch, days);
      expect(certificateEnds(pem), ends, reason: '$days days');
    }
  });

  test('warned 90 days before the end and after it, never earlier, nor for what is not one certificate', () async {
    final (pem, ends) = await _made(scratch, 3650);
    expect(forgeCaWarning(pem, ends.subtract(const Duration(days: 91))), isNull);
    expect(
      forgeCaWarning(pem, ends.subtract(const Duration(days: 89))),
      contains('ends on ${ends.toIso8601String().substring(0, 10)}'),
    );
    expect(forgeCaWarning(pem, ends.add(const Duration(days: 1))), contains('ended on'));
    expect(forgeCaWarning(pem, ends), contains('shared/forge-ca and shared/forge-ca-key'));
    expect(forgeCaWarning(null, ends), isNull);
    for (final bad in [
      '-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n',
      // A length that runs past the end.
      '-----BEGIN CERTIFICATE-----\n${base64.encode([0x30, 0x84, 0x7f, 0xff, 0xff, 0xff, 0x30])}\n-----END CERTIFICATE-----\n',
    ]) {
      expect(certificateEnds(bad), isNull, reason: bad);
      expect(forgeCaWarning(bad, ends), isNull);
    }
  });
}
