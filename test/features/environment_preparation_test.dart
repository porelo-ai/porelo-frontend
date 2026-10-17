// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_build_the_environment_for_this_project.dart';
import './step/i_choose_to_build.dart';
import './step/the_build_asked_for.dart';
import './step/nothing_was_started.dart';
import './step/it_says.dart';
import './step/the_operation_shows.dart';
import './step/i_close_what_is_open.dart';
import './step/the_project_is_listed.dart';
import './step/the_next_build_will_fail.dart';
import './step/i_show_what_this_session_has_run.dart';
import './step/the_record_marks_it_as_failed.dart';
import './step/i_open_the_command_finder.dart';
import './step/the_command_is_offered_as_unavailable.dart';

void main() {
  group('''Building a project's environment, and watching it run''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
    }

    testWidgets('''an environment is built without starting anything''', (tester) async {
      await bddSetUp(tester);
      await iBuildTheEnvironmentForThisProject(tester);
      await iChooseToBuild(tester, 'what changed');
      await theBuildAskedFor(tester, 'CACHED');
      await nothingWasStarted(tester);
    });
    testWidgets('''the depths say what each replaces and roughly what it costs''', (tester) async {
      await bddSetUp(tester);
      await iBuildTheEnvironmentForThisProject(tester);
      await itSays(tester, 'Keeps the base image and the packages on it');
      await itSays(tester, 'Roughly a minute or two.');
      await itSays(tester, 'Throws away the packages on the base image as well');
      await itSays(tester, 'Roughly several minutes, and it downloads.');
    });
    testWidgets('''the deepest rebuild is asked for as itself''', (tester) async {
      await bddSetUp(tester);
      await iBuildTheEnvironmentForThisProject(tester);
      await iChooseToBuild(tester, 'everything');
      await theBuildAskedFor(tester, 'EVERYTHING');
    });
    testWidgets('''progress is visible while it runs, and the frame stays usable''', (tester) async {
      await bddSetUp(tester);
      await iBuildTheEnvironmentForThisProject(tester);
      await iChooseToBuild(tester, 'what changed');
      await theOperationShows(tester, 'STEP 4/6: RUN apt-get install -y git');
      await iCloseWhatIsOpen(tester);
      await theProjectIsListed(tester, 'checkout');
    });
    testWidgets('''a build that fails names the step, and it is still readable afterwards''', (tester) async {
      await bddSetUp(tester);
      await theNextBuildWillFail(tester);
      await iBuildTheEnvironmentForThisProject(tester);
      await iChooseToBuild(tester, 'what changed');
      await itSays(tester, 'STEP 4/6: RUN apt-get install -y git returned 100');
      await iShowWhatThisSessionHasRun(tester);
      await theRecordMarksItAsFailed(tester);
    });
    testWidgets('''a project whose file nothing can find says why it cannot be built''', (tester) async {
      await bddSetUp(tester);
      await iSelectTheProject(tester, 'unrecorded');
      await iOpenTheCommandFinder(tester);
      await theCommandIsOfferedAsUnavailable(tester, 'Build the environment for this project');
    });
  });
}
