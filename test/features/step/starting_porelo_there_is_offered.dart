import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: starting Porelo there is offered
Future<void> startingPoreloThereIsOffered(WidgetTester tester) async {
  expect(find.byKey(const Key('offer-to-start')), findsOneWidget);
}
