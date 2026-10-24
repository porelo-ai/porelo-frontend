@Tags(<String>['linux'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/mock/machine.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

void main() {
  late MockDaemon daemon;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });
  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  // Harm: an older daemon can refuse or misread every start if sent an unknown parameter.
  for (final declaration in <({String? description, bool steps})>[
    (description: null, steps: false),
    (description: 'method Start(task: ?string) -> (steps: ?[]StartStep)', steps: false),
    (description: '# method Start(steps: ?bool)\nmethod Start(task: ?string) -> ()', steps: false),
    (description: 'method Start(task: ?string, footsteps: ?bool) -> ()', steps: false),
    (description: 'method Other(steps: ?bool) -> ()\nmethod Start(task: ?string) -> ()', steps: false),
    (description: 'method Start(options: (steps: ?bool)) -> ()', steps: false),
    (description: 'method Start(\n task: ?string,\n steps: ?bool\n) -> (exitCode: ?int)', steps: true),
  ]) {
    test('Start requests steps only from its declared inputs: ${declaration.description}', () async {
      daemon.description = declaration.description;
      Map<String, dynamic>? asked;
      daemon.stream('Start', (parameters) async* {
        asked = parameters;
        yield <String, dynamic>{'exitCode': 0};
      });
      await (await connect()).start(task: 'work').toList();
      expect(
        asked,
        declaration.steps ? <String, dynamic>{'task': 'work', 'steps': true} : <String, dynamic>{'task': 'work'},
      );
    });
  }

  // Harm: losing the failed dependency leaves a start looking as though it still waits.
  test('the waiting mock start delivers its failed dependency and ends with exit 69', () async {
    final machine = MockMachine(daemon, situation: 'start-waits', pace: Duration.zero);
    addTearDown(machine.close);
    final client = await connect();
    final waiting = Completer<void>();
    final progress = <StartProgress>[];
    final ended = client.start(project: 'checkout', task: 'new-work').forEach((reply) {
      progress.add(reply);
      if (reply.step?.state == 'WAITING') waiting.complete();
    });
    await waiting.future;
    expect(progress.last.step?.waitingOn, "the room's homeserver");
    expect(progress.any((reply) => reply.exitCode != null), isFalse);
    machine.failWaitingStart();
    await ended;
    final steps = progress.map((reply) => reply.step).whereType<StartStep>().toList();
    expect(steps.map((step) => step.step), <String>['SOURCE', 'CHECKS', 'CREDENTIALS', 'CONVERSATION', 'CONVERSATION']);
    expect(steps.map((step) => step.state), <String>['DONE', 'DONE', 'DONE', 'WAITING', 'FAILED']);
    expect(steps[3].waitingOn, "the room's homeserver");
    expect(steps.last.cause, 'Error: I/O error: Resource temporarily unavailable (os error 11)');
    expect(progress.last.exitCode, 69);
  });

  // Harm: dropping a final reply's steps hides the reason a repository refused to start.
  test('final steps and lines reach the backend consumer before the refusal', () async {
    daemon.description = 'method Start(steps: ?bool) -> ()';
    daemon.stream('Start', (_) async* {
      yield <String, dynamic>{
        'exitCode': 64,
        'output': <String>['Nothing was started.'],
        'steps': <Object?>[
          <String, dynamic>{
            'step': 'CHECKS',
            'state': 'FAILED',
            'text': 'Checking the repository',
            'waitingOn': '',
            'cause': 'porelo.yml belongs to the repository.',
          },
        ],
      };
    });
    final backend = PoreloBackend(Backend(socketPath: daemon.socketPath, label: 'mock'));
    await backend.open();
    final events = <StartEvent>[];
    await expectLater(backend.startTask(task: 'work').forEach(events.add), throwsA(isA<OperationFailed>()));
    expect(events.whereType<StartLine>().single.line, 'Nothing was started.');
    expect(events.whereType<StartStep>().single.cause, 'porelo.yml belongs to the repository.');
  });

  // Harm: a new step or state from a newer daemon must not crash a start.
  test('unknown values and extra fields survive the wire without casts', () async {
    daemon.stream('Start', (_) async* {
      yield <String, dynamic>{
        'step': <String, dynamic>{
          'step': 'FUTURE_STEP',
          'state': 'FUTURE_STATE',
          'text': 'Future work',
          'waitingOn': '',
          'cause': '',
          'future': true,
        },
      };
      yield <String, dynamic>{'exitCode': 0};
    });
    final step = (await (await connect()).start().first).step!;
    expect(step.step, 'FUTURE_STEP');
    expect(step.state, 'FUTURE_STATE');
    expect(step.text, 'Future work');
  });

  // Harm: malformed wire fields must not throw a cast error and strand the operation.
  test('every step field is checked before it is read', () {
    for (final field in <String>['step', 'state', 'text', 'waitingOn', 'cause']) {
      final map = <String, dynamic>{
        'step': 'CHECKS',
        'state': 'FAILED',
        'text': 'Checking',
        'waitingOn': '',
        'cause': '',
      };
      map[field] = <int>[1];
      final parsed = StartStep.from(map);
      expect(
        <String, String>{
          'step': parsed.step,
          'state': parsed.state,
          'text': parsed.text,
          'waitingOn': parsed.waitingOn,
          'cause': parsed.cause,
        }[field],
        '',
      );
    }
  });
}
