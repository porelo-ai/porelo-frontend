import 'package:flutter_test/flutter_test.dart';

import '../support/tiles.dart';
import '../support/world.dart';
import '../../support/expand_list_rows.dart';

/// Usage: I go to what needs a person
Future<void> iGoToWhatNeedsAPerson(WidgetTester tester) async {
  await toThePlace(tester, 'attention');
  await World.settle(tester);
  await expandListRows(tester);
}
