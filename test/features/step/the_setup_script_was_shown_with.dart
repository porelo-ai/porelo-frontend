import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the setup script was shown with {'porelo-agent-claude'}
Future<void> theSetupScriptWasShownWith(WidgetTester tester, String name) async {
  final shown = World.setup.asRootRan.lastWhere((script) => script.contains('--show'));
  expect(shown, contains("--with $name --show"));
}
