import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: restoring from the missing backup is not offered
///
/// The record is listed because the backup was taken. There is nothing to restore *from*, and
/// offering it would say the record is the thing when it is not.
Future<void> restoringFromTheMissingBackupIsNotOffered(WidgetTester tester) async {
  final buttons = tester.widgetList<IconButton>(find.byKey(const Key('consider-restoring'))).toList();

  expect(buttons, hasLength(2), reason: 'both backups should be listed');
  expect(buttons.first.onPressed, isNotNull, reason: 'the bundle that is there');
  expect(buttons.last.onPressed, isNull, reason: 'the bundle somebody moved');
}
