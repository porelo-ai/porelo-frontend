import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../../support/expand_list_rows.dart';

/// Usage: I forget the token here
Future<void> iForgetTheTokenHere(WidgetTester tester) async {
  await expandListRows(tester);
  // From the forge's own menu, beside its page's heading (walk 10).
  final name = World.forges.current?.name ?? 'GitHub';
  await tester.tap(find.byKey(ValueKey<String>('forges-menu $name')).first);
  await World.settle(tester);
  await tester.tap(find.byKey(ValueKey<String>('forge-remove $name')));
  await World.settle(tester);
  await tester.tap(find.byKey(const Key('forge-remove-confirm')));
  await World.settle(tester);
}
