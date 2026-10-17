import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: starting Porelo will fail with {'no porelod is installed there'}
Future<void> startingPoreloWillFailWith(WidgetTester tester, String words) async {
  World.startFailsWith = words;
}
