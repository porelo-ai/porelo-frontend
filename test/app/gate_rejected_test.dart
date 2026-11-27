import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/gate.dart';

import '../features/support/world.dart';

/// A push a task rejected is said to have been, and a push that left the list any other way is not.
void main() {
  final project = Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/checkout/project.yml'});

  GateState waitingWith(List<String> names) => GateState.from(<String, dynamic>{
    'mirror': '/srv/checkout/.porelo/mirror',
    'mode': 'gatekeeping',
    'seededFrom': '',
    'pending': <Map<String, dynamic>>[
      for (final name in names)
        <String, dynamic>{
          'name': name,
          'commit': '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d',
          'subject': 'Round to the nearest penny',
          'waiting': '4 minutes',
          'at': '2026-01-02T03:00:00Z',
        },
    ],
  });

  /// A gate that holds [names], read once, and a backend that will hold none of them next.
  Future<(FakeBackend, Gate)> aGateReadOnceWith(List<String> names) async {
    final backend = FakeBackend(<Task>[])..theGate = waitingWith(names);
    final gate = Gate();
    await gate.lookAt(backend, project);
    expect(gate.waiting.map((push) => push.name), names);
    backend.theGate = waitingWith(const <String>[]);
    return (backend, gate);
  }

  // Harm: a person takes a push a task rejected for one that vanished, or for their own refusal.
  test('a push gone from the list that a task rejected is said to be, once, with the task and the time', () async {
    final (backend, gate) = await aGateReadOnceWith(<String>['fix']);
    backend.pushEnds['fix'] = const PushEnd(
      decision: 'REJECTED',
      rejectedBy: 'screener-1',
      decisionSince: '2026-01-02T03:04:05Z',
    );

    await gate.lookAt(backend, project);

    final notice = gate.rejectedByTasks.single;
    expect(notice.task, 'screener-1');
    expect(notice.name, 'fix');
    expect(notice.subject, 'Round to the nearest penny');
    expect(notice.at, '2026-01-02T03:04:05Z');
    expect(backend.pushEndsAsked, <String>['fix']);
    expect(gate.problem, isNull);

    await gate.lookAt(backend, project);

    expect(gate.rejectedByTasks, hasLength(1), reason: 'reading again adds no second notice');
    expect(backend.pushEndsAsked, <String>['fix'], reason: 'the push is no longer in the list it is compared with');
  });

  // Harm: the owner account's own refusal, made elsewhere, is shown as a task's.
  test('a push the owner account rejected leaves no notice', () async {
    final (backend, gate) = await aGateReadOnceWith(<String>['fix']);
    backend.pushEnds['fix'] = const PushEnd(decision: 'REJECTED', decisionSince: '2026-01-02T03:04:05Z');

    await gate.lookAt(backend, project);

    expect(backend.pushEndsAsked, <String>['fix']);
    expect(gate.rejectedByTasks, isEmpty);
    expect(gate.problem, isNull);
  });

  // Harm: a push approved elsewhere, or still open, is called rejected because a name came with the answer.
  test('a task named for a decision that is not a rejection leaves no notice', () async {
    final (backend, gate) = await aGateReadOnceWith(<String>['fix']);
    backend.pushEnds['fix'] = const PushEnd(decision: 'APPROVED', rejectedBy: 'screener-1');

    await gate.lookAt(backend, project);

    expect(gate.rejectedByTasks, isEmpty);
  });

  // Harm: the person's own drop is asked about and shown as if a task had done it.
  test("the person's own drop through the model is not asked about", () async {
    final backend = FakeBackend(<Task>[])..theGate = waitingWith(const <String>['fix']);
    // Were it asked, the answer would blame a task.
    backend.pushEnds['fix'] = const PushEnd(decision: 'REJECTED', rejectedBy: 'screener-1');
    final gate = Gate();
    await gate.lookAt(backend, project);
    await gate.look(backend, gate.waiting.single);

    await gate.reject(backend, reason: 'not now');
    await gate.lookAt(backend, project);

    expect(gate.waiting, isEmpty);
    expect(backend.pushEndsAsked, isEmpty);
    expect(gate.rejectedByTasks, isEmpty);
  });

  // Harm: an extra question that fails hides the list, or says a push was rejected where nothing said so.
  test('a refusal, a machine without the method, or a lost connection leaves no notice and no problem', () async {
    final faults = <Exception>[
      const VarlinkException('org.varlink.service.MethodNotFound'),
      const VarlinkException('org.fuin.porelo.Tasks1.PlaceUnreadable'),
      const VarlinkDisconnected('gone'),
    ];
    for (final fault in faults) {
      final (backend, gate) = await aGateReadOnceWith(<String>['fix', 'other']);
      backend.theGate = waitingWith(<String>['other']);
      backend.refusePushEnd = fault;

      await gate.lookAt(backend, project);

      expect(gate.waiting.map((push) => push.name), <String>['other'], reason: '$fault');
      expect(gate.rejectedByTasks, isEmpty, reason: '$fault');
      expect(gate.problem, isNull, reason: '$fault');
    }
  });

  // Harm: a name the machine chose is shown with control characters, or whole at any length.
  test('the task name is shown as printable ASCII, at most 64 characters', () async {
    final (backend, gate) = await aGateReadOnceWith(<String>['fix']);
    backend.pushEnds['fix'] = PushEnd(decision: 'RETURNED', rejectedBy: 'a\u0007b\nc\u202Ed${'x' * 100}');

    await gate.lookAt(backend, project);

    final task = gate.rejectedByTasks.single.task;
    expect(task, startsWith('abcd'));
    expect(task.length, 64);
    expect(task.codeUnits.every((unit) => unit >= 0x20 && unit <= 0x7e), isTrue);
  });

  test('a time that is no instant is left out, and a notice is dismissed on its own', () async {
    final (backend, gate) = await aGateReadOnceWith(<String>['fix']);
    backend.pushEnds['fix'] = const PushEnd(decision: 'REJECTED', rejectedBy: 'screener-1', decisionSince: 'soon');

    await gate.lookAt(backend, project);

    expect(gate.rejectedByTasks.single.at, isNull);
    gate.dismissRejection(gate.rejectedByTasks.single);
    expect(gate.rejectedByTasks, isEmpty);
  });
}
