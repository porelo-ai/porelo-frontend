import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'world.dart';

/// Opens the menu of a machine's connections, where adding and forgetting stand.
Future<void> openTheConnectionsMenu(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('connections-menu')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('connections-menu')));
  await World.settle(tester);
}

/// The entry [id] of the open menu of the connections.
Finder connectionsMenuEntry(String id) =>
    find.byWidgetPredicate((w) => w is PopupMenuItem && w.key == ValueKey<String>(id));
