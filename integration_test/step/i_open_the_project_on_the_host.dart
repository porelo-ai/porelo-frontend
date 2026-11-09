import 'package:flutter_test/flutter_test.dart';

import '../support/rehearsal.dart';

/// Usage: I open the project on the host
Future<void> iOpenTheProjectOnTheHost(WidgetTester tester) =>
    pictured(tester, () async => toTheProjectOnTheHost(tester));
