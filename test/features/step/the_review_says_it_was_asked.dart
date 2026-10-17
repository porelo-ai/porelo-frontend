import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the review says it was asked {'Round money to the nearest penny'}
Future<void> theReviewSaysItWasAsked(WidgetTester tester, String asked) async {
  expect(tester.widget<SelectableText>(find.byKey(const Key('review-asked'))).data, asked);
  // Above what it touched, kept apart from it.
  expect(
    tester.getTopLeft(find.byKey(const Key('review-asked'))).dy,
    lessThan(tester.getTopLeft(find.byKey(const Key('review-not-a-verdict'))).dy),
  );
}
