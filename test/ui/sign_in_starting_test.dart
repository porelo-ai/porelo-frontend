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
}
