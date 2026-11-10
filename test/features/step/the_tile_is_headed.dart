import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the tile {'porelo-shared-shell'} is headed {'elsewhere'}
///
/// Under *Needs you*, each of its rows there; elsewhere, its tile.
Future<void> theTileIsHeaded(WidgetTester tester, String work, String machine) async {
  final tile = await whereTheTileIs(tester, work);
  final headings = tester.widgetList<Text>(find.descendant(of: tile, matching: find.byKey(const Key('needs-machine'))));
  expect(headings, isNotEmpty, reason: 'nothing names the machine of $work');
  // The machine is said on every tile and row, under the work that heads it (walk 8).
  for (final heading in headings) {
    expect(heading.data, 'on $machine');
  }
}
