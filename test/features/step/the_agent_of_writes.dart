import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the agent of {'porelo-billing-shell'} writes {'reading the contracts'}
///
/// One line of its log as its agent formats it, arriving now.
Future<void> theAgentOfWrites(WidgetTester tester, String work, String line) async {
  World.backend.formattedTails[work]!.add(<String>[line]);
  await tester.pump();
}
