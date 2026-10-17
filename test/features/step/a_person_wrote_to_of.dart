import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: a person wrote {'is the schema done?'} to {'reviewer'} of {'porelo-checkout-migrate'}
Future<void> aPersonWroteToOf(WidgetTester tester, String text, String peer, String task) async {
  expect(World.backend.saidByAPerson, [(task: task, peer: peer, text: text, kind: 'question')]);
}
