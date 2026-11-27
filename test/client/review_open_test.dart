// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/machine.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// How the gate's record of a push ends, asked with `ReviewOpen`, over a real socket.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  // Harm: the push is asked about as a pull request, or as the task of another push, and the answer names the
  // wrong task as its rejecter.
  test('a push is asked about by its project and its place at the gate, with no task', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.method('ReviewOpen', (parameters) {
      asked.add(parameters);
      return <String, dynamic>{
        'decision': 'REJECTED',
        'rejectedBy': 'screener-1',
        'decisionSince': '2026-01-02T03:04:05Z',
      };
    });
    final client = await connect();

    final end = await client.reviewOpen(
      'checkout',
      const RunPlace(gatePush: (repository: 'payments-api', name: 'fix')),
    );

    expect(asked.single, <String, dynamic>{
      'project': 'checkout',
      'place': <String, dynamic>{
        'gatePush': <String, dynamic>{'repository': 'payments-api', 'name': 'fix'},
      },
    });
    expect(asked.single.containsKey('task'), isFalse);
    expect(end.decision, 'REJECTED');
    expect(end.rejectedBy, 'screener-1');
    expect(end.decisionSince, '2026-01-02T03:04:05Z');
  });

  // Harm: a field of the wrong type is cast, throws, and the answer is lost, or is taken for a task's name.
  test('a field of the wrong type reads as absent, and an absent one stays absent', () async {
    daemon.method(
      'ReviewOpen',
      (_) => <String, dynamic>{
        'decision': 7,
        'rejectedBy': <String>['a'],
        'decisionSince': 5,
      },
    );
    final client = await connect();

    final end = await client.reviewOpen('checkout', const RunPlace(gatePush: (repository: null, name: 'fix')));

    expect(end.decision, isNull);
    expect(end.rejectedBy, isNull);
    expect(end.decisionSince, isNull);
  });

  test('an answer of the owner account carries no task', () async {
    daemon.method('ReviewOpen', (_) => <String, dynamic>{'decision': 'REJECTED'});
    final client = await connect();

    final end = await client.reviewOpen('checkout', const RunPlace(gatePush: (repository: null, name: 'fix')));

    expect(end.decision, 'REJECTED');
    expect(end.rejectedBy, isNull);
  });

  test('the mock machine answers a push from the state a test sets, and refuses one it does not know', () async {
    final machine = MockMachine(daemon, pace: Duration.zero);
    addTearDown(machine.close);
    machine.pushEnds['fix'] = <String, dynamic>{'decision': 'REJECTED', 'rejectedBy': 'screener-1'};
    final client = await connect();

    expect(
      (await client.reviewOpen('checkout', const RunPlace(gatePush: (repository: null, name: 'fix')))).rejectedBy,
      'screener-1',
    );
    expect(machine.reviewOpenAsked, hasLength(1));
    await expectLater(
      client.reviewOpen('checkout', const RunPlace(gatePush: (repository: null, name: 'nothing-of-the-sort'))),
      throwsA(isA<VarlinkException>()),
    );
  });
}
