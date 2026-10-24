import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/forge_prompt.dart';
import 'i_look_at_the_forges_repository.dart';

/// Usage: I bind the machine to {'acme/api'}
Future<void> iBindTheMachineTo(WidgetTester tester, String repository) async {
  await chooseTheRepository(tester, repository);
  await fromTheRepositorysMenu(tester, repository, 'bind');
  expect(find.byKey(const Key('binding-dialog')), findsOneWidget);
  await tester.tap(find.byKey(const Key('binding-bind')));
  await World.settle(tester);
  await answerMachineForgePrompt(tester);
}
