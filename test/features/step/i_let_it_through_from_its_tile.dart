import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import '../../support/expand_list_rows.dart';

/// Usage: I let it through from its tile
Future<void> iLetItThroughFromItsTile(WidgetTester tester) async {
  await expandListRows(tester, within: find.byKey(const Key('open-attention')));
  final button = find.byKey(const Key('tile-let-through')).first;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await World.settle(tester);
}
