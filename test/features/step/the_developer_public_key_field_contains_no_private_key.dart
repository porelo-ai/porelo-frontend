import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> theDeveloperPublicKeyFieldContainsNoPrivateKey(WidgetTester tester) async {
  expect(tester.widget<TextField>(find.byKey(const Key('developer-public-keys'))).controller!.text, isEmpty);
  expect(find.textContaining('sensitive-fixture'), findsNothing);
  expect(find.byKey(const Key('wizard-start')), findsNothing);
}
