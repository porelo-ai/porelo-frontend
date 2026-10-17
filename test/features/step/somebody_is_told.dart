import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: somebody is told {'is asking to reach api.example.test:443'}
Future<void> somebodyIsTold(WidgetTester tester, String words) async {
  final said = World.notifier.raised.map((each) => '${each.title} ${each.body}').join('\n');
  expect(said, contains(words));
}
