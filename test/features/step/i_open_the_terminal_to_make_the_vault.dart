import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I open the terminal to make the vault
Future<void> iOpenTheTerminalToMakeTheVault(WidgetTester tester) => World.tapInView(tester, 'open-vault-terminal');
