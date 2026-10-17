import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the repository {'checkout'} is not offered to start in
Future<void> theRepositoryIsNotOfferedToStartIn(WidgetTester tester, String repository) async {
  expect(
    World.fieldOffering(tester, id: 'start-repository-$repository'),
    isNull,
    reason: '$repository is offered as a place to work',
  );
}
