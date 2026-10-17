import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/session_view.dart';

import '../support/world.dart';

/// Usage: enough time passes to go back
Future<void> enoughTimePassesToGoBack(WidgetTester tester) async {
  await tester.pump(SessionView.backAfter);
  await World.settle(tester);
}
