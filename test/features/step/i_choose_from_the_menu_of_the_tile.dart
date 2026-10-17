import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I choose {'Stop it and remove it'} from the menu of the tile {'porelo-shared-shell'}
Future<void> iChooseFromTheMenuOfTheTile(WidgetTester tester, String label, String work) async {
  await toTheTile(tester, work);
  await tester.tap(find.descendant(of: tileFor(work), matching: find.byWidgetPredicate((each) => each.key is ValueKey<String> && (each.key! as ValueKey<String>).value.startsWith('tile-menu'))));
  await World.settle(tester);
  final item = find.ancestor(
      of: find.text(label), matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem));
  // Scrolled to first, as a person would: a long menu puts its last entries below the fold.
  await tester.ensureVisible(item);
  await tester.pump();
  await tester.tap(item);
  await World.settle(tester);
}
