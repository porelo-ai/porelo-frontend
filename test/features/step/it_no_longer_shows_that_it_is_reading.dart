import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: it no longer shows that it is reading
Future<void> itNoLongerShowsThatItIsReading(WidgetTester tester) async {
  expect(find.byKey(const Key('reading')), findsNothing);
}
