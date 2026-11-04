import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the list of work shows {'porelo-billing-shell'}
Future<void> theListOfWorkShows(WidgetTester tester, String work) async {
  expect(tileFor(work), findsOneWidget);
}
