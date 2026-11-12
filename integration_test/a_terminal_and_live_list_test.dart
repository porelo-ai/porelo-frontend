// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './step/the_interface_is_running.dart';
import './step/the_test_machine_has_an_open_vault.dart';
import './step/the_test_machine_has_porelos_stub_agent.dart';
import './step/work_of_the_stub_agent_waits_for_input_on_the_test_machine.dart';
import './step/i_work_in_that_work_by_hand_from_the_interface.dart';
import './step/i_type_into_the_terminal_of_the_work.dart';
import './step/i_paste_into_the_terminal_of_the_work.dart';
import './step/i_type_and_erase_it_with_ctrlu_before_in_the_terminal_of_the_work.dart';
import './step/the_work_received_each_line_whole_and_unchanged.dart';
import './step/i_run_task_list_watch_in_a_terminal_on_the_machine_beside_it.dart';
import './step/the_watch_shows_the_work_as_porelo_lists_it.dart';
import './step/the_work_reaches_a_host_its_project_did_not_declare.dart';
import './step/the_watch_names_the_clearance_question_of_the_work.dart';
import './step/i_end_the_agent_of_the_work_with_ctrld_in_its_terminal.dart';
import './step/the_watch_shows_the_work_ended_as_porelo_lists_it.dart';
import './step/i_press_ctrlc_in_the_watch.dart';
import './step/the_terminal_gives_an_ordinary_prompt_back.dart';
import './step/the_work_of_the_stub_agent_and_its_project_are_removed_again.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''A terminal in the window and the live list beside it''', () {
    testWidgets('''input reaches the work whole, the watch follows it, and Ctrl-C gives the terminal back''', (
      tester,
    ) async {
      await theInterfaceIsRunning(tester);
      await theTestMachineHasAnOpenVault(tester);
      await theTestMachineHasPorelosStubAgent(tester);
      await workOfTheStubAgentWaitsForInputOnTheTestMachine(tester);
      await iWorkInThatWorkByHandFromTheInterface(tester);
      await iTypeIntoTheTerminalOfTheWork(tester, 'Grüße von Zoë, mit Ångström und Leerzeichen');
      await iPasteIntoTheTerminalOfTheWork(tester, 'erste Zeile|zweite Zeile mit ä|dritte Zeile');
      await iTypeAndEraseItWithCtrluBeforeInTheTerminalOfTheWork(tester, 'falsch', 'richtig');
      await theWorkReceivedEachLineWholeAndUnchanged(tester);
      await iRunTaskListWatchInATerminalOnTheMachineBesideIt(tester);
      await theWatchShowsTheWorkAsPoreloListsIt(tester);
      await theWorkReachesAHostItsProjectDidNotDeclare(tester);
      await theWatchNamesTheClearanceQuestionOfTheWork(tester);
      await iEndTheAgentOfTheWorkWithCtrldInItsTerminal(tester);
      await theWatchShowsTheWorkEndedAsPoreloListsIt(tester);
      await iPressCtrlcInTheWatch(tester);
      await theTerminalGivesAnOrdinaryPromptBack(tester);
      await theWorkOfTheStubAgentAndItsProjectAreRemovedAgain(tester);
    });
  });
}
