import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../support/results_land.dart';

/// Usage: the findings are worked off and the file is deleted
Future<void> theFindingsAreWorkedOffAndTheFileIsDeleted(WidgetTester tester) =>
    walked(tester, '12 [findings] read: the findings are worked off and the file is deleted', () async {
      final place = ResultsLand.place ?? fail('no place of findings was read');
      for (final repository in ResultsLand.added.keys) {
        final clone = await aFreshClone(repository);
        final deleted = await theCommitsThat(clone, 'D', place);
        if (deleted.isEmpty) {
          fail('asked $repository at the forge for the findings under $place deleted; no branch deletes them');
        }
        // Deleted with the fix: the deleting commit changes more than the findings.
        final changed = await git(['show', '--format=', '--name-only', deleted.first], where: clone);
        final fixed = changed.split('\n').where((path) => path.isNotEmpty && !path.startsWith(place)).toList();
        if (fixed.isEmpty) {
          fail('asked ${deleted.first} in $repository for the fix beside the deletion; it changes only $changed');
        }
        noteStep('   $repository: findings deleted in ${deleted.first} with ${fixed.join(', ')}');
      }
    });
