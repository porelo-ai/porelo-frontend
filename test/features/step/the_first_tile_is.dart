import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the first tile is {'porelo-billing-shell'}
Future<void> theFirstTileIs(WidgetTester tester, String work) async {
  final tiles = tester
      .widgetList<Card>(find.byType(Card))
      .where((card) => '${card.key}'.contains("'tile "))
      .toList();
  expect(tiles, isNotEmpty, reason: 'no tiles are on screen');
  expect('${tiles.first.key}', contains(work));
}
