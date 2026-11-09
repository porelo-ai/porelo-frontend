import 'package:flutter_test/flutter_test.dart';

import '../support/repository_said.dart';

/// Usage: the machine says the repository {'payments-api'} stands {'ahead'} against central with no count
Future<void> theMachineSaysTheRepositoryStandsAgainstCentralWithNoCount(
  WidgetTester tester,
  String repository,
  String central,
) => theMachineSaysOfTheRepository(tester, repository, carriedHere: true, central: central);
