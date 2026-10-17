import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: {'porelo-checkout-shell'} has a message the filter could not check
Future<void> hasAMessageTheFilterCouldNotCheck(WidgetTester tester, String task) async {
  World.holdAMessage(task: task, peer: 'partner', text: '', standing: 'unchecked', reason: 'not UTF-8');
}
