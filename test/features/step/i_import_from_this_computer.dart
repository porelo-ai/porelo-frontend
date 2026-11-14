import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I import {'other-provider'} from this computer
Future<void> iImportFromThisComputer(WidgetTester tester, String provider) async {
  final button = find.byKey(Key('carry-credential $provider'));
  await tester.ensureVisible(button);
  await World.settle(tester);
  await tester.tap(button);
  await World.settle(tester);
}
