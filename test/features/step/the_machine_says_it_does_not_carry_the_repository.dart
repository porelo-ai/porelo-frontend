import 'package:flutter_test/flutter_test.dart';

import '../support/repository_said.dart';

/// Usage: the machine says it does not carry the repository {'billing'}
Future<void> theMachineSaysItDoesNotCarryTheRepository(WidgetTester tester, String repository) =>
    theMachineSaysOfTheRepository(tester, repository, carriedHere: false);
