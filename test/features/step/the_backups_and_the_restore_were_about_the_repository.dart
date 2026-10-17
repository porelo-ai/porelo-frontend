import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the backups and the restore were about the repository {'payments-api'}
Future<void> theBackupsAndTheRestoreWereAboutTheRepository(WidgetTester tester, String repository) async {
  expect(World.backend.backupsAskedIn, everyElement(repository));
  expect(World.backend.restoredIn, isNotEmpty);
  expect(World.backend.restoredIn, everyElement(repository));
}
