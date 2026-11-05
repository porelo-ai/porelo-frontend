import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/default_view.dart';

import '../features/support/world.dart';

void main() {
  const asks = FirstStart(outcome: FirstStart.askNew, project: 'x-project', file: 'project: x-project\n', hash: 'h1');

  Future<void> toTheQuestion(WidgetTester tester) async {
    final picker = pickACheckout;
    addTearDown(() => pickACheckout = picker);
    pickACheckout = ({initialDirectory, title}) async => '/home/me/x';
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.backend.theFirstStartSays = asks;
    World.shell.goTo(Section.work);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('new-work')));
    await World.settle(tester);
    final inDefault = find.byKey(const ValueKey<String>('new-work-in default'));
    if (inDefault.evaluate().isNotEmpty) {
      await tester.tap(inDefault);
      await World.settle(tester);
    }
    await tester.tap(find.byKey(const Key('default-checkout')));
    await World.settle(tester);
    expect(find.byKey(const Key('first-start')), findsOneWidget);
  }

  // Harm: the yes was this computer's, and work starts on a machine that holds a project of that name.
  testWidgets('a yes starts on the machine that asked, though another was selected meanwhile', (tester) async {
    await toTheQuestion(tester);
    final asked = World.machines.current;
    expect(asked.isThisComputer, isTrue);
    await World.machines.add(const Machine(name: 'elsewhere', socketPath: '/unused'));
    World.machines.select(World.machines.all.firstWhere((each) => each.name == 'elsewhere'));
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('first-start-yes')));
    await World.settle(tester);
    expect(World.backend.firstStartsConfirmed.single.$2, 'h1');
    expect(World.machines.current, asked);
  });

  // Harm: a checkout that asks nothing starts at once, and what its plugin said of it goes with the dialog.
  testWidgets('a known checkout\'s notes are said where its work starts', (tester) async {
    final picker = pickACheckout;
    addTearDown(() => pickACheckout = picker);
    pickACheckout = ({initialDirectory, title}) async => '/home/me/x';
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.backend.theFirstStartSays = const FirstStart(
      outcome: FirstStart.known,
      project: 'checkout',
      notes: <String>['The lookup did not answer.'],
    );
    World.shell.goTo(Section.work);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('new-work')));
    await World.settle(tester);
    final inDefault = find.byKey(const ValueKey<String>('new-work-in default'));
    if (inDefault.evaluate().isNotEmpty) {
      await tester.tap(inDefault);
      await World.settle(tester);
    }
    await tester.tap(find.byKey(const Key('default-checkout')));
    await World.settle(tester);
    expect(World.fleet.status, contains('The lookup did not answer.'));
  });

  // Harm: the start fails at once, its words replace the plugin's, and the dialog that held them is gone.
  testWidgets('a known checkout\'s notes stay though its start cannot go on', (tester) async {
    final picker = pickACheckout;
    addTearDown(() => pickACheckout = picker);
    pickACheckout = ({initialDirectory, title}) async => '/home/me/x';
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.backend.theFirstStartSays = const FirstStart(
      outcome: FirstStart.known,
      project: 'not-listed',
      notes: <String>['The lookup did not answer.'],
    );
    World.shell.goTo(Section.work);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('new-work')));
    await World.settle(tester);
    final inDefault = find.byKey(const ValueKey<String>('new-work-in default'));
    if (inDefault.evaluate().isNotEmpty) {
      await tester.tap(inDefault);
      await World.settle(tester);
    }
    await tester.tap(find.byKey(const Key('default-checkout')));
    await World.settle(tester);
    expect(World.fleet.status, contains('does not list not-listed'));
    expect(World.fleet.status, contains('The lookup did not answer.'));
  });

  // Harm: the person said yes, the file was written, and the window then did nothing and said nothing.
  testWidgets('a project the machine does not list after a yes is said, not left silent', (tester) async {
    await toTheQuestion(tester);
    await tester.tap(find.byKey(const Key('first-start-yes')));
    await World.settle(tester);
    expect(find.textContaining('does not list x-project'), findsOneWidget);
  });
}
