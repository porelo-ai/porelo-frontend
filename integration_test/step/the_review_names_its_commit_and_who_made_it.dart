import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/rehearsal.dart';

/// Usage: the review names its commit and who made it
Future<void> theReviewNamesItsCommitAndWhoMadeIt(WidgetTester tester) => pictured(tester, () async {
  expect(Rehearsal.reviewedCommit, isNotNull);
  final author = find.byKey(const Key('review-fact Author'));
  expect(author, findsOneWidget, reason: 'who made it');
  final said = theWordsUnder(tester, author);
  expect(said, isNot(contains('not reported')), reason: 'the host names its author');
  expect(said, contains('@'), reason: 'an author is a name and an address: $said');
});
