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
  // openssl's own form, which every version prints (-dateopt came after 3.0): notAfter=Oct 25 03:40:12 2036 GMT.
  final read = await Process.run('openssl', ['x509', '-noout', '-enddate', '-in', '${scratch.path}/ca-$days.pem']);
  expect(read.exitCode, 0, reason: '${read.stderr}');
  final said = RegExp(r'^notAfter=(\w{3}) +(\d{1,2}) (\d{2}):(\d{2}):(\d{2}) (\d{4}) GMT$')
      .firstMatch('${read.stdout}'.trim());
  expect(said, isNotNull, reason: 'openssl said ${read.stdout}');
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  int part(int group) => int.parse(said!.group(group)!);
  return (pem, DateTime.utc(part(6), months.indexOf(said!.group(1)!) + 1, part(2), part(3), part(4), part(5)));
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

  test('each form of the end, read from a certificate built here, and what hides its end refused', () {
    expect(
      certificateEnds(_pem(_certificate(notAfter: _utc('991231235959Z')))),
      DateTime.utc(1999, 12, 31, 23, 59, 59),
    );
    expect(certificateEnds(_pem(_certificate(notAfter: _utc('490101000000Z')))), DateTime.utc(2049));
    expect(certificateEnds(_pem(_certificate(notAfter: _generalized('21000101000000Z')))), DateTime.utc(2100));
    expect(
      certificateEnds(_pem(_certificate(notAfter: _utc('361025034012Z'), version: false))),
      DateTime.utc(2036, 10, 25, 3, 40, 12),
    );
    // An issuer longer than 127 bytes has a long length.
    expect(
      certificateEnds(_pem(_certificate(notAfter: _utc('361025034012Z'), issuer: 300))),
      DateTime.utc(2036, 10, 25, 3, 40, 12),
    );
    for (final (why, der) in [
      ('a month 13', _certificate(notAfter: _generalized('20261399000000Z'))),
      ('a minute 61', _certificate(notAfter: _utc('261028086100Z'))),
      (
        'fractional seconds, which DER certificates do not have',
        _certificate(notAfter: _generalized('20261028080000.5Z')),
      ),
      ('an offset in place of Z', _certificate(notAfter: _utc('261028080000+0200'))),
      (
        'a validity of one time, a later one after it',
        _certificate(notAfter: [], after: _generalized('20991231235959Z')),
      ),
      (
        'a later time before the end, in the validity',
        _certificate(notAfter: [..._generalized('20991231235959Z'), ..._utc('261028080000Z')]),
      ),
      // Read as 128 bytes, the issuer would end where a certificate's does.
      (
        'an issuer of indefinite length',
        _certificate(notAfter: _utc('361025034012Z'), rawIssuer: [0x30, 0x80, ...List<int>.filled(128, 0x41)]),
      ),
      // Read up to the certificate's end, not the part's, the fields after a short part would give a date.
      (
        'a validity outside the part it belongs to',
        _element(0x30, [
          ..._element(0x30, _element(0x02, [1])),
          ..._element(0x30, []),
          ..._element(0x30, []),
          ..._element(0x30, [..._utc('260101000000Z'), ..._utc('361025034012Z')]),
          ..._element(0x03, [0]),
        ]),
      ),
      ('a 30 February, which would roll into March', _certificate(notAfter: _generalized('20260230000000Z'))),
      ('a part longer than its certificate', _element(0x30, [0x30, 0x7f, 0x02, 0x01, 0x01, 0x30, 0x00])),
      (
        'a serial longer than the part it is in',
        _element(0x30, [
          ..._element(0x30, [0x02, 0x10, 0x01]),
          ..._element(0x30, [
            ..._element(0x30, []),
            ..._element(0x30, [..._utc('260101000000Z'), ..._utc('361025034012Z')]),
          ]),
          ..._element(0x03, [0]),
        ]),
      ),
      ('bytes after the certificate', [..._certificate(notAfter: _utc('361025034012Z')), 0]),
      ('an indefinite length', [0x30, 0x80, 0x30, 0x00, 0x00, 0x00]),
      ('a certificate that ends at its own start', [0x30, 0x02, 0x30, 0x00]),
      ('a length past its parent', [0x30, 0x84, 0x7f, 0xff, 0xff, 0xff, 0x30]),
    ]) {
      expect(certificateEnds(_pem(der)), isNull, reason: why);
    }
    expect(certificateEnds('-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n'), isNull);
  });

  test('warned 90 days before the end and after it, never earlier, nor for what is not one certificate', () {
    final pem = _pem(_certificate(notAfter: _utc('361025034012Z')));
    final ends = DateTime.utc(2036, 10, 25, 3, 40, 12);
    expect(forgeCaWarning(pem, ends.subtract(const Duration(days: 91))), isNull);
    final before = forgeCaWarning(pem, ends.subtract(const Duration(days: 89)))!;
    expect(before, contains('ends on 2036-10-25 03:40 UTC'));
    expect(before, contains('remove shared/forge-ca and shared/forge-ca-key'));
    expect(before, contains('A server set up before takes it only when it is set up again'));
    expect(before, isNot(contains('this stop makes the new one')));
    expect(forgeCaWarning(pem, ends.add(const Duration(minutes: 1))), contains('ended on 2036-10-25 03:40 UTC'));
    expect(forgeCaWarning(pem, ends, atTheStop: true), contains('Where you removed them already, this stop makes'));
    expect(forgeCaWarning(null, ends), isNull);
    expect(forgeCaWarning('-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n', ends), isNull);
  });
}

List<int> _element(int tag, List<int> content) => [
  tag,
  if (content.length < 0x80)
    content.length
  else if (content.length < 0x100) ...[
    0x81,
    content.length,
  ] else ...[
    0x82,
    content.length >> 8,
    content.length & 0xff,
  ],
  ...content,
];

List<int> _utc(String text) => _element(0x17, ascii.encode(text));

List<int> _generalized(String text) => _element(0x18, ascii.encode(text));

/// A certificate's shape as far as its end: the fields before the validity hold nothing a reader needs.
List<int> _certificate({
  required List<int> notAfter,
  bool version = true,
  int issuer = 0,
  List<int>? rawIssuer,
  List<int> after = const [],
}) => _element(0x30, [
  ..._element(0x30, [
    if (version) ..._element(0xa0, _element(0x02, [2])),
    ..._element(0x02, [1]),
    ..._element(0x30, []),
    ...?rawIssuer,
    if (rawIssuer == null) ..._element(0x30, List<int>.filled(issuer, 0x41)),
    ..._element(0x30, [..._utc('260101000000Z'), ...notAfter]),
    ...after,
    ..._element(0x30, []),
  ]),
  ..._element(0x30, []),
  ..._element(0x03, [0]),
]);

String _pem(List<int> der) {
  final text = base64.encode(der);
  final lines = [
    for (var i = 0; i < text.length; i += 64) text.substring(i, i + 64 > text.length ? text.length : i + 64),
  ];
  return '-----BEGIN CERTIFICATE-----\n${lines.join('\n')}\n-----END CERTIFICATE-----\n';
}
