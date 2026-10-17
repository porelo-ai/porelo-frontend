// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_show_the_agents_installed_here.dart';
import './step/it_lists_the_agent.dart';
import './step/it_says.dart';
import './step/i_open_the_agent.dart';
import './step/it_shows_the_host.dart';
import './step/one_agent_on_the_machine_cannot_be_read.dart';
import './step/it_lists_the_unusable_agent.dart';
import './step/the_machine_has_no_agents.dart';
import './step/it_shows_the_refused_host.dart';
import './step/it_shows_the_digest.dart';
import './step/the_agent_fetches_nothing.dart';
import './step/one_agent_is_shadowed_by_another_copy.dart';
import './step/it_lists_the_unused_copy.dart';

void main() {
  group('''Listing the agents a machine has, and what each one may reach''',
      () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets(
        '''every installed agent is listed with its version and where it was found''',
        (tester) async {
      await bddSetUp(tester);
      await iShowTheAgentsInstalledHere(tester);
      await itListsTheAgent(tester, 'An Agent');
      await itSays(tester, '2.4.0');
      await iOpenTheAgent(tester, 'An Agent');
      await itSays(tester, '/usr/share/porelo/agents/an-agent.yml');
    });
    testWidgets(
        '''an agent that reports no version says so rather than showing a blank''',
        (tester) async {
      await bddSetUp(tester);
      await iShowTheAgentsInstalledHere(tester);
      await itSays(tester, 'version not reported');
    });
    testWidgets('''what an agent needs to reach is shown with it''',
        (tester) async {
      await bddSetUp(tester);
      await iShowTheAgentsInstalledHere(tester);
      await iOpenTheAgent(tester, 'An Agent');
      await itShowsTheHost(tester, 'api.anthropic.com');
    });
    testWidgets(
        '''an agent that could not describe itself is listed, not left out''',
        (tester) async {
      await bddSetUp(tester);
      await oneAgentOnTheMachineCannotBeRead(tester);
      await iShowTheAgentsInstalledHere(tester);
      await itListsTheUnusableAgent(tester, 'broken-agent');
    });
    testWidgets(
        '''a machine with nothing installed says so, as a state rather than a failure''',
        (tester) async {
      await bddSetUp(tester);
      await theMachineHasNoAgents(tester);
      await iShowTheAgentsInstalledHere(tester);
      await itSays(tester, 'That is a state, not a failure');
    });
    testWidgets(
        '''what an agent is deliberately refused is shown beside what it may reach''',
        (tester) async {
      await bddSetUp(tester);
      await iShowTheAgentsInstalledHere(tester);
      await iOpenTheAgent(tester, 'An Agent');
      await itShowsTheRefusedHost(tester, 'telemetry.example.test');
      await itSays(tester, 'deliberately not given');
    });
    testWidgets('''the pinned build and its digest are shown''',
        (tester) async {
      await bddSetUp(tester);
      await iShowTheAgentsInstalledHere(tester);
      await iOpenTheAgent(tester, 'An Agent');
      await itSays(tester, '2.4.0');
      await itShowsTheDigest(tester,
          '3b1f8e2a9c4d5067a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718');
    });
    testWidgets(
        '''a fetch nobody can check says why, rather than showing a blank''',
        (tester) async {
      await bddSetUp(tester);
      await iShowTheAgentsInstalledHere(tester);
      await iOpenTheAgent(tester, 'Another Agent');
      await itSays(
          tester, 'Not checked, on purpose: upstream publishes no digest');
    });
    testWidgets(
        '''an agent that fetches nothing says so, rather than showing an empty list''',
        (tester) async {
      await bddSetUp(tester);
      await theAgentFetchesNothing(tester, 'An Agent');
      await iShowTheAgentsInstalledHere(tester);
      await iOpenTheAgent(tester, 'An Agent');
      await itSays(tester, 'It writes its tool into the image');
    });
    testWidgets(
        '''a copy that is installed and never used names the one that runs instead''',
        (tester) async {
      await bddSetUp(tester);
      await oneAgentIsShadowedByAnotherCopy(tester);
      await iShowTheAgentsInstalledHere(tester);
      await itListsTheUnusedCopy(tester, '/usr/libexec/porelo/agents/an-agent');
      await itSays(tester, 'runs instead');
    });
    testWidgets('''an agent says who its commits are attributed to''',
        (tester) async {
      await bddSetUp(tester);
      await iShowTheAgentsInstalledHere(tester);
      await iOpenTheAgent(tester, 'An Agent');
      await itSays(tester, 'An Agent <an-agent@porelo.invalid>');
    });
    testWidgets(
        '''an agent installed before that was reported says so rather than showing a blank''',
        (tester) async {
      await bddSetUp(tester);
      await iShowTheAgentsInstalledHere(tester);
      await iOpenTheAgent(tester, 'Another Agent');
      await itSays(tester, 'not recorded — installed before this was reported');
    });
  });
}
