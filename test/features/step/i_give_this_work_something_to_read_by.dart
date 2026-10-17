import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'i_ask_what_this_work_should_read_as.dart';

/// Usage: I give this work something to read by {'schema migration, second attempt'}
Future<void> iGiveThisWorkSomethingToReadBy(WidgetTester tester, String caption) async {
  await iAskWhatThisWorkShouldReadAs(tester);
  await tester.enterText(find.byKey(const Key('what-it-reads-as')), caption);
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('name-it')));
  await World.settle(tester);
}
