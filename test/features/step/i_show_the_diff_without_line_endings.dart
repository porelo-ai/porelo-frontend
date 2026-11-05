import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I show the diff without line endings
Future<void> iShowTheDiffWithoutLineEndings(WidgetTester tester) async {
  final box = find.byKey(const Key('review-without-line-endings'));
  await tester.ensureVisible(box);
  await World.settle(tester);
  await tester.tap(box);
  await World.settle(tester);
}
