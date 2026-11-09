import 'package:flutter_test/flutter_test.dart';

import '../support/repository_said.dart';

/// Usage: the machine says it carries the repository {'payments-api'}
Future<void> theMachineSaysItCarriesTheRepository(WidgetTester tester, String repository) =>
    theMachineSaysOfTheRepository(tester, repository, carriedHere: true);
