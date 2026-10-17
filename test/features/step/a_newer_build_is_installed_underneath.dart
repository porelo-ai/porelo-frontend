import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/newer_version.dart';

import '../support/world.dart';

/// Usage: a newer build is installed underneath
Future<void> aNewerBuildIsInstalledUnderneath(WidgetTester tester) async {
  // What a package upgrade does: the binary is replaced while this one keeps running.
  final binary = File('${Directory.systemTemp.path}/porelo-build-${DateTime.now().microsecondsSinceEpoch}');
  binary.writeAsStringSync('the build that is running');
  addTearDown(() => binary.existsSync() ? binary.deleteSync() : null);

  World.newerVersion = NewerVersion(what: binary)..watch();
  binary.setLastModifiedSync(DateTime.now().add(const Duration(minutes: 1)));
  World.newerVersion.lookNow();
  await World.rebuild(tester);
}
