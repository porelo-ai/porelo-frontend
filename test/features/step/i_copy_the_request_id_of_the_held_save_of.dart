import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/held_saves.dart';
import '../support/world.dart';

/// Usage: I copy the request id of the held save of {'cart-move'}
Future<void> iCopyTheRequestIdOfTheHeldSaveOf(WidgetTester tester, String story) async {
  World.watchTheClipboard(tester);
  final copy = find.byKey(Key('held-save-copy-request ${heldSaveId(story)}'));
  await tester.ensureVisible(copy);
  await tester.pump();
  await tester.tap(copy);
  await World.settle(tester);
}
