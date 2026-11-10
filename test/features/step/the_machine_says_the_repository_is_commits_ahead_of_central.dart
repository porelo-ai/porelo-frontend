import 'package:flutter_test/flutter_test.dart';

import '../support/repository_said.dart';

/// Usage: the machine says the repository {'payments-api'} is {3} commits ahead of central
Future<void> theMachineSaysTheRepositoryIsCommitsAheadOfCentral(WidgetTester tester, String repository, int commits) =>
    theMachineSaysOfTheRepository(
      tester,
      repository,
      carriedHere: true,
      central: 'ahead',
      ahead: commits,
      aheadMeasured: DateTime.now().toUtc().toIso8601String(),
    );
