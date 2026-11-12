import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../support/connections_menu.dart';

/// Usage: I forget the connection {'ssh://github.com'}
Future<void> iForgetTheConnection(WidgetTester tester, String match) async {
  await openTheConnectionsMenu(tester);
  await tester.tap(connectionsMenuEntry('forget $match'));
  await World.settle(tester);
}
