import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: a person told {'porelo-checkout-migrate'} {'stop the migration, the schema changed'}
Future<void> aPersonTold(WidgetTester tester, String task, String words) async {
  expect(World.backend.toldByAPerson, [(task: task, text: words)]);
}
