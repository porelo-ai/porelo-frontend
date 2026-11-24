// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/machine.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A waiting push's review summary, `ReviewSummary`, over a real socket.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  const commit = '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d';

  // Harm: a summary asked of another push or commit than the one shown, or read under other names than the
  // daemon's, shows counts that are not this push's.
  test('the summary is asked for exactly the push and commit, and read by the names the daemon gives', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.method('ReviewSummary', (parameters) {
      asked.add(parameters);
      return <String, dynamic>{
        'openFindings': 2,
        'openThreads': 3,
        'runs': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'owner review', 'completeness': 'complete', 'findings': 2},
          <String, dynamic>{'name': 'lint', 'completeness': 'partial', 'findings': 0},
        ],
      };
    });
    final client = await connect();

    final summary = await client.reviewSummary('checkout', 'migrate', repository: 'payments-api', commit: commit);

    expect(asked.single, <String, dynamic>{
      'project': 'checkout',
      'repository': 'payments-api',
      'name': 'migrate',
      'commit': commit,
    });
    expect(summary.openFindings, 2);
    expect(summary.openThreads, 3);
    expect(
      [for (final run in summary.runs) (run.name, run.completeness, run.findings)],
      [('owner review', 'complete', 2), ('lint', 'partial', 0)],
    );
    expect(summary.runs.first.complete, isTrue);
    expect(summary.runs.last.complete, isFalse);
  });

  // Harm: a completeness this build does not know is read as finished, or dropped, and the run reads clean.
  test('a completeness this build does not know is kept as said, and is not complete', () async {
    daemon.method(
      'ReviewSummary',
      (_) => <String, dynamic>{
        'openFindings': 0,
        'openThreads': 0,
        'runs': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'owner review', 'completeness': 'stalled-at-the-forge', 'findings': 0},
        ],
      },
    );
    final client = await connect();

    final run = (await client.reviewSummary('checkout', 'migrate', commit: commit)).runs.single;

    expect(run.completeness, 'stalled-at-the-forge');
    expect(run.complete, isFalse);
  });

  // Harm: an older daemon's missing summary reads as zero findings and zero threads.
  test('a daemon without the method is a feature it does not have, never zeros', () async {
    final client = await connect();

    await expectLater(
      client.reviewSummary('checkout', 'migrate', commit: commit),
      throwsA(isA<FeatureNotSupported>().having((missing) => missing.method, 'method', 'ReviewSummary')),
    );
  });

  // Harm: a malformed answer reads as zeros.
  test('an answer without its counts is refused, never read as zero', () async {
    daemon.method('ReviewSummary', (_) => <String, dynamic>{'runs': <Object>[]});
    final client = await connect();

    await expectLater(client.reviewSummary('checkout', 'migrate', commit: commit), throwsA(isA<FormatException>()));
  });

  // Harm: a summary refused because the push moved is taken for zeros of the push shown.
  test('a push that moved is refused as the review refuses it', () async {
    daemon.method(
      'ReviewSummary',
      (_) => throw const MockRefusal('org.fuin.porelo.Tasks1.MovedSinceReview', <String, dynamic>{
        'name': 'migrate',
        'reviewed': commit,
        'now': 'b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0',
      }),
    );
    final client = await connect();

    await expectLater(
      client.reviewSummary('checkout', 'migrate', commit: commit),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'name', 'MovedSinceReview')),
    );
  });

  // Harm: the stand-in machine a person runs the window against answers a summary for a push that is gone or moved,
  // or shows only one state.
  test('the stand-in machine answers each push at its commit, and refuses one gone or moved', () async {
    MockMachine(daemon, pace: Duration.zero);
    final client = await connect();

    final migrate = await client.reviewSummary('checkout', 'migrate', commit: '9a3c1f2');
    expect(migrate.runs.single.completeness, 'partial');
    final dropped = await client.reviewSummary('checkout', 'drop-dead-code', commit: '7f21b0e');
    expect((dropped.openFindings, dropped.openThreads, dropped.runs.single.complete), (1, 1, true));
    await expectLater(
      client.reviewSummary('checkout', 'migrate', commit: '7f21b0e'),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'name', 'MovedSinceReview')),
    );
    await expectLater(
      client.reviewSummary('checkout', 'nowhere', commit: '7f21b0e'),
      throwsA(isA<VarlinkException>().having((refusal) => refusal.simpleName, 'name', 'NoSuchPush')),
    );
  });
}
