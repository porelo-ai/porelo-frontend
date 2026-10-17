import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the setup script ran with {'porelo-agent-claude'}
Future<void> theSetupScriptRanWith(WidgetTester tester, String name) async {
  expect(World.setup.asRootRan.last, endsWith("\nbash /root/porelo-setup.sh --user agent --with $name\n"));
}
