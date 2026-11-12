import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../support/results_land.dart';

/// Usage: the findings file lies where the project's setting says
Future<void> theFindingsFileLiesWhereTheProjectsSettingSays(WidgetTester tester) =>
    walked(tester, "11 [findings] the findings file lies where the project's setting says", () async {
      // The place is the project's word, in its project.yml: one setting naming where a reading's findings go.
      final project = await aFreshClone(Walk.poreloProject);
      final file = await git(['show', 'HEAD:project.yml'], where: project);
      final place = ResultsLand.place = RegExp(
        r'^\s*findings:\s*"?([^"\s#]+)',
        multiLine: true,
      ).firstMatch(file)?.group(1);
      if (place == null) fail('asked project.yml of ${Walk.poreloProject} for the place of findings; it names none');
      // Every issue read with findings left one file there, on a branch of its repository at the forge.
      for (final repository in Walk.issueRepositories) {
        final clone = await aFreshClone(repository);
        final added = await theCommitsThat(clone, 'A', place);
        if (added.isEmpty) fail('asked $repository at the forge for a findings file under $place; no branch has one');
        ResultsLand.added[repository] = added.first;
        noteStep('   $repository: findings added under $place in ${added.first}');
      }
    });
