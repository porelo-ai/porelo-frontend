import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';

/// Usage: I click the tile {'porelo-checkout-shell'} with the right button
Future<void> iClickTheTileWithTheRightButton(WidgetTester tester, String work) async {
  await toTheTile(tester, work);
  // On the headline, not the name: the name is selectable text with its own menu.
  await tester.tap(
    find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-headline'))),
    buttons: kSecondaryButton,
  );
  await World.settle(tester);
}
