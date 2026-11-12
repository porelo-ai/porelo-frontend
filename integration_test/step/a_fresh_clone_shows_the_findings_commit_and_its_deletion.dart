import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../support/results_land.dart';

/// Usage: a fresh clone shows the findings commit and its deletion
Future<void> aFreshCloneShowsTheFindingsCommitAndItsDeletion(WidgetTester tester) => walked(
  tester,
  '13 [findings] read: a fresh clone shows the findings commit and its deletion',
  () async {
    final place = ResultsLand.place ?? fail('no place of findings was read');
    for (final MapEntry(key: repository, value: added) in ResultsLand.added.entries) {
      final clone = await aFreshClone(repository);
      final deleted = await theCommitsThat(clone, 'D', place);
      if (deleted.isEmpty) fail('asked a fresh clone of $repository for the deletion under $place; it has none');
      // One history: the deletion stands on the commit that added the findings.
      final ran = await git([
        'merge-base',
        '--is-ancestor',
        added,
        deleted.first,
      ], where: clone).then((_) => true, onError: (_) => false);
      if (!ran) fail('asked a fresh clone of $repository for $added before ${deleted.first}; they are not one history');
    }
  },
);
