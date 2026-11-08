import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

import '../support/world.dart';

/// Usage: the first task on {'tools'} in default asks before it starts
///
/// The machine proposes settings for the repository, shown before its first task, on every machine watched.
Future<void> theFirstTaskOnInDefaultAsksBeforeItStarts(WidgetTester tester, String repository) async {
  const asks = FirstStart(
    outcome: FirstStart.askNew,
    hosts: <String>['repo.example.org'],
    file: 'egress:\n  domains: [repo.example.org]\n',
    fileName: '.porelo.yml (this machine)',
    project: defaultProject,
    hash: 'h1',
  );
  World.backend.theFirstStartOfSays[repository] = asks;
  World.elsewhere.theFirstStartOfSays[repository] = asks;
}
