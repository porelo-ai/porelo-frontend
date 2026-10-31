import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import 'world.dart';

/// Gives a forge [token] at the local helper's terminal prompt, keeping the fixture value as that
/// helper would.
///
/// A forge is reached by the person's SSH identity by default, so an open form is kept that way
/// first; the token is the forge's explicit alternative, chosen from its menu as a person would.
Future<void> answerForgePrompt(WidgetTester tester, String token) async {
  String? name;
  final form = find.byKey(const Key('forge-name'));
  if (form.evaluate().isNotEmpty) name = tester.widget<TextField>(form).controller?.text.trim();
  if (find.byKey(const Key('forge-connect')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('forge-connect')));
    await World.settle(tester);
  }
  if (find.byKey(const Key('unlock-terminal')).evaluate().isEmpty) await _useATokenInstead(tester, name);
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

/// Chooses *Use a token instead…* from the menu of the forge called [name], or of the only forge
/// shown where no name is known, and connects the form it opens.
Future<void> _useATokenInstead(WidgetTester tester, String? name) async {
  final menus = name == null || name.isEmpty
      ? find.byWidgetPredicate((widget) => '${widget.key}'.startsWith("[<'forges-menu "))
      : find.byKey(ValueKey<String>('forges-menu $name'));
  expect(menus, findsWidgets, reason: 'the menu of the forge ${name ?? ''} to choose a token from');
  await tester.tap(menus.first);
  await World.settle(tester);
  await tester.tap(find.byKey(const ValueKey<String>('forge.useToken')).last);
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('forge-connect')));
  await World.settle(tester);
}

/// Opens the forge's page from the Forges page, as a person does after giving it a token there: the
/// repositories are on the forge's own page.
Future<void> openTheForgeShown(WidgetTester tester) async {
  if (find.byKey(const Key('forges-page')).evaluate().isEmpty) return;
  final rows = find.byWidgetPredicate((widget) => '${widget.key}'.startsWith("[<'forge ") && widget is ListTile);
  if (rows.evaluate().length != 1) return;
  await tester.tap(rows.first);
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
