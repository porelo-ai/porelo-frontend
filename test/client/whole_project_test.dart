@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A task that reads every repository of its project and hands back a result file, as Core's Tasks1 says it.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });
  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  const declares = 'method Start(task: ?string, allRepositories: ?bool, result: ?string) -> (exitCode: ?int)';

  test('a start over every repository asks for it and for its result file, with no repository', () async {
    daemon.description = declares;
    Map<String, dynamic>? asked;
    daemon.stream('Start', (parameters) async* {
      asked = parameters;
      yield <String, dynamic>{'exitCode': 0};
    });
    await (await connect()).start(project: 'demo', allRepositories: true, result: 'idea.json').toList();
    expect(asked, <String, dynamic>{'project': 'demo', 'allRepositories': true, 'result': 'idea.json'});
  });

  // Harm: a machine that does not know the option would start an ordinary task, one repository writable, where the
  // person asked for one that reads everything and changes nothing.
  for (final description in <String?>[
    null,
    'method Start(task: ?string) -> (exitCode: ?int)',
    'method Start(task: ?string, result: ?string) -> (exitCode: ?int)',
  ]) {
    test('a machine that does not declare it is not asked, and says so: $description', () async {
      daemon.description = description;
      var started = false;
      daemon.stream('Start', (parameters) async* {
        started = true;
        yield <String, dynamic>{'exitCode': 0};
      });
      await expectLater(
        (await connect()).start(project: 'demo', allRepositories: true, result: 'idea.json').toList(),
        throwsA(isA<FeatureNotSupported>()),
      );
      expect(started, isFalse);
    });
  }

  // Harm: a machine that cannot hand a file back is asked for one, and the person waits for an idea that never comes.
  for (final description in <String?>[
    'method Start(task: ?string) -> (exitCode: ?int)',
    'method Start(task: ?string, allRepositories: ?bool) -> (exitCode: ?int)',
  ]) {
    test('a result file is not asked of a machine that does not declare it: $description', () async {
      daemon.description = description;
      var started = false;
      daemon.stream('Start', (parameters) async* {
        started = true;
        yield <String, dynamic>{'exitCode': 0};
      });
      await expectLater(
        (await connect()).start(project: 'demo', result: 'idea.json').toList(),
        throwsA(isA<FeatureNotSupported>()),
      );
      expect(started, isFalse);
    });
  }

  // Harm: the person chooses an agent and a model for a discussion the machine cannot start, and learns it only after.
  test('a machine says ahead whether it can start a discussion', () async {
    daemon.description = declares;
    expect(await (await connect()).whyNoDiscussion(), isNull);
    for (final lacking in <String?>[
      null,
      'method Start(task: ?string, result: ?string) -> (exitCode: ?int)',
      'method Start(task: ?string, allRepositories: ?bool) -> (exitCode: ?int)',
    ]) {
      daemon.description = lacking;
      expect(await (await connect()).whyNoDiscussion(), contains('newer Porelo'), reason: '$lacking');
    }
  });

  // Harm: one failed read of the contract leaves a machine unable to start a discussion until the window restarts.
  test('a read of the contract that failed is asked again, not kept', () async {
    final client = await connect();
    daemon.describeRefusal = 'org.fuin.porelo.Tasks1.Busy';
    await expectLater(client.whyNoDiscussion(), throwsA(isA<VarlinkException>()));

    daemon
      ..describeRefusal = null
      ..description = declares;
    expect(await client.whyNoDiscussion(), isNull);
  });

  test('CanStart is asked about every repository where the start is', () async {
    Map<String, dynamic>? asked;
    daemon.method('CanStart', (parameters) {
      asked = parameters;
      return <String, dynamic>{'ready': true};
    });
    await (await connect()).canStart(project: 'demo', agent: 'pi', allRepositories: true);
    expect(asked, <String, dynamic>{'project': 'demo', 'agent': 'pi', 'allRepositories': true});
  });

  test('an end names the result file and how it stood', () {
    final ended = AgentEnded.from(<String, dynamic>{
      'at': '2026-11-11T12:00:00Z',
      'finished': true,
      'result': <String, dynamic>{'name': 'idea.json', 'state': 'handed', 'bytes': 812},
    });
    expect(ended.result?.name, 'idea.json');
    expect(ended.result?.state, ResultState.handed);
    expect(ended.result?.bytes, 812);
    expect(AgentEnded.from(<String, dynamic>{'at': 'x', 'finished': true}).result, isNull);
  });

  for (final state in <(String, ResultState)>[
    ('handed', ResultState.handed),
    ('missing', ResultState.missing),
    ('too-large', ResultState.tooLarge),
    ('unreadable', ResultState.unreadable),
  ]) {
    test('the state ${state.$1} is read as such', () {
      expect(TaskResult.from(<String, dynamic>{'name': 'idea.json', 'state': state.$1}).state, state.$2);
    });
  }

  test('a state the window does not know is kept as such, not taken for handed', () {
    final ended = AgentEnded.from(<String, dynamic>{
      'at': 'x',
      'finished': true,
      'result': <String, dynamic>{'name': 'idea.json', 'state': 'eaten', 'bytes': 0},
    });
    expect(ended.result?.state, ResultState.unknown);
  });

  test('the result is asked of the ended task, with its content', () async {
    Map<String, dynamic>? asked;
    daemon.method('Result', (parameters) {
      asked = parameters;
      return <String, dynamic>{'name': 'idea.json', 'state': 'handed', 'bytes': 2, 'content': '{}'};
    });
    final result = await (await connect()).result('idea-1');
    expect(asked, <String, dynamic>{'task': 'idea-1'});
    expect(result.state, ResultState.handed);
    expect(result.content, '{}');
  });

  test('a machine without Result says so', () async {
    await expectLater((await connect()).result('idea-1'), throwsA(isA<FeatureNotSupported>()));
  });
}
