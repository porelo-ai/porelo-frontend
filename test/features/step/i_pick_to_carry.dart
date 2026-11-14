import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I pick {'vault an-agent'} to carry
Future<void> iPickToCarry(WidgetTester tester, String source) async {
  await tester.tap(find.byKey(Key('carry-source $source')));
  await World.settle(tester);
}
