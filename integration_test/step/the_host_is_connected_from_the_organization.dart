import 'package:flutter_test/flutter_test.dart';

import 'i_connect_the_host_from_the_organization.dart';

/// Usage: the host is connected from the organization
Future<void> theHostIsConnectedFromTheOrganization(WidgetTester tester) =>
    // A scenario before this one connected it; where it stands connected already, nothing is pressed.
    connectTheHost(tester, alreadyIsAFault: false);
