import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the list of work counts {4}
Future<void> theListOfWorkCounts(WidgetTester tester, int count) async {
  expect(find.text('All work'), findsOneWidget);
  expect(workRows(), findsNWidgets(count));
}
