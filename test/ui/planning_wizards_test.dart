import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/planning_wizards.dart';
import 'package:porelo_planning/porelo_planning.dart' show PlanningWizardStep;

import '../features/support/world.dart';

void main() {
  // Harm: Start work drawn in a frame of its own reads and behaves unlike every other wizard of the window, and a
  // start that answered is not told back to the screen.
  testWidgets("the screen's steps run in the window's wizard, and its start answers whether it started", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final machine = ValueNotifier<String>('');
    addTearDown(machine.dispose);
    var starts = 0;
    bool? started;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => started = await const WindowPlanningWizards().show(
                context,
                title: 'Start work',
                steps: [
                  PlanningWizardStep(
                    title: 'Where',
                    words: 'Choose the machine.',
                    panel: (_) => TextButton(
                      key: const Key('choose-machine'),
                      onPressed: () => machine.value = 'build-machine',
                      child: const Text('build-machine'),
                    ),
                    check: () => machine.value.isEmpty ? 'Choose a machine before going on.' : null,
                    summary: () => ['On ${machine.value}'],
                  ),
                  PlanningWizardStep(
                    title: 'How',
                    panel: (_) => const Text('Unattended'),
                    check: () => null,
                    summary: () => ['Unattended'],
                    shown: () => false,
                  ),
                ],
                changes: machine,
                startLabel: 'Start',
                start: () async {
                  starts++;
                  return true;
                },
                canCancel: () => true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await World.settle(tester);

    expect(find.text('Choose a machine before going on.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('choose-machine')));
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('wizard-next')));
    await World.settle(tester);
    // How has nothing to choose: the review follows, its line kept, Change only beside Where.
    expect(find.text('On build-machine'), findsOneWidget);
    expect(find.text('Unattended'), findsOneWidget);
    expect(find.byKey(const Key('wizard-change-0')), findsOneWidget);
    expect(find.byKey(const Key('wizard-change-1')), findsNothing);
    await tester.tap(find.byKey(const Key('wizard-start')));
    await World.settle(tester);
    expect(starts, 1);
    expect(started, isTrue);
    expect(find.text('Start work'), findsNothing);
  });
}
