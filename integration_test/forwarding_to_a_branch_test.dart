// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './step/the_interface_is_running.dart';
import './step/a_task_in_the_forwarding_repository_has_work_waiting_at_its_gate.dart';
import './step/i_review_that_work_at_the_gate.dart';
import './step/i_forward_it_upstream_onto_the_branch_the_repository_has.dart';
import './step/github_has_that_branch_at_the_reviewed_commit_and_the_default_branch_where_it_was.dart';
import './step/i_forward_it_upstream_onto_a_new_branch_i_type.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Approved work forwarded to a chosen branch lands on it at GitHub''', () {
    testWidgets('''work forwarded onto a branch the repository has lands on that branch''', (tester) async {
      await theInterfaceIsRunning(tester);
      await aTaskInTheForwardingRepositoryHasWorkWaitingAtItsGate(tester);
      await iReviewThatWorkAtTheGate(tester);
      await iForwardItUpstreamOntoTheBranchTheRepositoryHas(tester);
      await githubHasThatBranchAtTheReviewedCommitAndTheDefaultBranchWhereItWas(tester);
    });
    testWidgets('''work forwarded onto a branch the person types lands on that new branch''', (tester) async {
      await theInterfaceIsRunning(tester);
      await aTaskInTheForwardingRepositoryHasWorkWaitingAtItsGate(tester);
      await iReviewThatWorkAtTheGate(tester);
      await iForwardItUpstreamOntoANewBranchIType(tester);
      await githubHasThatBranchAtTheReviewedCommitAndTheDefaultBranchWhereItWas(tester);
    });
  });
}
