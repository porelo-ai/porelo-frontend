import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the page offers no {'Bring it to central…'}
Future<void> thePageOffersNo(WidgetTester tester, String label) async {
  expect(
    find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((each) => each is ButtonStyleButton)),
    findsNothing,
  );
}
