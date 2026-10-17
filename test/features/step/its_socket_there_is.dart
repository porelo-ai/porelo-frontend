import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: its socket there is {'/run/user/1001/porelo/porelod.sock'}
Future<void> itsSocketThereIs(WidgetTester tester, String socket) async {
  await World.onTheWizardsSecondPage(tester);
  await tester.enterText(find.byKey(const Key('machine-remote-socket')), socket);
  await World.settle(tester);
}
