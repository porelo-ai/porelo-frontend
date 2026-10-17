import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: nothing porelo doctor found is shown
Future<void> nothingPoreloDoctorFoundIsShown(WidgetTester tester) async {
  expect(find.byKey(const Key('doctor-found')), findsNothing);
  expect(find.byKey(const Key('ask-doctor-again')), findsNothing);
}
