// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// The parts of a start, as a machine's Start declares them.
const _parts =
    'place: ?Place, rights: ?[]Right, readLanded: ?[]string, writeAs: ?(author, review), projectServices: ?bool, '
    'noGate: ?bool';

/// Own work with the project's services, as an order for a builder names it.
const _own = StartParts(rights: ['push', 'reply'], projectServices: true);

/// A planned stage: one repository read only, a result handed back.
const _stage = StartParts(rights: ['report'], projectServices: true, readOnly: true);

/// A task a planner ordered, started with exactly the arguments the order gives.
void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
    daemon.description = 'method Start(task: ?string, $_parts) -> (exitCode: ?int)';
  });

  tearDown(() => daemon.stop());

  Future<StartProgress> startOrdered(PoreloBackend backend, {String? callerKey}) => backend.startOrdered(
    project: 'demo',
    repository: 'porelo',
    agent: 'claude',
    model: 'opus',
    mode: Mode.agent,
    prompt: '  Work on ST1.\n',
    parts: _own,
    callerKey: callerKey,
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
        'rights': ['push', 'reply'],
        'projectServices': true,
      });
      expect(answer.container, 'porelo-demo-porelo');
      expect(answer.action, StartAction.create);
    },
  );

  // Harm: a reader starts seeing none of the work it is to read, and searches for it until its time runs out.
  test('Start gets the tasks a reader reads and its key, as the order gives them', () async {
    daemon.description = 'method Start(task: ?string, callerKey: ?string, $_parts) -> (exitCode: ?int)';
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
      parts: StartParts(rights: ['reply', 'report'], projectServices: true, readLanded: ['foo-1']),
      callerKey: 'offer-2',
    );

    expect(asked.single['readLanded'], ['foo-1']);
    expect(asked.single['callerKey'], 'offer-2');
  });

  // Harm: a planned stage starts with its repository writable and a gate, or without the issues its planner gave it,
  // or not handing back its result.
  test('a planned stage asks for its repository read only, its result file and its given files', () async {
    daemon.description =
        'method Start(task: ?string, readOnly: ?bool, result: ?string, given: ?[string]string, $_parts) -> (exitCode: ?int)';
    final asked = <Map<String, dynamic>>[];
    daemon.stream('Start', (parameters) async* {
      asked.add(parameters);
      yield <String, dynamic>{'container': 'porelo-demo-porelo-pi', 'exitCode': 0, 'action': 'CREATE'};
    });
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
    await backend.open();

    await backend.startOrdered(
      project: 'demo',
      repository: 'porelo',
      agent: 'claude',
      model: 'opus',
      mode: Mode.agent,
      prompt: 'Analyse PI68.',
      parts: _stage,
      result: 'analysis.json',
      given: {'PI68.md': '# PI68\n'},
    );

    expect(asked.single['readOnly'], isTrue);
    expect(asked.single['result'], 'analysis.json');
    expect(asked.single['given'], {'PI68.md': '# PI68\n'});
    expect(asked.single.containsKey('allRepositories'), isFalse);
  });

  // Harm: a machine that cannot start a stage read only starts it writable, with a gate, as ordinary work.
  test('a machine that cannot start a stage read only, or give it files, is never asked to start it', () async {
    final asked = <Map<String, dynamic>>[];
    daemon.stream('Start', (parameters) async* {
      asked.add(parameters);
      yield <String, dynamic>{'container': 'porelo-demo-porelo', 'exitCode': 0, 'action': 'CREATE'};
    });
    for (final (description, missing) in [
      ('method Start(task: ?string, result: ?string, given: ?[string]string, $_parts) -> (exitCode: ?int)', 'readOnly'),
      ('method Start(task: ?string, readOnly: ?bool, result: ?string, $_parts) -> (exitCode: ?int)', 'given'),
    ]) {
      daemon.description = description;
      final again = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
      await again.open();
      await expectLater(
        again.startOrdered(
          project: 'demo',
          repository: 'porelo',
          agent: 'claude',
          model: 'opus',
          mode: Mode.agent,
          prompt: 'Analyse PI68.',
          parts: _stage,
          result: 'analysis.json',
          given: {'PI68.md': '# PI68\n'},
        ),
        throwsA(isA<FeatureNotSupported>().having((error) => '$error', 'words', contains(missing))),
      );
    }
    expect(asked, isEmpty);
  });

  // Harm: a stage of a project kept in a tracker starts without knowing which issue and phase it works on.
  test('a planned stage of a tracked project is started with its issue and phase as work', () async {
    daemon.description =
        'method Start(task: ?string, readOnly: ?bool, result: ?string, given: ?[string]string, '
        'work: ?(issue: string, phase: string), $_parts) -> (exitCode: ?int)';
    final asked = <Map<String, dynamic>>[];
    daemon.stream('Start', (parameters) async* {
      asked.add(parameters);
      yield <String, dynamic>{'container': 'porelo-demo-porelo-pi', 'exitCode': 0, 'action': 'CREATE'};
    });
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
    await backend.open();

    await backend.startOrdered(
      project: 'demo',
      repository: 'porelo',
      agent: 'claude',
      model: 'opus',
      mode: Mode.agent,
      prompt: 'Build porelo-frontend#617.',
      parts: _stage,
      result: 'result.json',
      work: (issue: 'porelo-ai/porelo-frontend#617', phase: 'Implementing'),
    );

    expect(asked.single['work'], {'issue': 'porelo-ai/porelo-frontend#617', 'phase': 'Implementing'});
  });

  // Harm: a machine whose Start cannot take a stage's issue starts it anyway, working on nothing it can name.
  test('a machine whose Start takes no work is never asked to start a stage that has one', () async {
    daemon.description =
        'method Start(task: ?string, readOnly: ?bool, result: ?string, given: ?[string]string, $_parts) -> (exitCode: ?int)';
    final asked = <Map<String, dynamic>>[];
    daemon.stream('Start', (parameters) async* {
      asked.add(parameters);
      yield <String, dynamic>{'container': 'porelo-demo-porelo', 'exitCode': 0, 'action': 'CREATE'};
    });
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
    await backend.open();

    await expectLater(
      backend.startOrdered(
        project: 'demo',
        repository: 'porelo',
        agent: 'claude',
        model: 'opus',
        mode: Mode.agent,
        prompt: 'Build porelo-frontend#617.',
        parts: _stage,
        result: 'result.json',
        work: (issue: 'porelo-ai/porelo-frontend#617', phase: 'Implementing'),
      ),
      throwsA(isA<FeatureNotSupported>().having((error) => '$error', 'words', contains('work'))),
    );
    expect(asked, isEmpty);
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
    const declares = 'method Start(task: ?string, steps: ?bool, $_parts) -> (exitCode: ?int)';

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

    // Harm: what the machine says while it prepares is read and dropped, so the person's operation shows nothing and
    // they wait blind or press again.
    test('what Start says on the way reaches the caller as it comes, before the answer', () async {
      daemon.description = declares;
      daemon.stream(
        'Start',
        (_) => runsOn({'step': 'AGENT', 'state': 'STARTED', 'text': 'pi runs', 'container': 'porelo-demo_porelo'}),
        isFinal: _finalReply,
      );
      final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
      await backend.open();
      final told = <StartEvent>[];

      await backend
          .startOrdered(
            project: 'demo',
            repository: 'porelo',
            agent: 'claude',
            model: 'opus',
            mode: Mode.agent,
            prompt: 'Work on ST1.',
            parts: _own,
            onEvent: told.add,
          )
          .timeout(const Duration(seconds: 5));

      expect(told.whereType<StartLine>().map((each) => each.line), ['starting']);
      expect(told.whereType<StartStep>().map((each) => (each.step, each.state)), [('AGENT', 'STARTED')]);
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

    // Harm: two starts of one project at once, and each offer's report goes to the other's task.
    test('of two starts of one project at once, each takes the task its key names', () async {
      daemon.description = declares;
      var listings = 0;
      daemon.method('List', (_) {
        listings++;
        return <String, dynamic>{
          'tasks': [
            {'name': 'porelo-demo_porelo', 'task': 'porelo', 'project': 'demo', 'repository': 'porelo', 'run': 'r1'},
            if (listings > 1) ...[
              {
                'name': 'porelo-demo_porelo-2',
                'task': 'porelo-2',
                'project': 'demo',
                'repository': 'porelo',
                'run': 'r2',
                'callerKey': 'offer-of-the-other-start',
              },
              {
                'name': 'porelo-demo_porelo-3',
                'task': 'porelo-3',
                'project': 'demo',
                'repository': 'porelo',
                'run': 'r3',
                'callerKey': 'offer-of-this-start',
              },
            ],
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

      final answer = await startOrdered(backend, callerKey: 'offer-of-this-start').timeout(const Duration(seconds: 5));

      expect((answer.container, answer.exitCode), ('porelo-demo_porelo-3', 0));
    });

    // Harm: a machine that lists no key leaves the start waiting for the agent's whole run, so the story's next task
    // waits on it.
    test('with the one newly listed task where the machine lists no keys, though the start gave one', () async {
      daemon.description = declares;
      var listings = 0;
      daemon.method('List', (_) {
        listings++;
        return <String, dynamic>{
          'tasks': [
            {'name': 'porelo-demo_porelo', 'task': 'porelo', 'project': 'demo', 'repository': 'porelo', 'run': 'r1'},
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

      final answer = await startOrdered(backend, callerKey: 'offer-of-this-start').timeout(const Duration(seconds: 5));

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
    daemon.description =
        'method Start(task: ?string, allRepositories: ?bool, result: ?string, $_parts) -> (exitCode: ?int)';
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
      parts: StartParts(rights: [], projectServices: false, allRepositories: true),
    );

    expect(asked.single, <String, dynamic>{
      'project': 'demo',
      'agent': 'claude',
      'model': 'opus',
      'mode': 'AGENT',
      'prompt': 'Discuss the idea.',
      'now': true,
      'allRepositories': true,
      'rights': <String>[],
      'projectServices': false,
    });
    expect(answer.container, 'porelo-demo-idea');
  });

  // Harm: a task reading another task's work reaches the machine holding the right to push or the project's
  // services, or with its rights left to the machine's default set.
  group('a planned start hands Start the parts its order names, unchanged', () {
    Future<List<Map<String, dynamic>>> asking(StartParts parts, {String? description}) async {
      if (description != null) daemon.description = description;
      final asked = <Map<String, dynamic>>[];
      daemon.stream('Start', (parameters) async* {
        asked.add(parameters);
        yield <String, dynamic>{'container': 'porelo-demo-screener-1', 'exitCode': 0, 'action': 'CREATE'};
      });
      final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
      await backend.open();
      await backend.startOrdered(
        project: 'demo',
        repository: 'porelo',
        agent: 'claude',
        model: 'opus',
        mode: Mode.agent,
        prompt: 'Read the push fix.',
        parts: parts,
      );
      return asked;
    }

    test("a screener's start carries its place and exactly its rights, no account and no services", () async {
      final asked = await asking(
        StartParts(
          rights: ['reply', 'openThreads', 'reject'],
          projectServices: false,
          place: {
            'gatePush': {'name': 'fix'},
          },
        ),
      );

      expect(asked.single['place'], {
        'gatePush': {'name': 'fix'},
      });
      expect(asked.single['rights'], ['reply', 'openThreads', 'reject']);
      expect(asked.single['projectServices'], isFalse);
      expect(asked.single.containsKey('writeAs'), isFalse);
      for (final kind in const ['readOnly', 'allRepositories', 'noGate']) {
        expect(asked.single.containsKey(kind), isFalse, reason: 'no kind of workspace the order did not name: $kind');
      }
    });

    test('an order naming no right reaches Start as an empty list, never left out', () async {
      final asked = await asking(const StartParts(rights: [], projectServices: false, noGate: true));

      expect(asked.single.containsKey('rights'), isTrue, reason: 'left out, the machine gives its default set');
      expect(asked.single['rights'], isEmpty);
      expect(asked.single['noGate'], isTrue);
    });

    test('a reviewer at a pull request is started with the account its order names', () async {
      final asked = await asking(
        StartParts(
          rights: ['reply', 'openThreads'],
          projectServices: false,
          place: {'pullRequest': 'https://git.example.org/acme/api/pull/12'},
          writeAs: 'review',
        ),
      );

      expect(asked.single['place'], {'pullRequest': 'https://git.example.org/acme/api/pull/12'});
      expect(asked.single['writeAs'], 'review');
    });

    test('a machine whose Start lacks one part the order names is never asked to start it', () async {
      const declared = <String, String>{
        'rights': 'rights: ?[]Right',
        'noGate': 'noGate: ?bool',
        'place': 'place: ?Place',
        'readLanded': 'readLanded: ?[]string',
        'writeAs': 'writeAs: ?(author, review)',
        'projectServices': 'projectServices: ?bool',
      };
      for (final missing in declared.keys) {
        final others = [
          for (final MapEntry(key: part, value: declares) in declared.entries)
            if (part != missing) declares,
        ];
        final description = 'method Start(task: ?string, ${others.join(', ')}) -> ()';
        final asked = <Map<String, dynamic>>[];
        daemon
          ..description = description
          ..stream('Start', (parameters) async* {
            asked.add(parameters);
            yield <String, dynamic>{'container': 'porelo-demo-porelo', 'exitCode': 0, 'action': 'CREATE'};
          });
        final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'), asksToCertify: false);
        await backend.open();
        await expectLater(
          backend.startOrdered(
            project: 'demo',
            repository: 'porelo',
            agent: 'claude',
            model: 'opus',
            mode: Mode.agent,
            prompt: 'Read the push fix.',
            // Every part an order can name, so each one the machine lacks is met.
            parts: const StartParts(
              rights: ['reply'],
              projectServices: false,
              noGate: true,
              readLanded: ['mend'],
              writeAs: 'review',
              place: {'pullRequest': 'https://git.example.org/acme/api/pull/12'},
            ),
          ),
          throwsA(isA<FeatureNotSupported>().having((error) => '$error', 'words', contains('Start($missing)'))),
        );
        expect(asked, isEmpty, reason: 'without $missing');
      }
    });
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
