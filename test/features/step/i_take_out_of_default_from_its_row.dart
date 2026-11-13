import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I take {'foo-2'} out of default from its row
Future<void> iTakeOutOfDefaultFromItsRow(WidgetTester tester, String repository) =>
    World.fromARepositorysMenu(tester, repository, 'take-out');
