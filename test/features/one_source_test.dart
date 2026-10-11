// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_machine_has_the_project_default.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/default_holds_from_the_checkout_whose_remote_is.dart';
import './step/i_select_the_project.dart';
import './step/i_choose_the_command.dart';
import './step/it_says.dart';
import './step/default_holds_from_the_remote.dart';
import './step/default_holds_at_already.dart';
import './step/it_does_not_say.dart';
import './step/a_refresh_moves_to.dart';
import './step/i_select_the_work.dart';
import './step/the_machine_was_asked_to_refresh_the_task.dart';
import './step/the_status_line_mentions.dart';
import './step/a_refresh_answers.dart';
import './step/a_refresh_answers_because.dart';

void main() {
  group('''Where a repository's work comes from and goes, and catching up''',
      () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theMachineHasTheProjectDefault(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets(
        '''a repository started in a checkout says its work comes from it and goes back there''',
        (tester) async {
      await bddSetUp(tester);
      await defaultHoldsFromTheCheckoutWhoseRemoteIs(
          tester, 'app', '/home/somebody/work/app', 'git@example.org:app.git');
      await iSelectTheProject(tester, 'default');
      await iChooseTheCommand(
          tester, 'Repositories worked on without a project');
      await itSays(tester,
          'From the checkout /home/somebody/work/app, and back into it as sokar/<task>');
      await itSays(tester,
          'its remote git@example.org:app.git is yours to pull and push');
    });
    testWidgets(
        '''a repository added by its address says its work comes from that remote and goes there''',
        (tester) async {
      await bddSetUp(tester);
      await defaultHoldsFromTheRemote(
          tester, 'tools', 'git@example.org:acme/tools.git');
      await iSelectTheProject(tester, 'default');
      await iChooseTheCommand(
          tester, 'Repositories worked on without a project');
      await itSays(
          tester, 'From git@example.org:acme/tools.git, and back there');
    });
    testWidgets(
        '''a machine older than one source shows the address as before''',
        (tester) async {
      await bddSetUp(tester);
      await defaultHoldsAtAlready(
          tester, 'tools', 'git@example.org:acme/tools.git');
      await iSelectTheProject(tester, 'default');
      await iChooseTheCommand(
          tester, 'Repositories worked on without a project');
      await itSays(tester, 'git@example.org:acme/tools.git');
      await itDoesNotSay(tester, 'and back there');
    });
    testWidgets(
        '''a running task is brought up to its source, and its agent is told''',
        (tester) async {
      await bddSetUp(tester);
      await aRefreshMovesTo(tester, 'main', '111df4193e7e0011');
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'sokar-checkout-shell');
      await iChooseTheCommand(tester, 'Bring it up to its source');
      await theMachineWasAskedToRefreshTheTask(tester, 'sokar-checkout-shell');
      await theStatusLineMentions(tester,
          'main moved to 111df4193e7e; its agent was told, and git fetch sokar brings it');
    });
    testWidgets(
        '''a task without a gate says there is nothing to bring up, rather than nothing''',
        (tester) async {
      await bddSetUp(tester);
      await aRefreshAnswers(tester, 'NOT_GATED');
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'sokar-checkout-shell');
      await iChooseTheCommand(tester, 'Bring it up to its source');
      await theStatusLineMentions(tester,
          'has no gate, so there is nothing here to bring up to its source');
      await theStatusLineMentions(
          tester, 'started without one, or it is offline');
    });
    testWidgets('''a refresh that failed says why, in the machine's words''',
        (tester) async {
      await bddSetUp(tester);
      await aRefreshAnswersBecause(
          tester, 'FAILED', 'the checkout /home/somebody/work/app is gone');
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'sokar-checkout-shell');
      await iChooseTheCommand(tester, 'Bring it up to its source');
      await theStatusLineMentions(tester,
          'could not be brought up to its source: the checkout /home/somebody/work/app is gone');
    });
  });
}
