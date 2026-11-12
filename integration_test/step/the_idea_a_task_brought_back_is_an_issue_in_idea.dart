import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../support/results_land.dart';

/// Usage: the idea a task brought back is an issue in Idea
Future<void> theIdeaATaskBroughtBackIsAnIssueInIdea(
  WidgetTester tester,
) => walked(tester, '10 [ideas] the idea a task brought back is an issue in Idea', () async {
  // An issue of the run in Idea that is none of the story's own: what a task brought back, as the store keeps it and as
  // the planner says it.
  final own = {for (final issue in Walk.issues) issue.id};
  final found = <String>[];
  for (final repository in Walk.issueRepositories) {
    final clone = await aFreshClone(repository);
    final heads = await git([
      'grep',
      '-l',
      '-E',
      '"state": *"Idea"',
      'HEAD',
      '--',
      'issues',
    ], where: clone).catchError((_) => '');
    for (final path in heads.split('\n').where((each) => each.isNotEmpty)) {
      final id = RegExp(r'issues/([A-Z]+[0-9]+)-').firstMatch(path)?.group(1);
      if (id != null && !own.contains(id)) found.add(id);
    }
  }
  if (found.isEmpty) {
    fail('asked the issue repositories for an issue in Idea beside the story\'s ${own.join(', ')}; none');
  }
  for (final id in found) {
    await probe(['issue-state', id, 'Idea']);
  }
  noteStep('   brought back: ${found.join(', ')}');
});
