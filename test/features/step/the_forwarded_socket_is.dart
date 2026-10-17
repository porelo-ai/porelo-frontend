import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the forwarded socket is {'/tmp/porelod-remote.sock'}
Future<void> theForwardedSocketIs(WidgetTester tester, String socket) async {
  await World.onTheWizardsSecondPage(tester);
  await tester.enterText(find.byKey(const Key('machine-socket')), socket);
  await World.settle(tester);
}
