import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/connections_menu.dart';

/// Usage: adding a connection is offered
Future<void> addingAConnectionIsOffered(WidgetTester tester) async {
  await openTheConnectionsMenu(tester);
  expect(tester.widget<PopupMenuItem<Object?>>(connectionsMenuEntry('add-connection')).enabled, isTrue);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await World.settle(tester);
}
