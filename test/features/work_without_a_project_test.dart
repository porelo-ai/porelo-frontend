// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_machine_has_the_project_default.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/the_first_project_on_the_machine_is.dart';
import './step/i_select_the_project.dart';
import './step/i_open_the_command_finder.dart';
import './step/the_command_is_unavailable_because.dart';
import './step/i_press_the_start_tile.dart';
import './step/it_says.dart';
import './step/i_start_work_in_default_on.dart';
import './step/default_holds_at.dart';
import './step/the_repository_is_chosen.dart';
import './step/default_holds_at_already.dart';
import './step/i_start_work_in_this_project.dart';
import './step/i_start_work_in_default_on_the_one_called.dart';
import './step/nothing_was_put_into_default_again.dart';
import './step/the_forge_reaches_as_an_admin_and_without_admin_rights.dart';
import './step/the_keychain_here_keeps_the_token_for_the_forge.dart';
import './step/i_pick_at_the_forge_for_default.dart';
import './step/the_address_for_default_reads.dart';
import './step/i_start_work_on_it_from_default.dart';
import './step/no_deploy_key_calls_were_made.dart';
import './step/i_put_the_start_away.dart';
import './step/i_choose_the_command.dart';
import './step/i_take_out_of_default.dart';
import './step/the_forge_holds_no_key_titled_at.dart';
import './step/the_project_header_does_not_say.dart';
import './step/the_project_header_says.dart';
import './step/the_start_tile_says.dart';
import './step/default_holds_at_named_by_too.dart';
import './step/default_no_longer_holds.dart';
import './step/i_review_what_is_waiting_at_the_gate.dart';
import './step/i_open_the_waiting_push.dart';
import './step/i_start_forwarding_it_to_its_origin.dart';
import './step/the_forwarding_asks.dart';
import './step/i_go_to_the_place.dart';
import './step/the_projects_page_lists_on.dart';

void main() {
  group('''Work on a repository without writing a project first''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theMachineHasTheProjectDefault(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''default is the project shown first, and cannot be stopped following''', (tester) async {
      await bddSetUp(tester);
      await theFirstProjectOnTheMachineIs(tester, 'default');
      await iSelectTheProject(tester, 'default');
      await iOpenTheCommandFinder(tester);
      await theCommandIsUnavailableBecause(tester, 'Stop following this project', 'default is always there');
    });
    testWidgets('''work in default starts on a repository named by its address, which goes into default on the way''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'default');
      await iPressTheStartTile(tester);
      await itSays(tester, 'which cannot be changed');
      await itSays(tester, 'Approved work goes to the repository’s origin');
      await iStartWorkInDefaultOn(tester, 'git@example.org:acme/tools.git');
      await defaultHoldsAt(tester, 'tools', 'git@example.org:acme/tools.git');
      await theRepositoryIsChosen(tester, 'tools');
    });
    testWidgets('''a repository worked on before in default is started on again without naming it''', (tester) async {
      await bddSetUp(tester);
      await defaultHoldsAtAlready(tester, 'tools', 'git@example.org:acme/tools.git');
      await iSelectTheProject(tester, 'default');
      await iStartWorkInThisProject(tester);
      await iStartWorkInDefaultOnTheOneCalled(tester, 'tools');
      await theRepositoryIsChosen(tester, 'tools');
      await nothingWasPutIntoDefaultAgain(tester);
    });
    testWidgets('''a repository picked at a forge fills its https address without deploy keys''', (tester) async {
      await bddSetUp(tester);
      await theForgeReachesAsAnAdminAndWithoutAdminRights(tester, 'acme/api', 'acme/web');
      await theKeychainHereKeepsTheTokenForTheForge(tester, 'ghp_accepted');
      await iSelectTheProject(tester, 'default');
      await iStartWorkInThisProject(tester);
      await iPickAtTheForgeForDefault(tester, 'acme/api');
      await theAddressForDefaultReads(tester, 'https://github.com/acme/api.git');
      await iStartWorkOnItFromDefault(tester);
      await defaultHoldsAt(tester, 'api', 'https://github.com/acme/api.git');
      await noDeployKeyCallsWereMade(tester);
      await iPutTheStartAway(tester);
      await iChooseTheCommand(tester, 'Repositories worked on without a project');
      await iTakeOutOfDefault(tester, 'api');
      await theForgeHoldsNoKeyTitledAt(tester, 'porelo vm default/api', 'acme/api');
    });
    testWidgets('''default opened from its row says what it is and offers its repositories, and nothing it lacks''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'default');
      await theProjectHeaderDoesNotSay(tester, 'not followed here');
      await theProjectHeaderDoesNotSay(tester, 'environment not prepared');
      await theProjectHeaderSays(tester, 'worked on with Porelo’s own settings');
      await theStartTileSays(tester, 'Start work');
    });
    testWidgets('''a repository a followed project names too is offered to be taken out of default''', (tester) async {
      await bddSetUp(tester);
      await defaultHoldsAtNamedByToo(tester, 'api', 'https://github.com/acme/api.git', 'payments');
      await iSelectTheProject(tester, 'default');
      await iChooseTheCommand(tester, 'Repositories worked on without a project');
      await itSays(tester, 'payments names it too: its next task starts there');
      await iTakeOutOfDefault(tester, 'api');
      await defaultNoLongerHolds(tester, 'api');
      await itSays(tester, 'Its mirror, and anything waiting in it, stay');
    });
    testWidgets('''only default holds repositories without a project''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iOpenTheCommandFinder(tester);
      await theCommandIsUnavailableBecause(tester, 'Repositories worked on without a project', 'only default holds');
    });
    testWidgets('''work waiting in default is forwarded to its origin''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'default');
      await iReviewWhatIsWaitingAtTheGate(tester);
      await iOpenTheWaitingPush(tester);
      await itSays(tester, 'Forward it to its origin');
      await iStartForwardingItToItsOrigin(tester);
      await theForwardingAsks(tester, 'Forward it to its origin');
    });
    testWidgets('''work without a project is listed on its machine''', (tester) async {
      await bddSetUp(tester);
      await iGoToThePlace(tester, 'projects');
      await itSays(tester, 'Without a project');
      await theProjectsPageListsOn(tester, 'checkout', 'this machine');
    });
  });
}
