import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/gate.dart';
import 'package:porelo_frontend/src/ui/gate_view.dart';

import '../features/support/world.dart';

/// The gate view says a task rejected a push, in one line the person can dismiss.
void main() {
  final project = Project.from(const <String, dynamic>{'name': 'checkout', 'file': '/srv/checkout/project.yml'});

  Future<Gate> aGateWhereATaskRejected(PushEnd end) async {
    final backend = FakeBackend(<Task>[])
      ..theGate = GateState.from(const <String, dynamic>{
        'mode': 'gatekeeping',
        'pending': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'fix',
            'commit': '9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d',
            'subject': 'Round to the nearest penny',
            'waiting': '4 minutes',
            'at': '2026-01-02T03:00:00Z',
          },
        ],
      });
    final gate = Gate();
    await gate.lookAt(backend, project);
    backend
      ..theGate = GateState.from(const <String, dynamic>{'mode': 'gatekeeping', 'pending': <Object>[]})
      ..pushEnds['fix'] = end;
    await gate.lookAt(backend, project);
    return gate;
  }

  Future<void> show(WidgetTester tester, Gate gate, {double width = 1280}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // As the window does: the view is drawn again whenever the gate says something changed.
          body: ListenableBuilder(
            listenable: gate,
            builder: (_, _) => GateView(gate: gate, focusNode: FocusNode(), onOpen: (_) {}, onClose: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String clock(String instant) {
    final local = DateTime.parse(instant).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} at ${two(local.hour)}:${two(local.minute)}';
  }

  // Harm: a push a task rejected is taken for one that vanished, or for the person's own refusal.
  testWidgets('the line names the task, the push and the time, and goes when dismissed', (tester) async {
    final gate = await aGateWhereATaskRejected(
      const PushEnd(decision: 'REJECTED', rejectedBy: 'screener-1', decisionSince: '2026-01-02T03:04:05Z'),
    );
    await show(tester, gate);

    final words = 'The task screener-1 rejected Round to the nearest penny (fix) on ${clock('2026-01-02T03:04:05Z')}.';
    expect(find.text(words), findsOneWidget);

    await tester.tap(find.byKey(const Key('gate-rejected-dismiss-fix')));
    await tester.pump();

    expect(find.text(words), findsNothing);
    expect(gate.rejectedByTasks, isEmpty);
  });

  testWidgets('without a time the line has none, and a long name is shown whole at a narrow width', (tester) async {
    final task = 'screener-${'x' * 40}';
    final gate = await aGateWhereATaskRejected(PushEnd(decision: 'REJECTED', rejectedBy: task));
    await show(tester, gate, width: 360);

    expect(find.text('The task $task rejected Round to the nearest penny (fix).'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no line is drawn where the owner account rejected', (tester) async {
    final gate = await aGateWhereATaskRejected(const PushEnd(decision: 'REJECTED'));
    await show(tester, gate);

    expect(find.textContaining('The task '), findsNothing);
  });
}
