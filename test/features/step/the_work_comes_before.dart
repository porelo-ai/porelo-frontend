import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the work {'porelo-billing-shell'} comes before {'porelo-checkout-shell'}
Future<void> theWorkComesBefore(WidgetTester tester, String first, String second) async {
  final a = tester.getTopLeft(tileFor(first));
  final b = tester.getTopLeft(tileFor(second));
  expect(a.dy < b.dy || (a.dy == b.dy && a.dx < b.dx), isTrue, reason: '$first is after $second');
}
