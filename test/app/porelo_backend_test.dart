// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// The real backend over a real socket, where a reply's meaning is decided.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloBackend> open() async {
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'));
    await backend.open();
    return backend;
  }

  // A refusal is an ordinary final reply, with no exit code to fail on.
  test('a refused start fails the operation, naming the refusal', () async {
    daemon.stream('Start', (_) async* {
      yield <String, dynamic>{'line': 'Resolving project.yml'};
      yield <String, dynamic>{'action': 'NEEDS_VAULT'};
    });
    final backend = await open();

    await expectLater(
      backend.startTask(task: 'porelo-demo-shell').toList(),
      throwsA(isA<StartRefused>().having((refused) => '$refused', 'words', contains('vault is locked'))),
    );
  });

  test('a start that created the task completes', () async {
    daemon.stream('Start', (_) async* {
      yield <String, dynamic>{'line': 'Resolving project.yml'};
      yield <String, dynamic>{'action': 'CREATE', 'container': 'porelo-demo-shell', 'exitCode': 0};
    });
    final backend = await open();

    expect(await backend.startTask(task: 'porelo-demo-shell').toList(), <String>['Resolving project.yml']);
  });
}
