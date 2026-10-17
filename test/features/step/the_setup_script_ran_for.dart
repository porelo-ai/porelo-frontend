import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the setup script ran for {'agent'}
Future<void> theSetupScriptRanFor(WidgetTester tester, String user) async {
  expect(World.setup.asRootRan.last, contains("\nbash /root/porelo-setup.sh --user $user"));
}
