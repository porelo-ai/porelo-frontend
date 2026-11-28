import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';
import '../support/world.dart';

/// Usage: I open the issue of the held save of {'cart-move'}
///
/// Taps the issue named in the held save's card, which is a link where the board gives that issue a page.
Future<void> iOpenTheIssueOfTheHeldSaveOf(WidgetTester tester, String story) async {
  final issue = find.byKey(Key('held-save-issue ${heldSaveId(story)}'));
  await tester.ensureVisible(issue);
  await tester.pump();
  await tester.tap(issue);
  await World.settle(tester);
}
