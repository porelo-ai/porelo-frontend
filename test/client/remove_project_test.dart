// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/project_deletion.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// `RemoveProject` on the wire: the parameters and the answer `Deletion` reads.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  // Harm: a removal goes out without the preview it was asked with, and removes what it was to describe.
  test('its name, preview and force go out as asked, and the answer is read', () async {
    late Map<String, dynamic> asked;
    daemon.method('RemoveProject', (parameters) {
      asked = parameters;
      return <String, dynamic>{
        'outcome': 'PREVIEWED',
        'removes': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'MIRROR', 'what': '/srv/local/.porelo/mirror'},
        ],
        'keeps': <String>['/srv/local/project.yml'],
        'unreviewed': <String>[],
        'running': <String>[],
      };
    });

    final answer = await (await connect()).removeProject('local', dryRun: true);

    expect(asked, <String, dynamic>{'name': 'local', 'dryRun': true});
    expect(answer.outcome, DeleteOutcome.previewed);
    expect(answer.removes.single.what, '/srv/local/.porelo/mirror');
    expect(answer.keeps, ['/srv/local/project.yml']);
  });

  // Harm: a daemon too old to know the call reads as a failed machine, or takes the rest of the frame with it.
  test('a daemon that has no such method says so for this feature alone', () async {
    daemon.method('Projects', (_) => <String, dynamic>{'projects': <Map<String, dynamic>>[]});
    final client = await connect();

    await expectLater(client.removeProject('local', dryRun: true), throwsA(isA<FeatureNotSupported>()));
    expect(await client.projects(), isEmpty, reason: 'every other call goes on working');
  });

  // Harm: a person is left thinking something happened, or nothing can be said of why.
  test('the removal says the daemon cannot do it, and says it was not removed', () async {
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'));
    await backend.open();
    final deleting = ProjectDeletion();
    addTearDown(deleting.dispose);

    await deleting.consider(backend, 'local');

    expect(deleting.problem, contains('RemoveProject'));
    expect(deleting.removed, isFalse);
    expect(deleting.answer, isNull);
  });

  // Harm: the machine's own refusal of an organization's project is lost for a bare name.
  test('a refusal is said by its words', () async {
    daemon.method(
      'RemoveProject',
      (_) => throw const MockRefusal('org.fuin.porelo.Tasks1.NotAllowed', <String, dynamic>{
        'message': 'demo is the organization’s',
      }),
    );
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'));
    await backend.open();
    final deleting = ProjectDeletion();
    addTearDown(deleting.dispose);

    await deleting.consider(backend, 'demo');

    expect(deleting.problem, contains('demo is the organization’s'));
    expect(deleting.removed, isFalse);
  });
}
