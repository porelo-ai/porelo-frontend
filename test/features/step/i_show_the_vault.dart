import 'package:flutter_test/flutter_test.dart';

import 'i_choose_the_command.dart';

/// Usage: I show the vault
Future<void> iShowTheVault(WidgetTester tester) => iChooseTheCommand(tester, 'Show the vault');
