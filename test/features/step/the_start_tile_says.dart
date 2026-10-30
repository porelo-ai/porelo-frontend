import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the start tile says {'Start work'}
Future<void> theStartTileSays(WidgetTester tester, String words) async {
  await World.tapInView(tester, 'project-menu');
  expect(find.textContaining(words), findsWidgets);
  await tester.tapAt(const Offset(5, 5));
  await World.settle(tester);
}
