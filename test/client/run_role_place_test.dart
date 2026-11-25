@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A run's role and the place it works, handed to Porelo's Start as the planner's order names them.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });
  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  const declares = 'method Start(task: ?string, role: ?(AUTHOR, REVIEWER), place: ?Place) -> (exitCode: ?int)';
  const place = <String, Object?>{
    'gatePush': <String, Object?>{'repository': 'porelo', 'name': 'porelo-demo-porelo'},
  };

  // Harm: a reviewer starts at another place than the planner read, or as an author at its own work.
  test('the role and the place reach Start unchanged, and nothing of them where the order names none', () async {
    daemon.description = declares;
    final asked = <Map<String, dynamic>>[];
    daemon.stream('Start', (parameters) async* {
      asked.add(parameters);
      yield <String, dynamic>{'exitCode': 0};
    });
    final client = await connect();
    await client.start(project: 'demo', role: 'REVIEWER', place: place).toList();
    await client.start(project: 'demo').toList();

    expect(asked.first, <String, dynamic>{'project': 'demo', 'role': 'REVIEWER', 'place': place});
    expect(asked.last.containsKey('role') || asked.last.containsKey('place'), isFalse);
  });

  // Harm: a machine that does not know them starts the run as an author at its own work.
  for (final (role, place) in <(String?, Map<String, Object?>?)>[('REVIEWER', null), (null, place)]) {
    test('a machine whose Start takes no ${role == null ? 'place' : 'role'} is not asked, and says so', () async {
      daemon.description = 'method Start(task: ?string) -> (exitCode: ?int)';
      var started = false;
      daemon.stream('Start', (parameters) async* {
        started = true;
        yield <String, dynamic>{'exitCode': 0};
      });
      await expectLater(
        (await connect()).start(project: 'demo', role: role, place: place).toList(),
        throwsA(isA<FeatureNotSupported>()),
      );
      expect(started, isFalse);
    });
  }
}
