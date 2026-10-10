// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sokar_frontend/client.dart';
import 'package:sokar_frontend/src/app/fleet_backend.dart';
import 'package:sokar_frontend/src/app/outcome_words.dart';
import 'package:sokar_frontend/src/mock/mock_daemon.dart';

/// Starting a listed task again, when the machine says no with an exit code.
///
/// Reported: *Start it again* said only "failed with exit code 70", and
/// the daemon had printed which agent it wanted, a line before.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  // The replies measured on the Ubuntu VM that day, in order.
  const measured = <Map<String, dynamic>>[
    <String, dynamic>{'line': 'task           sokar-utils4j-shell'},
    <String, dynamic>{'line': 'project        utils4j'},
    <String, dynamic>{'line': 'task image     sokar/utils4j'},
    <String, dynamic>{
      'line': 'sokar: org.fuin.sokar.agent.api.AgentException: Several agents are installed '
          '(claude, stub), so --agent is required',
    },
    <String, dynamic>{'output': <String>[], 'container': '', 'exitCode': 70},
  ];

  test('what the machine printed before failing comes back with the result', () async {
    daemon.stream('Start', (_) async* {
      for (final reply in measured) {
        yield reply;
      }
    });
    final backend = SokarBackend(Backend(socketPath: daemon.socketPath, label: 'mock'));
    await backend.open();

    final result = await backend.startAgain(project: '/srv/utils4j/project.yml', task: 'sokar-utils4j-shell');

    expect(result.exitCode, 70);
    expect(result.output, hasLength(4));
    expect(startWords('sokar-utils4j-sokar-utils4j-shell', result),
        contains('Several agents are installed (claude, stub), so --agent is required'));
  });

  test('the reason is the last thing said, not the plan printed on the way', () {
    const result = StartProgress(exitCode: 69, output: <String>[
      'task           sokar-utils4j-shell',
      'reachable      deb.debian.org                 set os-packages-debian',
      '               github.com                     set git-hosting',
      'sokar: sokar-utils4j-sokar-utils4j-shell was started before this machine restarted, so it cannot be started again.',
      '       Its sockets were under \$XDG_RUNTIME_DIR, which the system clears on restart.',
      '',
      '         podman cp sokar-utils4j-sokar-utils4j-shell:/workspace ./recovered',
    ]);

    final words = startWords('sokar-utils4j-sokar-utils4j-shell', result);

    expect(words, contains('failed with exit code 69'));
    expect(words, contains('cannot be started again'));
    expect(words, contains('podman cp sokar-utils4j-sokar-utils4j-shell:/workspace ./recovered'));
    expect(words, isNot(contains('deb.debian.org')));
  });

  test('work started before its machine restarted is a known refusal, said in words', () {
    const predates = StartAction('PREDATES_RESTART');

    expect(predates.isKnown, isTrue);
    expect(predates.starts, isFalse);
    expect(startWords('sokar-predates-shell', const StartProgress(action: predates, exitCode: 69)),
        contains('was started before this machine restarted'));
    expect('${const StartRefused(predates)}', contains('started before this machine restarted'));
  });

  test('a failure that printed nothing still says its exit code, and no more', () {
    expect(startWords('sokar-demo-shell', const StartProgress(exitCode: 70)),
        'Starting sokar-demo-shell failed with exit code 70.');
  });
}
