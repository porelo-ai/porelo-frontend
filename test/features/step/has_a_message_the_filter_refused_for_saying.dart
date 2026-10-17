import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: {'porelo-checkout-shell'} has a message the filter refused, for {'partner'}, saying {'key AKIA0000'}
Future<void> hasAMessageTheFilterRefusedForSaying(WidgetTester tester, String task, String peer, String text) async {
  World.holdAMessage(
    task: task,
    peer: peer,
    text: text,
    standing: 'refused-by-filter',
    reason: 'rule aws-key at part 1, line 1',
  );
}
