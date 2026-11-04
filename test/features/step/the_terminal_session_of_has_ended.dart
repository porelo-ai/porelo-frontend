import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the terminal session of {'porelo-billing-shell'} has ended
Future<void> theTerminalSessionOfHasEnded(WidgetTester tester, String work) async {
  World.backend.screens[work] = const Screen(lines: <String>[], live: false);
}
