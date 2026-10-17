import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I choose the package {'porelo-agent-claude'}
Future<void> iChooseThePackage(WidgetTester tester, String name) => World.tapInView(tester, 'package-$name');
