import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the session prints {'root@porelo-billing-shell:/work#'}
Future<void> theSessionPrints(WidgetTester tester, String words) async {
  World.terminals.last.prints(words);
  await World.settle(tester);
}
