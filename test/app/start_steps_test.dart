import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/operations.dart';
import 'package:porelo_frontend/src/ui/operations.dart';

import '../features/support/world.dart';

void main() {
  const cause = 'Error: I/O error: Resource temporarily unavailable (os error 11)';
  const waiting = StartStep(
    step: 'CONVERSATION',
    state: 'WAITING',
    text: 'Preparing the conversation',
    waitingOn: "the room's homeserver",
    cause: '',
  );
  const failed = StartStep(
    step: 'CONVERSATION',
    state: 'FAILED',
    text: 'Preparing the conversation',
    waitingOn: '',
    cause: cause,
  );

  Future<({FakeBackend backend, Operation operation})> start(WidgetTester tester) async {
    final backend = FakeBackend(<Task>[]);
    final operations = Operations();
    addTearDown(() async {
      operations.dispose();
      await backend.launch.close();
      await backend.stop();
    });
    final operation = operations.run(
      title: 'Start work',
      output: backend.startTask(project: 'checkout', task: 'work'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: operations,
            builder: (context, _) => OperationOutputView(operation: operation, onBack: () {}, onClose: () {}),
          ),
        ),
      ),
    );
    return (backend: backend, operation: operation);
  }

  // Harm: a start waiting on a failed service must not read as still running or waiting.
  testWidgets('a failed dependency replaces its waiting step and settles the operation', (tester) async {
    final (:backend, :operation) = await start(tester);
    backend.launch.add(waiting);
    await tester.pump();
    expect(find.text("waits on the room's homeserver"), findsOneWidget);
    backend.launch.add(failed);
    backend.launch.addError(const OperationFailed(69));
    await tester.pump();
    expect(find.text(failed.text), findsOneWidget);
    expect(find.text(cause), findsOneWidget);
    expect(find.text("waits on the room's homeserver"), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(operation.running, isFalse);
    expect(operation.failed, isTrue);
    expect(operation.steps.values.single.state, 'FAILED');
  });

  // Harm: saying a refusal twice can replace its real cause with an incorrect explanation.
  for (final withSteps in <bool>[false, true]) {
    testWidgets('the old 69 sentence is shown only without steps: $withSteps', (tester) async {
      final (:backend, :operation) = await start(tester);
      backend.launch.add('the original details');
      if (withSteps) backend.launch.add(failed);
      backend.launch.addError(const OperationFailed(69));
      await tester.pump();
      expect(find.text(const OperationFailed(69).toString()), withSteps ? findsNothing : findsOneWidget);
      expect(find.text('the original details'), findsOneWidget);
      expect(operation.failed, isTrue);
    });
  }

  // Harm: a newer daemon adding steps or states must not break the view.
  testWidgets('unknown step and state remain visible without throwing', (tester) async {
    final (:backend, :operation) = await start(tester);
    backend.launch.add(
      const StartStep(step: 'FUTURE_STEP', state: 'FUTURE_STATE', text: 'Future work', waitingOn: '', cause: ''),
    );
    await tester.pump();
    expect(find.text('Future work'), findsOneWidget);
    expect(find.text('FUTURE_STEP'), findsOneWidget);
    expect(find.text('FUTURE_STATE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(operation.running, isTrue);
  });

  // Harm: interleaved step updates must not leave an older waiting state beside a failed step.
  testWidgets('each step keeps its latest state in first arrival order', (tester) async {
    final (:backend, :operation) = await start(tester);
    backend.launch.add(waiting);
    backend.launch.add(
      const StartStep(step: 'IMAGE', state: 'STARTED', text: 'Building the image', waitingOn: '', cause: ''),
    );
    backend.launch.add(failed);
    await tester.pump();
    expect(operation.steps.keys, <String>['CONVERSATION', 'IMAGE']);
    expect(find.text('Preparing the conversation'), findsOneWidget);
    expect(find.text(cause), findsOneWidget);
    expect(find.text("waits on the room's homeserver"), findsNothing);
  });

  // Harm: reopening a failed operation must not lose its dependency's cause.
  test('the saved operation retains step order and the failed dependency', () {
    final operation = Operation(id: 'start', title: 'Start work', startedAt: DateTime.fromMillisecondsSinceEpoch(0))
      ..state = OperationState.failed
      ..summary = ''
      ..steps['SOURCE'] = const StartStep(
        step: 'SOURCE',
        state: 'DONE',
        text: 'Reading the source',
        waitingOn: '',
        cause: '',
      )
      ..steps['CONVERSATION'] = failed;
    final reopened = Operation.fromStored(operation.toStored(Operations.linesKept))!;
    expect(reopened.failed, isTrue);
    expect(reopened.steps.keys, <String>['SOURCE', 'CONVERSATION']);
    expect(reopened.steps['CONVERSATION']?.cause, cause);
    expect(reopened.steps['CONVERSATION']?.state, 'FAILED');
    expect(reopened.summary, isEmpty);
  });
}
