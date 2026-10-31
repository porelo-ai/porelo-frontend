import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../support/world.dart';

/// Usage: the machine shown is {'this machine'}
Future<void> theMachineShownIs(WidgetTester tester, String name) async {
  // Read off the screen, not off the model: the criterion is that it is never ambiguous, which is a
  // claim about what can be seen. A machine's page and its project's page name it in the title.
  final section = World.shell.section;
  expect(
    section == Section.machine || section == Section.project,
    isTrue,
    reason: 'nothing on the ${section.label} page names the machine an action acts on',
  );
  final title = tester.widget<Text>(find.byKey(const Key('app-title'))).data ?? '';
  expect(title == name || title.startsWith('$name › '), isTrue, reason: 'the title says $title');
}
