import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I press the start tile
Future<void> iPressTheStartTile(WidgetTester tester) async {
  await World.tapInView(tester, 'project-menu');
  await World.tapInView(tester, 'work.start');
  await World.settle(tester);
}
