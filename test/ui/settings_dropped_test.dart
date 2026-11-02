import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart';

void main() {
  // Harm: a person's machines are gone and nobody tells them why.
  testWidgets('a start that dropped the saved settings says so in one sentence', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, settingsDropped: true);
    await World.settle(tester);
    expect(find.byKey(const Key('settings-dropped')), findsOneWidget);
    expect(find.text(settingsDroppedWords), findsOneWidget);
  });

  // Harm: the sentence greets every start.
  testWidgets('any other start says nothing of it', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.settle(tester);
    expect(find.byKey(const Key('settings-dropped')), findsNothing);
  });
}
