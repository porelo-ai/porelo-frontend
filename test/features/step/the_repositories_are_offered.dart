import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the repositories are offered
Future<void> theRepositoriesAreOffered(WidgetTester tester) async {
  // A page now, no longer a dialog (walk 10): the forge's repositories, or with no forge
  // set up yet, the Forges page with a forge being added.
  expect(
    find.byKey(const Key('forge-page')).evaluate().isNotEmpty ||
        find.byKey(const Key('forge-form-dialog')).evaluate().isNotEmpty,
    isTrue,
  );
}
