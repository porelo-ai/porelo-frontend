import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_check_run.dart';
import 'package:porelo_host/porelo_host.dart' show HostPreparationSettings;

void main() {
  // Harm: the check's own words on standard error are dropped, and the person reads "no answer" without a cause.
  test('a check without an answer says what porelo-host wrote on standard error, with its exit', () async {
    final check = HostCheckRun(
      run: (program, arguments, {inDirectory, environment = const {}, input}) async =>
          (code: 3, out: '', err: 'porelo-host: the collection beside this command could not be read\n'),
      executable: 'porelo-host',
    );
    final answer = await check.check(
      address: '192.0.2.7',
      hostKey: 'ssh-ed25519 AAAA',
      publicKey: 'ssh-ed25519 BBBB',
      settings: const HostPreparationSettings(),
    );
    expect(answer.answered, isFalse, reason: 'exit 3 is no answer of the check');
    expect(answer.said, contains('the collection beside this command could not be read'));
    expect(answer.said, contains('exit 3'));
  });

  // Harm: a warning on standard error replaces the check's findings, and a passing machine reads as refused.
  test('an answer of the check stays the check\'s own, whatever stands on standard error', () async {
    final check = HostCheckRun(
      run: (program, arguments, {inDirectory, environment = const {}, input}) async => (
        code: 0,
        out: '{"v":1,"ok":true,"complete":true,"findings":[{"id":"memory","state":"pass"}]}',
        err: 'a warning\n',
      ),
      executable: 'porelo-host',
    );
    final answer = await check.check(
      address: '192.0.2.7',
      hostKey: 'ssh-ed25519 AAAA',
      publicKey: 'ssh-ed25519 BBBB',
      settings: const HostPreparationSettings(),
    );
    expect(answer.passed, isTrue);
  });
}
