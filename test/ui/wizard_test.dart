import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/wizard.dart';

import '../features/support/world.dart';

void main() {
  late TextEditingController first;
  late TextEditingController second;
  late ValueNotifier<WizardActionState> action;
  late int starts;

  setUp(() {
    first = TextEditingController();
    second = TextEditingController();
    action = ValueNotifier(WizardActionState.waiting);
    starts = 0;
  });
  tearDown(() {
    first.dispose();
    second.dispose();
    action.dispose();
  });

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await World.settle(tester);
  }

  Future<void> open(WidgetTester tester, {bool goesOn = false}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => Wizard(
                  title: 'An example',
                  action: 'Start the example',
                  changes: Listenable.merge([first, second, action]),
                  steps: [
                    WizardStep(
                      title: 'First',
                      words: 'Give the first value.',
                      panel: (_) => TextField(key: const Key('first'), controller: first),
                      check: () => first.text.isEmpty ? 'Give a first value before going on.' : null,
                      summary: () => [first.text],
                    ),
                    WizardStep(
                      title: 'Second',
                      words: 'Give the second value.',
                      panel: (_) => TextField(key: const Key('second'), controller: second),
                      check: () => second.text.isEmpty ? 'Give a second value before going on.' : null,
                      summary: () => [second.text],
                    ),
                  ],
                  actionSteps: [
                    WizardActionStep(
                      title: 'Working',
                      words: 'Wait for the answer.',
                      panel: (_) => Text('External answer: ${action.value.name}'),
                      run: () async {
                        starts++;
                        action.value = WizardActionState.running;
                      },
                      state: () => action.value,
                      goesOnWhenLeft: goesOn,
                    ),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await World.settle(tester);
  }

  // Harm: incomplete answers can reach an external action that costs money or writes data.
  testWidgets('next refuses an incomplete step and names the reason', (tester) async {
    await open(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
    expect(find.text('Give a first value before going on.'), findsOneWidget);
    await tap(tester, 'wizard-next');
    expect(find.byKey(const Key('first')), findsOneWidget);
    expect(starts, 0);
    await tester.enterText(find.byKey(const Key('first')), 'one');
    await tester.pump();
    await tap(tester, 'wizard-next');
    expect(find.byKey(const Key('second')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
    expect(starts, 0);
  });

  // Harm: a repeated click on Next starts work before the review and explicit start decision.
  testWidgets('a stale next button cannot accept the start decision', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('first')), 'one');
    await tester.pump();
    await tap(tester, 'wizard-next');
    await tester.enterText(find.byKey(const Key('second')), 'two');
    await tester.pump();
    final next = tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed!;
    next();
    next();
    await World.settle(tester);
    expect(starts, 0, reason: 'the review must have its own start decision');
    expect(find.byKey(const Key('wizard-start')), findsOneWidget);
  });

  // Harm: navigating back loses answers that the person already supplied.
  testWidgets('back keeps both steps values', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('first')), 'one');
    await tester.pump();
    await tap(tester, 'wizard-next');
    await tester.enterText(find.byKey(const Key('second')), 'two');
    await tester.pump();
    await tap(tester, 'wizard-back');
    expect(tester.widget<TextField>(find.byKey(const Key('first'))).controller!.text, 'one');
    await tap(tester, 'wizard-next');
    expect(tester.widget<TextField>(find.byKey(const Key('second'))).controller!.text, 'two');
  });

  // Harm: leaving silently discards answers that took work to provide.
  testWidgets('leave asks before dropping supplied values', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('first')), 'keep this');
    await tester.pump();
    await tap(tester, 'wizard-leave');
    expect(find.byKey(const Key('wizard-confirm-leave')), findsOneWidget);
    expect(find.byType(Wizard), findsOneWidget);
    await tap(tester, 'wizard-stay');
    expect(tester.widget<TextField>(find.byKey(const Key('first'))).controller!.text, 'keep this');
    await tap(tester, 'wizard-leave');
    await tap(tester, 'wizard-confirm-leave');
    expect(find.byType(Wizard), findsNothing);
  });

  // Harm: retaining a refusal after correction leaves external work stuck on stale answers.
  testWidgets('returning from a refused action runs it again after correcting an answer', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('first')), 'one');
    await tester.pump();
    await tap(tester, 'wizard-next');
    await tester.enterText(find.byKey(const Key('second')), 'two');
    await tester.pump();
    await tap(tester, 'wizard-next');
    await tap(tester, 'wizard-start');
    expect(starts, 1);
    action.value = WizardActionState.refused;
    await tester.pump();
    expect(find.text('External answer: refused'), findsOneWidget);
    await tap(tester, 'wizard-back');
    await tap(tester, 'wizard-back');
    await tester.enterText(find.byKey(const Key('second')), 'corrected');
    await tester.pump();
    await tap(tester, 'wizard-next');
    expect(find.text('corrected'), findsOneWidget, reason: 'the start decision must review the new answer');
    await tap(tester, 'wizard-start');
    expect(starts, 2);
    expect(second.text, 'corrected');
    expect(find.text('External answer: refused'), findsNothing);
    expect(find.text('External answer: running'), findsOneWidget);
  });

  Future<void> startTheAction(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('first')), 'one');
    await tester.pump();
    await tap(tester, 'wizard-next');
    await tester.enterText(find.byKey(const Key('second')), 'two');
    await tester.pump();
    await tap(tester, 'wizard-next');
    expect(starts, 0);
    await tap(tester, 'wizard-start');
    expect(starts, 1);
  }

  // Harm: a running external action is forgotten while it can still rent or change a machine.
  testWidgets('a running action asks before leave and cannot finish early', (tester) async {
    await open(tester);
    await startTheAction(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
    await tap(tester, 'wizard-leave');
    expect(find.byKey(const Key('wizard-confirm-leave')), findsOneWidget);
    expect(find.text('External answer: running'), findsOneWidget);
    await tap(tester, 'wizard-stay');
    action.value = WizardActionState.waiting;
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
    action.value = WizardActionState.refused;
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
    action.value = WizardActionState.done;
    await tester.pump();
    await tap(tester, 'wizard-next');
    expect(find.byType(Wizard), findsNothing);
  });

  // Harm: Back beside a running action offers a way that means nothing there and races the work, which goes on.
  testWidgets('a running action offers no Back, and Back comes again once it has answered', (tester) async {
    await open(tester);
    await startTheAction(tester);
    expect(find.byKey(const Key('wizard-back')), findsNothing);
    expect(find.byKey(const Key('wizard-leave')), findsOneWidget);
    action.value = WizardActionState.waiting;
    await tester.pump();
    await tap(tester, 'wizard-back');
    await tap(tester, 'wizard-confirm-back');
    expect(find.byKey(const Key('wizard-start')), findsOneWidget);
    await tap(tester, 'wizard-start');
    expect(starts, 1, reason: 'returning to an action still under way must not start it twice');
    action.value = WizardActionState.refused;
    await tester.pump();
    expect(
      find.byKey(const Key('wizard-back')),
      findsOneWidget,
      reason: 'a refused action is corrected on a step before',
    );
  });

  // Harm: a person is warned about the very way the work is meant to go on, and stays to watch a run of minutes.
  testWidgets('an action that goes on by design leaves without asking', (tester) async {
    await open(tester, goesOn: true);
    await startTheAction(tester);
    await tap(tester, 'wizard-leave');
    expect(find.byKey(const Key('wizard-confirm-leave')), findsNothing);
    expect(find.byType(Wizard), findsNothing);
  });
}
