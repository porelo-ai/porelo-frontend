import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the repository {'units4j'} is offered to start in
Future<void> theRepositoryIsOfferedToStartIn(WidgetTester tester, String repository) async {
  expect(
    World.fieldOffering(tester, id: 'start-repository-$repository'),
    isNotNull,
    reason: '$repository is not offered as a place to work',
  );
}
