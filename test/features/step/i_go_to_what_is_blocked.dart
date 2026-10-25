import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';

import '../support/world.dart';
import '../../support/expand_list_rows.dart';

/// Usage: I go to what is blocked
///
/// A blocked connection is a question on its work's tile, and every one of them is on what needs
/// a person.
Future<void> iGoToWhatIsBlocked(WidgetTester tester) async {
  await toTheMachines(tester);
  await toThePlace(tester, 'attention');
  await World.settle(tester);
  await expandListRows(tester);
}
