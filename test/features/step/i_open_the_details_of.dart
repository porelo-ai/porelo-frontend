import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: I open the details of {'this machine'}
Future<void> iOpenTheDetailsOf(WidgetTester tester, String machine) async {
  await toTheMachinesPage(tester, machine);
}
