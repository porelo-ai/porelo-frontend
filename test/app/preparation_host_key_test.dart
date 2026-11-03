import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/preparation_host_key.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

import '../support/host_organization.dart' show hostKey;

void main() {
  final fingerprint = 'SHA256:${List.filled(43, 'A').join()}';

  // Harm: preparation trusts a key other than the one shown, or an unvalidated address changes the scan's options.
  test('the scanned Ed25519 key alone is fingerprinted on standard input', () async {
    final calls = <List<String>>[];
    final key = await fetchPreparationHostKey(
      '192.0.2.7',
      port: 2222,
      run: (program, arguments, {inDirectory, environment = const {}, input}) async {
        calls.add([program, ...arguments]);
        if (calls.length == 1) {
          expect(input, isNull);
          return (code: 0, out: '# SSH banner\n[192.0.2.7]:2222 $hostKey\n', err: '');
        }
        expect(input, '$hostKey\n', reason: 'the displayed fingerprint must be calculated from the fetched key');
        return (code: 0, out: '256 $fingerprint no comment (ED25519)\n', err: '');
      },
    );
    expect(calls.first.skip(1), ['-T', '5', '-t', 'ed25519', '-p', '2222', '192.0.2.7']);
    expect(calls.last.skip(1), ['-lf', '-']);
    expect(key, (key: hostKey, fingerprint: fingerprint));
  });

  // Harm: failed scans or malformed keys become a confirmable pin, or unsafe input launches an SSH tool.
  test('failed scans and unreadable fingerprints never produce a preparation key', () async {
    var calls = 0;
    var scan = (code: 0, out: '192.0.2.7 $hostKey\n', err: '');
    var printed = (code: 0, out: '256 $fingerprint no comment (ED25519)\n', err: '');
    Future<Ran> run(
      String program,
      List<String> arguments, {
      String? inDirectory,
      Map<String, String> environment = const {},
      String? input,
    }) async {
      calls++;
      return arguments.first == '-T' ? scan : printed;
    }

    for (final bad in [
      (code: 70, out: scan.out, err: ''),
      (code: 0, out: '', err: ''),
      (code: 0, out: '192.0.2.7 ssh-ed25519 broken\n', err: ''),
      (code: 0, out: '192.0.2.7 ssh-rsa AAAA\n', err: ''),
    ]) {
      scan = bad;
      await expectLater(fetchPreparationHostKey('192.0.2.7', run: run), throwsA(isA<WorkspaceRefused>()));
    }
    scan = (code: 0, out: '192.0.2.7 $hostKey\n', err: '');
    for (final bad in [
      (code: 1, out: printed.out, err: ''),
      (code: 0, out: 'unreadable', err: ''),
      (code: 0, out: '256 $fingerprint\n256 $fingerprint\n', err: ''),
    ]) {
      printed = bad;
      await expectLater(fetchPreparationHostKey('192.0.2.7', run: run), throwsA(isA<WorkspaceRefused>()));
    }
    final before = calls;
    for (final address in ['-option', 'host;command', 'host\nother', 'user@host']) {
      await expectLater(fetchPreparationHostKey(address, run: run), throwsA(isA<WorkspaceRefused>()));
    }
    expect(calls, before, reason: 'invalid input must not launch the process');
  });
}
