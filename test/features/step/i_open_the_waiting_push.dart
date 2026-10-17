import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I open the waiting push
/// Usage: I open the waiting push {'Retry a declined card once'}
Future<void> iOpenTheWaitingPush(
  WidgetTester tester, [
  String subject = 'Round to the nearest penny, not away from zero',
]) async {
  await tester.tap(find.text(subject));
  await World.settle(tester);
}
