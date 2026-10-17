import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'i_look_at_the_forges_repository.dart';

/// Usage: I look at every Porelo key and signer of {'acme/api'}
Future<void> iLookAtEveryPoreloKeyAndSignerOf(WidgetTester tester, String repository) async {
  await chooseTheRepository(tester, repository);
  await fromTheRepositorysMenu(tester, repository, 'repository-tools');
  await tester.tap(find.byKey(const Key('binding-survey')));
  await World.settle(tester);
}
