import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/connections_menu.dart';

/// Usage: I add a connection to {'https://gitlab.example/acme/'}
Future<void> iAddAConnectionTo(WidgetTester tester, String match) async {
  await openTheConnectionsMenu(tester);
  await tester.tap(connectionsMenuEntry('add-connection'));
  await World.settle(tester);
  await tester.enterText(find.byKey(const Key('connection-match')), match);
  await World.settle(tester);
}
