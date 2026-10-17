import 'package:flutter_test/flutter_test.dart';

import 'the_machine_says_needs_a_grant_for_in.dart';

/// Usage: the machine says {'jira'} is granted
Future<void> theMachineSaysIsGranted(WidgetTester tester, String entry) => needing(tester, entry, '', '', 'granted');
