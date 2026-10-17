import 'package:flutter_test/flutter_test.dart';

import 'the_machine_says_needs_a_grant_for_in.dart';

/// Usage: the machine says {'jira'} needs granting again for {'porelo-checkout-shell'} in {'checkout'}
Future<void> theMachineSaysNeedsGrantingAgainForIn(WidgetTester tester, String entry, String task, String project) =>
    needing(tester, entry, task, project, 'ended');
