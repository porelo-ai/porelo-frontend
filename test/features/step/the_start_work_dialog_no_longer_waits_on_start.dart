import 'package:flutter_test/flutter_test.dart';

import 'the_start_work_dialog_waits_on_start_with_its_mark.dart';

/// Usage: the Start work dialog no longer waits on Start
Future<void> theStartWorkDialogNoLongerWaitsOnStart(WidgetTester tester) async {
  expect(find.text(startWaitWords), findsNothing);
}
