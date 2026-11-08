import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: nothing reached the machine {'elsewhere'}
Future<void> nothingReachedTheMachine(WidgetTester tester, String name) async {
  expect(name, 'elsewhere');
  expect(World.elsewhere.removals, isEmpty, reason: 'nothing may be removed on the machine chosen meanwhile');
  expect(World.elsewhere.starts, isEmpty, reason: 'nothing may start on the machine chosen meanwhile');
}
