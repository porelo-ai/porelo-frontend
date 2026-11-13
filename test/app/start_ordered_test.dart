// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A task a planner ordered, started with exactly the arguments the order gives.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<StartProgress> startOrdered(PoreloBackend backend) => backend.startOrdered(
    project: 'demo',
    repository: 'porelo',
    agent: 'claude',
    model: 'opus',
    mode: Mode.agent,
    prompt: '  Work on ST1.\n',
  );

  // Harm: a planned task starts with an argument the order did not give, or without one it gave.
  test(
    'Start gets the order\'s project, repository, agent, model, mode and prompt as given, and asks to answer at once',
    () async {
      final asked = <Map<String, dynamic>>[];
      daemon.stream('Start', (parameters) async* {
        asked.add(parameters);
        yield <String, dynamic>{'line': 'starting'};
        yield <String, dynamic>{'container': 'porelo-demo-porelo', 'exitCode': 0, 'action': 'CREATE'};
      });
      final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
      await backend.open();

      final answer = await startOrdered(backend);

      expect(asked.single, <String, dynamic>{
        'project': 'demo',
        'repository': 'porelo',
        'agent': 'claude',
        'model': 'opus',
        'mode': 'AGENT',
        'prompt': '  Work on ST1.\n',
        'now': true,
      });
      expect(answer.container, 'porelo-demo-porelo');
      expect(answer.action, StartAction.create);
    },
  );

  // Harm: a reader starts seeing none of the work it is to read, and searches for it until its time runs out.
  test('Start gets the tasks a reader reads and its key, as the order gives them', () async {
    daemon.description = 'method Start(task: ?string, callerKey: ?string, reads: ?[]string) -> (exitCode: ?int)';
    final asked = <Map<String, dynamic>>[];
    daemon.stream('Start', (parameters) async* {
      asked.add(parameters);
      yield <String, dynamic>{'container': 'porelo-demo-porelo-2', 'exitCode': 0, 'action': 'CREATE'};
    });
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
    await backend.open();

    await backend.startOrdered(
      project: 'demo',
      repository: 'porelo',
      agent: 'claude',
      model: 'opus',
      mode: Mode.agent,
      prompt: 'Read foo-1.',
      callerKey: 'offer-2',
      reads: ['foo-1'],
    );

    expect(asked.single['reads'], ['foo-1']);
    expect(asked.single['callerKey'], 'offer-2');
  });

  // Harm: a refused start reads as a start, or loses the words the machine gave for it.
  test('a refusal comes back with what the machine printed before it', () async {
    daemon.stream('Start', (_) async* {
      yield <String, dynamic>{'line': 'porelo: the task porelo-demo-porelo is already running'};
      yield <String, dynamic>{'container': 'porelo-demo-porelo', 'exitCode': 1, 'action': 'RUNNING'};
    });
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
    await backend.open();

    final answer = await startOrdered(backend);

    expect(answer.action, StartAction.running);
    expect(answer.output, ['porelo: the task porelo-demo-porelo is already running']);
  });

  // Harm: a start with a prompt answers only when its agent's run ends, so the story's next task waits on it, and a
  // task started With you opens its terminal only after the agent has finished.
  test('the start answers once its task stands, while the agent still runs', () async {
    daemon.stream('Start', (parameters) async* {
      yield <String, dynamic>{'line': 'starting'};
      // A prompted start without now lasts the whole run; this run never ends.
      if (parameters['now'] != true) await Completer<void>().future;
      yield <String, dynamic>{'container': 'porelo-demo-porelo', 'exitCode': 0, 'action': 'CREATE'};
    });
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
    await backend.open();

    final answer = await startOrdered(backend).timeout(const Duration(seconds: 5));

    expect(answer.container, 'porelo-demo-porelo');
    expect(answer.action, StartAction.create);
  });

  // Harm: Start gives its final reply only when the agent's run ends, so the planner hears of a builder that works for
  // half an hour only then, and the story's next task waits on it.
  group('a start whose agent runs on answers once its agent runs', () {
    const declares = 'method Start(task: ?string, steps: ?bool) -> (exitCode: ?int)';

    Stream<Map<String, dynamic>> runsOn(Map<String, dynamic> step) async* {
      yield <String, dynamic>{'line': 'starting'};
      yield <String, dynamic>{'step': step};
      // The agent's run goes on; Start's final reply would come only at its end.
      await Completer<void>().future;
    }

    test('with the container the step names', () async {
      daemon.description = declares;
      daemon.stream(
        'Start',
        (_) => runsOn({'step': 'AGENT', 'state': 'STARTED', 'text': 'pi runs', 'container': 'porelo-demo_porelo'}),
        isFinal: _finalReply,
      );
      final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
      await backend.open();

      final answer = await startOrdered(backend).timeout(const Duration(seconds: 5));

      expect((answer.container, answer.exitCode), ('porelo-demo_porelo', 0));
      expect(answer.output, ['starting']);
    });

    test('with the task the machine lists newly for the project and repository, where the step names none', () async {
      daemon.description = declares;
      var listings = 0;
      daemon.method('List', (_) {
        listings++;
        return <String, dynamic>{
          'tasks': [
            {'name': 'porelo-demo_porelo', 'task': 'porelo', 'project': 'demo', 'repository': 'porelo', 'run': 'r1'},
            {'name': 'porelo-other_porelo', 'task': 'porelo', 'project': 'other', 'repository': 'porelo', 'run': 'r9'},
            if (listings > 1)
              {
                'name': 'porelo-demo_porelo-2',
                'task': 'porelo-2',
                'project': 'demo',
                'repository': 'porelo',
                'run': 'r2',
              },
          ],
        };
      });
      daemon.stream(
        'Start',
        (_) => runsOn({'step': 'AGENT', 'state': 'STARTED', 'text': 'pi runs'}),
        isFinal: _finalReply,
      );
      final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
      await backend.open();

      final answer = await startOrdered(backend).timeout(const Duration(seconds: 5));

      expect((answer.container, answer.exitCode), ('porelo-demo_porelo-2', 0));
    });

    // Harm: a start refused before its agent runs is told to the planner as started, with a container the machine
    // lists meanwhile, or loses the words the machine gave for the refusal.
    test('a refusal before the agent runs stays a refusal in the machine\'s words', () async {
      daemon.description = declares;
      var listings = 0;
      daemon.method('List', (_) {
        listings++;
        return <String, dynamic>{
          'tasks': [
            if (listings > 1)
              {'name': 'porelo-demo_porelo', 'task': 'porelo', 'project': 'demo', 'repository': 'porelo', 'run': 'r1'},
          ],
        };
      });
      daemon.stream('Start', (_) async* {
        yield <String, dynamic>{
          'step': {'step': 'WORKSPACE', 'state': 'STARTED', 'text': 'Making the workspace'},
        };
        yield <String, dynamic>{
          'step': {'step': 'CREDENTIALS', 'state': 'FAILED', 'text': 'Reading credentials', 'cause': 'vault locked'},
        };
        yield <String, dynamic>{'line': 'porelo: the vault is locked; unlock it and start again'};
        yield <String, dynamic>{'exitCode': 75};
      }, isFinal: _finalReply);
      final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
      await backend.open();

      final answer = await startOrdered(backend).timeout(const Duration(seconds: 5));

      expect((answer.container, answer.exitCode), (null, 75));
      expect(answer.output, ['porelo: the vault is locked; unlock it and start again']);
    });
  });

  // Harm: a discussion starts as an ordinary task, one repository writable and nothing handed back, or with a
  // repository the order never named.
  test('a discussion asks for every repository read only and for its result file, naming no repository', () async {
    daemon.description = 'method Start(task: ?string, allRepositories: ?bool, result: ?string) -> (exitCode: ?int)';
    final asked = <Map<String, dynamic>>[];
    daemon.stream('Start', (parameters) async* {
      asked.add(parameters);
      yield <String, dynamic>{'container': 'porelo-demo-idea', 'exitCode': 0, 'action': 'CREATE'};
    });
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
    await backend.open();

    final answer = await backend.startDiscussion(
      project: 'demo',
      agent: 'claude',
      model: 'opus',
      mode: Mode.agent,
      prompt: 'Discuss the idea.',
      result: 'idea.json',
    );

    expect(asked.single, <String, dynamic>{
      'project': 'demo',
      'agent': 'claude',
      'model': 'opus',
      'mode': 'AGENT',
      'prompt': 'Discuss the idea.',
      'now': true,
      'allRepositories': true,
      'result': 'idea.json',
    });
    expect(answer.container, 'porelo-demo-idea');
  });

  test('an ended task\'s result is asked of the machine with its content', () async {
    Map<String, dynamic>? asked;
    daemon.method('Result', (parameters) {
      asked = parameters;
      return <String, dynamic>{'name': 'idea.json', 'state': 'handed', 'bytes': 2, 'content': '{}'};
    });
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
    await backend.open();

    final result = await backend.taskResult('porelo-demo-idea');

    expect(asked, <String, dynamic>{'task': 'porelo-demo-idea'});
    expect(result.content, '{}');
  });
}

/// Start's final reply, the one that carries its result; every reply before it goes out as it comes.
bool _finalReply(Map<String, dynamic> reply) => reply.containsKey('exitCode');
