// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_open_what_this_project_may_reach.dart';
import './step/it_shows_granted_by.dart';
import './step/it_says_is_refused.dart';
import './step/i_look_inside_the_set.dart';
import './step/it_lists.dart';
import './step/it_says.dart';
import './step/it_does_not_say.dart';
import './step/i_open_the_command_finder.dart';
import './step/the_command_is_offered_as_unavailable.dart';
import './step/the_project_has_the_repositories.dart';
import './step/the_repository_adds.dart';
import './step/i_open_what_the_repository_may_reach.dart';
import './step/is_marked_as_added_by_the_repository.dart';
import './step/is_not_marked_as_added_by_the_repository.dart';
import './step/egress_was_asked_about_the_repository.dart';
import './step/i_ask_to_stop_following_this_project.dart';
import './step/nothing_was_removed.dart';
import './step/i_agree_to_stop_following_it.dart';
import './step/following_stopped_for.dart';
import './step/nothing_was_forced.dart';
import './step/stopping_following_will_refuse_because.dart';
import './step/it_was_forced.dart';
import './step/the_command_is_offered.dart';
import './step/the_project_is_left_over_followed_by_nothing.dart';
import './step/the_command_is_unavailable_because.dart';
import './step/the_machine_follows_nothing_called_it.dart';

void main() {
  group('''What a project may reach, and no longer following one''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
    }

    testWidgets('''what the work may reach says where each host came from''', (tester) async {
      await bddSetUp(tester);
      await iOpenWhatThisProjectMayReach(tester);
      await itShowsGrantedBy(tester, 'api.anthropic.com', 'agent an-agent');
      await itShowsGrantedBy(tester, 'pub.dev', 'set dart-packages');
    });
    testWidgets('''what is asked for and refused is told apart from what nobody added''', (tester) async {
      await bddSetUp(tester);
      await iOpenWhatThisProjectMayReach(tester);
      await itSaysIsRefused(tester, 'telemetry.example.test');
    });
    testWidgets('''a set says which hosts it grants, because the name alone does not''', (tester) async {
      await bddSetUp(tester);
      await iOpenWhatThisProjectMayReach(tester);
      await iLookInsideTheSet(tester, 'Container registries');
      await itLists(tester, 'quay.io');
    });
    testWidgets('''what a project may reach is shown, and said to be changed only in its repository''', (tester) async {
      await bddSetUp(tester);
      await iOpenWhatThisProjectMayReach(tester);
      await itSays(tester, 'under egress; a machine following it takes the change');
      await itDoesNotSay(tester, 'Make this change');
    });
    testWidgets('''a project that declares no egress at all is not offered it''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'billing');
      await iOpenTheCommandFinder(tester);
      await theCommandIsOfferedAsUnavailable(tester, 'What this project may reach');
    });
    testWidgets('''what a repository adds is shown on top of what every repository gets, and marked''', (tester) async {
      await bddSetUp(tester);
      await theProjectHasTheRepositories(tester, 'checkout', 'checkout, payments-api');
      await theRepositoryAdds(tester, 'payments-api', 'api.stripe.com');
      await iSelectTheProject(tester, 'checkout');
      await iOpenWhatTheRepositoryMayReach(tester, 'payments-api');
      await itSays(tester, 'checkout · payments-api');
      await itSays(tester, 'github.com');
      await isMarkedAsAddedByTheRepository(tester, 'api.stripe.com');
      await isNotMarkedAsAddedByTheRepository(tester, 'github.com');
      await egressWasAskedAboutTheRepository(tester, 'payments-api');
    });
    testWidgets('''choosing sets one at a time is explained, not merely how it works''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iOpenWhatThisProjectMayReach(tester);
      await itSays(tester, 'ones installed later');
    });
    testWidgets('''what would go is shown, and asking removes nothing''', (tester) async {
      await bddSetUp(tester);
      await iAskToStopFollowingThisProject(tester);
      await itSays(tester, 'This stops following checkout');
      await nothingWasRemoved(tester);
    });
    testWidgets('''the repository is said to be untouched, and following it again brings it back''', (tester) async {
      await bddSetUp(tester);
      await iAskToStopFollowingThisProject(tester);
      await itSays(tester, 'Its repository is not touched');
      await itSays(tester, 'Following its repository again brings it back');
    });
    testWidgets('''agreeing is a second act, and it says what is still there afterwards''', (tester) async {
      await bddSetUp(tester);
      await iAskToStopFollowingThisProject(tester);
      await iAgreeToStopFollowingIt(tester);
      await followingStoppedFor(tester, 'checkout');
      await itSays(tester, 'no longer followed here');
      await nothingWasForced(tester);
    });
    testWidgets('''commits nobody reviewed stop it, and say where they exist''', (tester) async {
      await bddSetUp(tester);
      await stoppingFollowingWillRefuseBecause(tester, 'HOLDS_WORK');
      await iAskToStopFollowingThisProject(tester);
      await iAgreeToStopFollowingIt(tester);
      await itSays(tester, 'nobody has reviewed it');
      await itSays(tester, 'in the mirror and nowhere else');
      await nothingWasForced(tester);
    });
    testWidgets('''running work stops it, and is not told the same way''', (tester) async {
      await bddSetUp(tester);
      await stoppingFollowingWillRefuseBecause(tester, 'TASKS_RUNNING');
      await iAskToStopFollowingThisProject(tester);
      await iAgreeToStopFollowingIt(tester);
      await itSays(tester, 'Work is still running');
      await itSays(tester, 'cut off where it stands');
    });
    testWidgets('''going past a refusal is a second decision, and is what carries force''', (tester) async {
      await bddSetUp(tester);
      await stoppingFollowingWillRefuseBecause(tester, 'HOLDS_WORK');
      await iAskToStopFollowingThisProject(tester);
      await iAgreeToStopFollowingIt(tester);
      await iAgreeToStopFollowingIt(tester);
      await itWasForced(tester);
      await itSays(tester, 'is gone');
    });
    testWidgets('''a project this machine does not follow can still be cleared away''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'unrecorded');
      await iOpenTheCommandFinder(tester);
      await theCommandIsOffered(tester, 'Stop following this project');
    });
    testWidgets('''a project left from before following offers nothing but clearing it away''', (tester) async {
      await bddSetUp(tester);
      await theProjectIsLeftOverFollowedByNothing(tester, 'checkout');
      await iSelectTheProject(tester, 'checkout');
      await iOpenTheCommandFinder(tester);
      await theCommandIsUnavailableBecause(
        tester,
        'Review what is waiting at the gate',
        'not a project this machine follows',
      );
      await theCommandIsUnavailableBecause(
        tester,
        'Build the environment for this project',
        'not a project this machine follows',
      );
      await theCommandIsOffered(tester, 'Stop following this project');
    });
    testWidgets('''a project the machine follows nothing by is said to be so, and nothing goes''', (tester) async {
      await bddSetUp(tester);
      await theProjectIsLeftOverFollowedByNothing(tester, 'checkout');
      await theMachineFollowsNothingCalledIt(tester);
      await iAskToStopFollowingThisProject(tester);
      await itSays(tester, 'Nothing follows checkout here');
      await itSays(tester, 'Nothing was removed');
    });
  });
}
