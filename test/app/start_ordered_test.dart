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
}
