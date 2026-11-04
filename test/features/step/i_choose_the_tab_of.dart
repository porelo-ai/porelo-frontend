import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I choose the tab of {'porelo-billing-shell'}
Future<void> iChooseTheTabOf(WidgetTester tester, String work) async {
  final tab = find.byWidgetPredicate(
    (widget) => '${widget.key}'.startsWith("[<'running-tab ") && '${widget.key}'.endsWith("/$work'>]"),
  );
  await tester.ensureVisible(tab);
  await tester.pump();
  await tester.tap(tab);
  await World.settle(tester);
}
