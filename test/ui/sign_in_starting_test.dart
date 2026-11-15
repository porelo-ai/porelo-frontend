import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/agent_sign_in.dart';
import 'package:porelo_frontend/src/ui/sign_in_panel.dart';

import '../features/support/world.dart';

/// A sign-in whose start the machine takes long to answer, as the first one on a machine does while it builds its
/// login image.
void main() {
  // Harm: a start that runs for minutes reads as nothing happening, so the person presses again or gives up, and
  // never learns where to look when it does not move.
  testWidgets('a start that is out shows the mark, the time so far as it moves, and where to look after two minutes', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var now = DateTime.utc(2026, 11, 15, 10);
    final machine = FakeBackend(const <Task>[])
      ..signsIn = true
      ..signInStartHeld = Completer<void>();
    final signingIn = SigningIn(clock: () => now)..machine = 'gorge';
    addTearDown(signingIn.dispose);
    signingIn.take(machine, const AgentSignIn(agent: 'claude', state: 'NOT_SIGNED_IN'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SignInPanel(signingIn: signingIn)),
      ),
    );

    unawaited(signingIn.signIn());
    await tester.pump();

    final starting = find.byKey(const Key('start-sign-in-starting'));
    expect(find.descendant(of: starting, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(find.textContaining('gorge is preparing the sign-in to claude'), findsOneWidget);
    expect(find.text('0 s so far.'), findsOneWidget);

    now = now.add(const Duration(minutes: 1, seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1 min 5 s so far.'), findsOneWidget, reason: 'the time moves without anything else changing');
    expect(find.byKey(const Key('start-sign-in-look-further')), findsNothing);

    now = now.add(const Duration(seconds: 55));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2 min 0 s so far.'), findsOneWidget);
    expect(find.text("If this does not move, gorge's log says why."), findsOneWidget);

    machine.signInStartHeld!.complete();
    await tester.pump();
    await tester.pump();
    expect(starting, findsNothing, reason: 'answered, the start is no longer shown as running');
  });

  // Harm: a refused start still reads as running, its time going on, so the person waits for nothing.
  testWidgets('a refused start shows its refusal and no time', (tester) async {
    final (:machine, :signingIn) = await _shown(tester);
    machine.signInRefusedAs = 'ALREADY_SIGNED_IN';

    unawaited(signingIn.signIn());
    await tester.pump();
    expect(find.text('0 s so far.'), findsOneWidget);
    machine.signInStartHeld!.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('start-sign-in-starting')), findsNothing);
    expect(find.textContaining('so far'), findsNothing);
    expect(find.textContaining('holds a sign-in'), findsWidgets, reason: 'the refusal is said instead');
  });

  // Harm: a panel closed while its start is out keeps a timer ticking for a view nobody has open.
  testWidgets('a panel closed while its start is out stops ticking', (tester) async {
    final (:machine, :signingIn) = await _shown(tester);
    unawaited(signingIn.signIn());
    await tester.pump();
    expect(find.byKey(const Key('start-sign-in-starting')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    // A timer still pending fails the test once its body ends.
    expect(signingIn.starting, isTrue, reason: 'only the panel went; the start is still out');
  });
}

/// A panel on a machine whose sign-in start is held until the test answers it.
Future<({FakeBackend machine, SigningIn signingIn})> _shown(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1280, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final machine = FakeBackend(const <Task>[])
    ..signsIn = true
    ..signInStartHeld = Completer<void>();
  final signingIn = SigningIn(clock: () => DateTime.utc(2026, 11, 15, 10))..machine = 'gorge';
  addTearDown(signingIn.dispose);
  signingIn.take(machine, const AgentSignIn(agent: 'claude', state: 'NOT_SIGNED_IN'));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SignInPanel(signingIn: signingIn)),
    ),
  );
  return (machine: machine, signingIn: signingIn);
}
