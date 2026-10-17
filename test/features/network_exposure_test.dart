// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/work_is_blocked_reaching.dart';
import './step/the_rail_says_is_waiting.dart';
import './step/i_go_to_what_is_blocked.dart';
import './step/it_shows_the_destination.dart';
import './step/it_names_the_work_and_the_rule.dart';
import './step/other_work_is_blocked_reaching.dart';
import './step/both_are_shown_together.dart';
import './step/i_let_it_through.dart';
import './step/the_answer_sent_was.dart';
import './step/i_keep_it_blocked.dart';
import './step/i_select_the_project.dart';
import './step/the_work_is_marked_as_unenforced.dart';
import './step/the_work_is_not_marked_as_unenforced.dart';
import './step/the_answer_comes_back.dart';
import './step/it_says.dart';
import './step/the_question_runs_out.dart';
import './step/it_says_the_question_ran_out.dart';
import './step/nothing_is_waiting_any_more.dart';
import './step/i_select_the_work.dart';
import './step/i_choose_the_command.dart';
import './step/i_ask_it_to_reach.dart';
import './step/i_choose.dart';
import './step/i_show_what_that_would_grant.dart';
import './step/it_lists_the_grant.dart';
import './step/nothing_has_been_granted_yet.dart';
import './step/showing_what_it_would_grant_is_not_offered_yet.dart';
import './step/i_grant_it.dart';
import './step/the_scope_sent_was.dart';
import './step/the_project_file_cannot_be_found.dart';
import './step/the_machine_refuses_the_name_on_purpose.dart';
import './step/it_does_not_say.dart';
import './step/granting_it_is_not_offered.dart';
import './step/i_open_the_command_finder.dart';
import './step/the_command_is_offered_as_unavailable.dart';
import './step/i_take_something_back_from_this_work.dart';
import './step/i_say_the_names.dart';
import './step/i_show_what_that_would_take_back.dart';
import './step/nothing_has_been_taken_back_yet.dart';
import './step/i_take_it_back.dart';
import './step/taking_back_will_find_nothing_in_the_firewall.dart';
import './step/i_change_what_this_work_does_with_a_blocked_connection.dart';
import './step/i_choose_to.dart';
import './step/the_work_was_set_to.dart';
import './step/the_status_line_mentions.dart';

