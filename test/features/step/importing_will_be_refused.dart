import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: importing will be refused
Future<void> importingWillBeRefused(WidgetTester tester) async {
  World.backend.importRefused = true;
}
