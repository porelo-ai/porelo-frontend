import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: I read the message from {'porelo-checkout-shell'}
Future<void> iReadTheMessageFrom(WidgetTester tester, String task) async {
  final read = find.byWidgetPredicate(
    (each) => each.key is ValueKey<String> && (each.key! as ValueKey<String>).value.startsWith('read-message $task/'),
  );
  await tester.tap(read);
  await World.settle(tester);
}
