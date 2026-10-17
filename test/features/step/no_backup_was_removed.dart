import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: no backup was removed
///
/// Read off the socket: what makes a preview a preview is that the call carried `dryRun`.
Future<void> noBackupWasRemoved(WidgetTester tester) async {
  expect(
    World.backend.backupDeletions.every((asked) => asked.preview),
    isTrue,
    reason: 'a backup was removed before anybody agreed to it',
  );
}
