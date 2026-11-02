import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';
import 'i_look_at_the_forges_repository.dart';

/// Usage: I look at the changes waiting at {'acme/api'}
Future<void> iLookAtTheChangesWaitingAt(WidgetTester tester, String repository) async {
  await chooseTheRepository(tester, repository);
  await fromTheRepositorysMenu(tester, repository, 'repository-tools');
  await tester.ensureVisible(find.byKey(const Key('binding-changes')));
  await tester.tap(find.byKey(const Key('binding-changes')));
  await World.settle(tester);
}
