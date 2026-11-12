import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/forwarding.dart';
import '../support/rehearsal.dart';

/// Usage: GitHub has that branch at the reviewed commit and the default branch where it was
Future<void> githubHasThatBranchAtTheReviewedCommitAndTheDefaultBranchWhereItWas(WidgetTester tester) =>
    pictured(tester, () async {
      final branch = Forwarding.branch!;
      // porelod pushes once the gate let it go; GitHub answers the new head a moment later.
      String? head;
      await pumpUntil(
        tester,
        () async => (head = await theHeadAtGitHub(branch)) == Rehearsal.reviewedCommit,
        timeout: const Duration(minutes: 2),
        what: 'GitHub to have $branch at ${Rehearsal.reviewedCommit}',
      );
      final (defaultBranch, defaultHead) = await theDefaultAtGitHub();
      final (wasBranch, wasHead) = Forwarding.defaultBefore!;
      expect(defaultBranch, wasBranch, reason: 'the default branch is still $wasBranch');
      expect(defaultHead, wasHead, reason: 'the reviewed commit $head did not land on $defaultBranch');
      // Nor on any other branch: each but the chosen one stands where it stood, and no other branch was made.
      final now = await theBranchesAtGitHub()
        ..remove(branch);
      expect(now, Map.of(Forwarding.branchesBefore!)..remove(branch), reason: 'only $branch moved');
    });
