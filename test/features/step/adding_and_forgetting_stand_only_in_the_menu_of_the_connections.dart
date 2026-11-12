import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/connections_menu.dart';

/// Usage: adding and forgetting stand only in the menu of the connections
Future<void> addingAndForgettingStandOnlyInTheMenuOfTheConnections(WidgetTester tester) async {
  expect(find.byKey(const Key('add-connection')), findsNothing, reason: 'adding stands in the view itself');
  expect(
    find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('forget '),
    ),
    findsNothing,
    reason: 'forgetting stands in the view itself',
  );
  await openTheConnectionsMenu(tester);
  expect(tester.widget<PopupMenuItem<Object?>>(connectionsMenuEntry('add-connection')).enabled, isTrue);
  expect(tester.widget<PopupMenuItem<Object?>>(connectionsMenuEntry('forget ssh://github.com')).enabled, isTrue);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await World.settle(tester);
}
