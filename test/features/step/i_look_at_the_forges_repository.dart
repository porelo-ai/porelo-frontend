import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I look at the forge's repository {'acme/api'}
Future<void> iLookAtTheForgesRepository(WidgetTester tester, String name) async {
  await chooseTheRepository(tester, name);
}

/// The command in a repository's menu that each older choice of its card now is.
const Map<String, String> _commandFor = <String, String>{
  'bind': 'repository.follow',
  'repository-tools': 'repository.tools',
  'open-at-forge': 'repository.open',
  'default-add': 'repository.default',
  'default-remove': 'repository.defaultRemove',
};

/// Chooses [what] (`bind`, `repository-tools`, `open-at-forge`, `default-add`, `default-remove`)
/// from [repository]'s menu on its forge's page.
Future<void> fromTheRepositorysMenu(WidgetTester tester, String repository, String what) async {
  await tester.tap(find.byKey(ValueKey<String>('forge-repository-menu $repository')));
  await World.settle(tester);
  await tester.tap(find.byKey(ValueKey<String>(_commandFor[what] ?? what)).last);
  await World.settle(tester);
}

/// Brings [name]'s row on screen, as a person looks at it: what it holds is said on the row itself,
/// and a click on the row would open it at the forge.
Future<void> chooseTheRepository(WidgetTester tester, String name) async {
  final row = find.byKey(ValueKey<String>('repository $name'));
  expect(row, findsOneWidget, reason: 'the row of $name on its forge page');
  await tester.ensureVisible(row);
  await World.settle(tester);
}
