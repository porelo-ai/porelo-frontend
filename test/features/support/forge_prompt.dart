import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import 'world.dart';

/// Answers the local helper's prompt, keeping the fixture value as that helper would.
Future<void> answerForgePrompt(WidgetTester tester, String token) async {
  await tester.tap(find.byKey(const Key('forge-connect')));
  await World.settle(tester);
  expect(find.byKey(const Key('unlock-terminal')), findsOneWidget);
  final terminal = World.terminals.last;
  expect(terminal.command.skip(1).take(2), ['key', 'set']);
  terminal.send('$token\n');
  await World.forgeTokens.write(terminal.command.last, token);
  terminal.endsWith(0);
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('unlock-done')));
  await World.settle(tester);
}

/// Answers Porelo's own prompt on the machine, which lists only the resulting entry's name.
Future<void> answerMachineForgePrompt(WidgetTester tester) async {
  if (find.byKey(const Key('unlock-terminal')).evaluate().isEmpty) return;
  final terminal = World.terminals.last;
  terminal.send('machine-token\n');
  final before = World.backend.theStoreIs;
  World.backend.theStoreIs = VaultState(
    vault: before.vault,
    exists: true,
    readable: true,
    credentials: [
      ...before.credentials,
      const Credential(name: 'git.token.github.com', type: 'token', characters: 13),
    ],
  );
  terminal.endsWith(0);
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('unlock-done')));
  await World.settle(tester);
}
