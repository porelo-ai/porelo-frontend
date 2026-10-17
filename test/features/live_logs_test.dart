// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_select_the_work.dart';
import './step/i_read_the_log.dart';
import './step/the_log_prints.dart';
import './step/the_log_shows.dart';
import './step/the_log_was_asked_from_its_last_lines.dart';
import './step/the_log_prints_lines_one_by_one.dart';
import './step/the_newest_line_is_in_view.dart';
import './step/the_log_prints_lines_at_once.dart';
import './step/the_log_keeps_lines.dart';
import './step/it_says.dart';
import './step/the_log_prints_a_line_of_characters.dart';
import './step/i_stop_following.dart';
import './step/the_log_is_not_being_followed.dart';
import './step/i_ask_which_logs_the_work_has.dart';
import './step/the_logs_offered_are.dart';
import './step/the_work_also_has_the_log.dart';
import './step/the_machine_says_the_log_holds.dart';
import './step/the_log_is_described_as.dart';
import './step/the_log_is_described_by_nothing.dart';
import './step/the_work_has_no_logs_left.dart';
import './step/it_says_it_has_no_logs.dart';
import './step/the_log_prints_a_red_line_saying.dart';
import './step/the_log_shows_no_escape_characters.dart';
import './step/the_log_ends.dart';

void main() {
  group('''Reading a task's logs as they are written''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
    }

    testWidgets(
        '''a log is read inside the interface, without dropping to another tool''',
        (tester) async {
      await bddSetUp(tester);
      await iReadTheLog(tester, 'agent.log');
      await theLogPrints(tester, 'building the image');
      await theLogShows(tester, 'building the image');
      await theLogWasAskedFromItsLastLines(tester, 1000);
    });
    testWidgets(
        '''a log written hard is drawn in bundles while followed, and stays at its end''',
        (tester) async {
      await bddSetUp(tester);
      await iReadTheLog(tester, 'agent.log');
      await theLogPrintsLinesOneByOne(tester, '400');
      await theNewestLineIsInView(tester, 'line 400 of a log written hard');
    });
    testWidgets(
        '''only the newest lines are kept, and the earlier ones are said to be on the machine''',
        (tester) async {
      await bddSetUp(tester);
      await iReadTheLog(tester, 'agent.log');
      await theLogPrintsLinesAtOnce(tester, '6000');
      await theLogKeepsLines(tester, '5000');
      await itSays(tester, 'The 1000 earlier lines are not kept here');
      await theNewestLineIsInView(tester, 'line 6000');
    });
    testWidgets(
        '''a line of tens of thousands of characters is drawn cut short, saying how much is left out''',
        (tester) async {
      await bddSetUp(tester);
      await iReadTheLog(tester, 'agent.log');
      await theLogPrintsALineOfCharacters(tester, '85000');
      await theLogShows(tester, '(83000 more characters)');
    });
    testWidgets(
        '''following can be suspended to read back, and nothing that arrives is lost''',
        (tester) async {
      await bddSetUp(tester);
      await iReadTheLog(tester, 'agent.log');
      await theLogPrints(tester, 'the first thing');
      await iStopFollowing(tester);
      await theLogPrints(tester, 'what arrived while reading back');
      await theLogIsNotBeingFollowed(tester);
      await theLogShows(tester, 'what arrived while reading back');
    });
    testWidgets('''only the logs the work actually has are offered''',
        (tester) async {
      await bddSetUp(tester);
      await iAskWhichLogsTheWorkHas(tester);
      await theLogsOfferedAre(tester, 'agent.log');
    });
    testWidgets(
        '''a log whose name is not a .log is offered and read like any other''',
        (tester) async {
      await bddSetUp(tester);
      await theWorkAlsoHasTheLog(tester, 'events.jsonl');
      await iAskWhichLogsTheWorkHas(tester);
      await theLogsOfferedAre(tester, 'agent.log, events.jsonl');
    });
    testWidgets(
        '''what the firewall blocked is readable, and it is the file a stuck task needs''',
        (tester) async {
      await bddSetUp(tester);
      await theWorkAlsoHasTheLog(tester, 'events.jsonl');
      await iReadTheLog(tester, 'events.jsonl');
      await theLogPrints(tester, 'deny registry.example.com:443');
      await theLogShows(tester, 'deny registry.example.com:443');
    });
    testWidgets(
        '''a log whose name does not say what it is arrives explained''',
        (tester) async {
      await bddSetUp(tester);
      await theWorkAlsoHasTheLog(tester, 'events.jsonl');
      await theMachineSaysTheLogHolds(
          tester, 'events.jsonl', 'what the firewall blocked');
      await iAskWhichLogsTheWorkHas(tester);
      await theLogIsDescribedAs(
          tester, 'events.jsonl', 'what the firewall blocked');
      await theLogIsDescribedByNothing(tester, 'agent.log');
    });
    testWidgets(
        '''work whose logs are gone says so rather than looking broken''',
        (tester) async {
      await bddSetUp(tester);
      await theWorkHasNoLogsLeft(tester);
      await iAskWhichLogsTheWorkHas(tester);
      await itSaysItHasNoLogs(tester);
    });
    testWidgets(
        '''color an agent wrote is rendered, never shown as escape characters''',
        (tester) async {
      await bddSetUp(tester);
      await iReadTheLog(tester, 'agent.log');
      await theLogPrintsARedLineSaying(tester, 'it went wrong');
      await theLogShows(tester, 'it went wrong');
      await theLogShowsNoEscapeCharacters(tester);
    });
    testWidgets('''the log of finished work is still readable after it ends''',
        (tester) async {
      await bddSetUp(tester);
      await iReadTheLog(tester, 'agent.log');
      await theLogPrints(tester, 'the last thing it said');
      await theLogEnds(tester);
      await theLogShows(tester, 'the last thing it said');
    });
  });
}