void main() {
  group('''Answering blocked connections, and widening what work reaches''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''a blocked connection turns up without anybody going to look for it''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await theRailSaysIsWaiting(tester, '1');
    });
    testWidgets('''what was attempted, by which work, and which rule stopped it''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await iGoToWhatIsBlocked(tester);
      await itShowsTheDestination(tester, 'api.example.test:443');
      await itNamesTheWorkAndTheRule(tester);
    });
    testWidgets('''several pieces of work are watched in one view, not one view each''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await otherWorkIsBlockedReaching(tester, 'files.example.test:22');
      await iGoToWhatIsBlocked(tester);
      await bothAreShownTogether(tester);
    });
    testWidgets('''letting one through tells the work that is waiting''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await iGoToWhatIsBlocked(tester);
      await iLetItThrough(tester);
      await theAnswerSentWas(tester, 'allow');
    });
    testWidgets('''keeping one blocked is a separate answer, not a silence''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await iGoToWhatIsBlocked(tester);
      await iKeepItBlocked(tester);
      await theAnswerSentWas(tester, 'deny');
    });
    testWidgets('''work nothing is enforcing is marked wherever it appears''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'billing');
      await theWorkIsMarkedAsUnenforced(tester, 'porelo-billing-audit');
      await theWorkIsNotMarkedAsUnenforced(tester, 'porelo-billing-shell');
    });
    testWidgets('''letting one through says the host is reachable, not that the attempt succeeded''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await iGoToWhatIsBlocked(tester);
      await iLetItThrough(tester);
      await theAnswerComesBack(tester);
      await itSays(tester, 'the attempt that was refused is gone');
    });
    testWidgets('''a destination asked about again says why that is not a mistake''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'cdn.example.test:443');
      await iGoToWhatIsBlocked(tester);
      await iLetItThrough(tester);
      await theAnswerComesBack(tester);
      await workIsBlockedReaching(tester, 'cdn.example.test:443');
      await itSays(tester, 'remembered per address');
    });
    testWidgets('''a question that ran out says so rather than quietly disappearing''', (tester) async {
      await bddSetUp(tester);
      await workIsBlockedReaching(tester, 'api.example.test:443');
      await iGoToWhatIsBlocked(tester);
      await theQuestionRunsOut(tester);
      await itSaysTheQuestionRanOut(tester);
      await nothingIsWaitingAnyMore(tester);
    });
    testWidgets('''what running work may reach is changed from where that work is listed''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iChooseTheCommand(tester, 'Let this work reach something new');
      await iAskItToReach(tester, 'files.example.test');
      await iChoose(tester, 'Just this run');
      await iShowWhatThatWouldGrant(tester);
      await itListsTheGrant(tester, 'files.example.test');
      await nothingHasBeenGrantedYet(tester);
    });
    testWidgets('''how far the change goes is chosen, never defaulted''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iChooseTheCommand(tester, 'Let this work reach something new');
      await iAskItToReach(tester, 'files.example.test');
      await showingWhatItWouldGrantIsNotOfferedYet(tester);
    });
    testWidgets('''the scope that was chosen is the scope that is sent''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iChooseTheCommand(tester, 'Let this work reach something new');
      await iAskItToReach(tester, 'files.example.test');
      await iChoose(tester, 'This run and the project file');
      await iShowWhatThatWouldGrant(tester);
      await iGrantIt(tester);
      await theScopeSentWas(tester, 'RUN_AND_PROJECT');
    });
    testWidgets('''a grant says the host is reachable next time, not that what failed will now work''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iChooseTheCommand(tester, 'Let this work reach something new');
      await iAskItToReach(tester, 'files.example.test');
      await iChoose(tester, 'Just this run');
      await iShowWhatThatWouldGrant(tester);
      await iGrantIt(tester);
      await itSays(tester, 'Reachable from the next attempt');
      await itSays(tester, 'This run only');
    });
    testWidgets('''a run widened with no project file to write is a partial success, not a failure''', (tester) async {
      await bddSetUp(tester);
      await theProjectFileCannotBeFound(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iChooseTheCommand(tester, 'Let this work reach something new');
      await iAskItToReach(tester, 'files.example.test');
      await iChoose(tester, 'This run and the project file');
      await iShowWhatThatWouldGrant(tester);
      await iGrantIt(tester);
      await itSays(tester, 'Granted for this run');
      await itSays(tester, 'Reachable from the next attempt');
    });
    testWidgets('''a name refused on purpose is said as a refusal, with the machine's reason''', (tester) async {
      await bddSetUp(tester);
      await theMachineRefusesTheNameOnPurpose(tester, 'www.iana.org');
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iChooseTheCommand(tester, 'Let this work reach something new');
      await iAskItToReach(tester, 'www.iana.org');
      await iChoose(tester, 'This run and the project file');
      await iShowWhatThatWouldGrant(tester);
      await itSays(tester, 'Refused: that name is refused on purpose');
      await itSays(tester, 'www.iana.org is refused by the project');
      await itDoesNotSay(tester, 'Reachable from the next attempt');
      await grantingItIsNotOffered(tester);
    });
    testWidgets('''work that is not running says why it cannot be widened''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-migrate');
      await iOpenTheCommandFinder(tester);
      await theCommandIsOfferedAsUnavailable(tester, 'Let this work reach something new');
    });
    testWidgets('''an offline project is never offered the action''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'billing');
      await iSelectTheWork(tester, 'porelo-billing-shell');
      await iOpenTheCommandFinder(tester);
      await theCommandIsOfferedAsUnavailable(tester, 'Let this work reach something new');
    });
    testWidgets('''taking a name back is previewed before anything changes''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iTakeSomethingBackFromThisWork(tester);
      await iSayTheNames(tester, 'files.example.test');
      await iChoose(tester, 'Just this run');
      await iShowWhatThatWouldTakeBack(tester);
      await itSays(tester, 'files.example.test');
      await itSays(tester, '2 addresses come out of the firewall');
      await nothingHasBeenTakenBackYet(tester);
    });
    testWidgets('''it says that new connections stop, never that the host is unreachable''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iTakeSomethingBackFromThisWork(tester);
      await itSays(tester, 'This stops new connections');
      await itSays(tester, 'a transfer already in flight runs to its end');
      await itSays(tester, 'stopping the task is what does that');
    });
    testWidgets('''taking it back says how far it went''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iTakeSomethingBackFromThisWork(tester);
      await iSayTheNames(tester, 'files.example.test');
      await iChoose(tester, 'This run and the project');
      await iShowWhatThatWouldTakeBack(tester);
      await iTakeItBack(tester);
      await itSays(tester, 'Taken back: files.example.test');
      await itSays(tester, 'The project file is changed too');
    });
    testWidgets('''a name that was never reached takes nothing out of the firewall''', (tester) async {
      await bddSetUp(tester);
      await takingBackWillFindNothingInTheFirewall(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iTakeSomethingBackFromThisWork(tester);
      await iSayTheNames(tester, 'files.example.test');
      await iChoose(tester, 'Just this run');
      await iShowWhatThatWouldTakeBack(tester);
      await itSays(tester, 'it was granted and never reached');
    });
    testWidgets('''work that is not running is not offered it''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-migrate');
      await iOpenTheCommandFinder(tester);
      await theCommandIsOfferedAsUnavailable(tester, 'Take something back from this work');
    });
    testWidgets('''enforcement is turned off on work that is already running''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iChangeWhatThisWorkDoesWithABlockedConnection(tester);
      await iChooseTo(tester, 'Stop asking entirely');
      await theWorkWasSetTo(tester, 'off');
      await theStatusLineMentions(tester, 'went from “prompt” to “off”');
    });
    testWidgets('''it says what turning it off does not undo''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
      await iChangeWhatThisWorkDoesWithABlockedConnection(tester);
      await itSays(tester, 'a connection that was refused stays refused');
      await itSays(tester, 'The ruleset is loaded either way');
    });
    testWidgets('''asking for the mode it is already in is not reported as a change''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'billing');
      await iSelectTheWork(tester, 'porelo-billing-audit');
      await iChangeWhatThisWorkDoesWithABlockedConnection(tester);
      await iChooseTo(tester, 'Stop asking entirely');
      await theStatusLineMentions(tester, 'was already doing that');
    });
    testWidgets('''work that is not running is not offered it''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-migrate');
      await iOpenTheCommandFinder(tester);
      await theCommandIsOfferedAsUnavailable(tester, 'Change what this work does with a blocked connection');
    });
  });
}
