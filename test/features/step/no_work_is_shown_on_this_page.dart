import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: no work is shown on this page
Future<void> noWorkIsShownOnThisPage(WidgetTester tester) async {
  // A machine's or a project's own page, drawn with its menu: a page that is not there shows no work
  // either, which would pass this for the wrong reason.
  expect(
    find.byKey(const Key('machine-menu')).evaluate().isNotEmpty ||
        find.byKey(const Key('project-menu')).evaluate().isNotEmpty,
    isTrue,
    reason: 'neither a machine nor a project page is shown',
  );
  expect(workRows(), findsNothing);
}
