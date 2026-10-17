import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the command to store one is {'porelo vault put an-agent --type oauth'}
///
/// Rendered verbatim. The daemon built it from the key it really uses, and a line rebuilt here
/// would sooner or later name a different one.
Future<void> theCommandToStoreOneIs(WidgetTester tester, String command) async {
  expect(
    tester.widgetList<SelectableText>(find.byKey(const Key('store-command'))).map((each) => each.data),
    contains(command),
  );
}
