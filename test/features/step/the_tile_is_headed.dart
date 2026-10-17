import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: the tile {'porelo-shared-shell'} is headed {'elsewhere'}
Future<void> theTileIsHeaded(WidgetTester tester, String work, String machine) async {
  await toTheTile(tester, work);
  final heading = tester.widget<Text>(
    find.descendant(of: tileFor(work), matching: find.byKey(const Key('tile-machine'))),
  );
  // The machine is said on every tile, under the work that heads it (walk 8).
  expect(heading.data, machine);
}
