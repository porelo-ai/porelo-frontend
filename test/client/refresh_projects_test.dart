// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sokar_frontend/client.dart';
import 'package:sokar_frontend/src/app/fleet_backend.dart';
import 'package:sokar_frontend/src/mock/machine.dart';
import 'package:sokar_frontend/src/mock/mock_daemon.dart';

/// Holds checking a followed project now to what the machine answers, over a real socket.
void main() {
  late MockDaemon daemon;
  late MockMachine machine;
  late SokarBackend backend;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
    machine = MockMachine(daemon, pace: Duration.zero);
    backend = SokarBackend(Backend(socketPath: daemon.socketPath, label: 'mock'));
    await backend.open();
  });

  tearDown(() async {
    await machine.close();
    await daemon.stop();
  });

  test('a followed project is fetched now and answered as its record', () async {
    await backend.follow('payments', 'git@example.org:payments.git', unverified: true);

    final records = await backend.refreshProjects(project: 'payments');

    expect(records.map((each) => (each.name, each.outcome, each.commit)), [('payments', 'UNCHANGED', 'c0ffee1d2e3f')]);
  });

  test('without a name every followed project is fetched', () async {
    await backend.follow('payments', 'git@example.org:payments.git', unverified: true);
    await backend.follow('shop', 'git@example.org:shop.git', unverified: true);

    expect((await backend.refreshProjects()).map((each) => each.name), containsAll(<String>['payments', 'shop']));
  });

  test('a project this account does not follow is refused by name, not answered empty', () async {
    await expectLater(
      backend.refreshProjects(project: 'nobody'),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'error', 'NoSuchProject')),
    );
  });

  test('a task is brought up to its source, and one that is not a task is refused by name', () async {
    final task = (await backend.tasks()).first;

    final refreshed = await backend.refreshTask(task.name);

    expect(refreshed.outcome, anyOf('UNCHANGED', 'NOT_GATED'));
    await expectLater(
      backend.refreshTask('no-such-task'),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'error', 'NoSuchTask')),
    );
  });
}
