// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_select_the_work.dart';
import './step/no_forge_follows_the_builds_of.dart';
import './step/i_open_the_selection.dart';
import './step/it_does_not_say.dart';
import './step/the_builds_of_are_read_from.dart';
import './step/a_tile_says.dart';
import './step/the_build_of_is.dart';
import './step/it_says.dart';
import './step/the_build_of_failed_in_of_jobs.dart';
import './step/the_build_of_is_unknown_because.dart';
import './step/that_reader_does_not_work_because.dart';

void main() {
  group('''What the build of the work's push did, as the machine reads it''',
      () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
    }

    testWidgets('''work no forge follows says nothing about builds''',
        (tester) async {
      await bddSetUp(tester);
      await noForgeFollowsTheBuildsOf(tester, 'porelo-checkout-shell');
      await iOpenTheSelection(tester);
      await itDoesNotSay(tester, 'Builds');
    });
    testWidgets(
        '''a machine older than builds says nothing about them, rather than none''',
        (tester) async {
      await bddSetUp(tester);
      await iOpenTheSelection(tester);
      await itDoesNotSay(tester, 'Builds');
      await itDoesNotSay(tester, 'no push yet');
    });
    testWidgets('''a followed task with nothing pushed yet says so''',
        (tester) async {
      await bddSetUp(tester);
      await theBuildsOfAreReadFrom(tester, 'porelo-checkout-shell', 'github');
      await aTileSays(tester, 'No build yet');
      await aTileSays(tester, 'no push yet; its builds are read from github');
    });
    testWidgets('''a build underway lists no jobs yet''', (tester) async {
      await bddSetUp(tester);
      await theBuildsOfAreReadFrom(tester, 'porelo-checkout-shell', 'github');
      await theBuildOfIs(tester, '0123456789abcdef0123', 'running');
      await aTileSays(tester, 'Build running');
      await iOpenTheSelection(tester);
      await itSays(tester, 'no jobs yet');
    });
    testWidgets(
        '''a failed build lists every job, and the log of the one that failed''',
        (tester) async {
      await bddSetUp(tester);
      await theBuildsOfAreReadFrom(tester, 'porelo-checkout-shell', 'github');
      await theBuildOfFailedInOfJobs(
          tester, '0123456789abcdef0123', 'Build / unit tests', 3);
      await aTileSays(tester, 'Build failed');
      await aTileSays(tester, '0123456789ab · 3 jobs, 1 failed');
      await iOpenTheSelection(tester);
      await itSays(tester,
          'Build / unit tests: failure, log in /porelo/files/build-0123456789ab-1.log');
      await itSays(tester, 'Job 2: success, no log here');
    });
    testWidgets('''a verdict the machine could not get says why''',
        (tester) async {
      await bddSetUp(tester);
      await theBuildsOfAreReadFrom(tester, 'porelo-checkout-shell', 'github');
      await theBuildOfIsUnknownBecause(
          tester, '0123456789abcdef0123', 'the vault is shut');
      await aTileSays(tester, '0123456789ab · the vault is shut');
    });
    testWidgets(
        '''a verdict or a result this interface does not know is shown as it comes''',
        (tester) async {
      await bddSetUp(tester);
      await theBuildsOfAreReadFrom(tester, 'porelo-checkout-shell', 'github');
      await theBuildOfIs(tester, '0123456789abcdef0123', 'waiting_for_runner');
      await aTileSays(tester, 'Build: waiting_for_runner');
    });
    testWidgets(
        '''a reader that does not work is said, whatever the builds hold''',
        (tester) async {
      await bddSetUp(tester);
      await theBuildsOfAreReadFrom(tester, 'porelo-checkout-shell', 'github');
      await thatReaderDoesNotWorkBecause(tester, 'not installed');
      await aTileSays(tester, 'Builds not followed');
      await aTileSays(tester, 'not installed');
    });
  });
}
