import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

/// Usage: no tile is shown for {'porelo-billing-shell'}
Future<void> noTileIsShownFor(WidgetTester tester, String work) async {
  expect(tileFor(work), findsNothing);
}
