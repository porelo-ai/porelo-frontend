@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A start's own key and the tasks a reader reads, as Core's Tasks1 Start takes them.
void main() {
  late MockDaemon daemon;
  Map<String, dynamic>? asked;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
    asked = null;
    daemon.stream('Start', (parameters) async* {
      asked = parameters;
      yield <String, dynamic>{'exitCode': 0};
    });
  });
  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  test('a start gives its key and the tasks it reads to a machine that takes them', () async {
    daemon.description = 'method Start(task: ?string, callerKey: ?string, reads: ?[]string) -> (exitCode: ?int)';
    await (await connect()).start(project: 'demo', callerKey: 'offer-1', reads: ['foo-1']).toList();
    expect(asked, <String, dynamic>{
      'project': 'demo',
      'callerKey': 'offer-1',
      'reads': ['foo-1'],
    });
  });

  // Harm: a machine that keeps no key refuses a start the window could have made without it.
  test('a machine that keeps no key is started without it', () async {
    daemon.description = 'method Start(task: ?string) -> (exitCode: ?int)';
    await (await connect()).start(project: 'demo', callerKey: 'offer-1').toList();
    expect(asked, <String, dynamic>{'project': 'demo'});
  });

  // Harm: a reader starts seeing none of the work it is to read, and searches for it until its time runs out.
  test('a machine that cannot hand a reader its work is not asked to start it, and says so', () async {
    daemon.description = 'method Start(task: ?string, callerKey: ?string) -> (exitCode: ?int)';
    await expectLater(
      (await connect()).start(project: 'demo', reads: ['foo-1']).toList(),
      throwsA(isA<FeatureNotSupported>()),
    );
    expect(asked, isNull);
  });

  test('a listed task gives back the key it was started with, and none as empty', () {
    expect(Task.from(<String, dynamic>{'name': 'a', 'callerKey': 'offer-1'}).callerKey, 'offer-1');
    expect(Task.from(<String, dynamic>{'name': 'a'}).callerKey, isEmpty);
  });

  test('a listed task gives the branches its work landed on as Porelo names them, none while it waits', () {
    final entry = <String, dynamic>{
      'branch': 'porelo/foo-1',
      'ref': 'refs/porelo/landed/foo-1/porelo/foo-1',
      'remote': 'origin/landed/foo-1/porelo/foo-1',
      'commit': 'a' * 40,
    };
    expect(
      Task.from(<String, dynamic>{
        'name': 'a',
        'landed': [entry],
      }).landed,
      [entry],
    );
    expect(Task.from(<String, dynamic>{'name': 'a', 'landed': <Object>[]}).landed, isEmpty);
    expect(Task.from(<String, dynamic>{'name': 'a'}).landed, isNull);
  });
}
