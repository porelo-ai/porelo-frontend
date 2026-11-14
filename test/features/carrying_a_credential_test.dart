// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/a_host_that_carries_credentials.dart';
import './step/i_switch_to_the_machine.dart';
import './step/i_show_what_this_machine_can_authenticate_against.dart';
import './step/the_vault_here_holds_of_kind.dart';
import './step/it_says.dart';
import './step/i_open_the_provider.dart';
import './step/i_import_from_this_computer.dart';
import './step/i_pick_to_carry.dart';
import './step/i_press.dart';
import './step/the_carry_says.dart';
import './step/the_host_holds_of_kind.dart';
import './step/the_agent_here_is_signed_in_to_as.dart';
import './step/this_computer_sealed_what_holds_for.dart';
import './step/the_host_already_holds_of_kind.dart';

void main() {
  group('''Carrying a credential from this computer to a host''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await aHostThatCarriesCredentials(tester, 'elsewhere');
      await iSwitchToTheMachine(tester, 'elsewhere');
      await iShowWhatThisMachineCanAuthenticateAgainst(tester);
    }

    testWidgets('''an entry of the vault here is carried, and the host reads its provider as authenticated''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theVaultHereHoldsOfKind(tester, 'an-agent', 'oauth');
      await itSays(tester, 'other-provider · not authenticated');
      await iOpenTheProvider(tester, 'Another Provider');
      await iImportFromThisComputer(tester, 'other-provider');
      await iPickToCarry(tester, 'vault an-agent');
      await iPress(tester, 'Carry to elsewhere');
      await theCarrySays(tester, 'Carried: the host holds it as an-agent');
      await theHostHoldsOfKind(tester, 'an-agent', 'oauth');
      await iPress(tester, 'Close');
      await itSays(tester, 'other-provider · authenticated');
    });
    testWidgets('''the sign-in an agent here holds is carried, and the host reads its provider as authenticated''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theAgentHereIsSignedInToAs(tester, 'an-agent', 'other-provider', 'oauth');
      await itSays(tester, 'other-provider · not authenticated');
      await iOpenTheProvider(tester, 'Another Provider');
      await iImportFromThisComputer(tester, 'other-provider');
      await iPickToCarry(tester, 'agent an-agent');
      await iPress(tester, 'Carry to elsewhere');
      await theCarrySays(tester, 'Carried: the host holds it as an-agent');
      await thisComputerSealedWhatHoldsFor(tester, 'an-agent', 'other-provider');
      await theHostHoldsOfKind(tester, 'an-agent', 'oauth');
      await iPress(tester, 'Close');
      await itSays(tester, 'other-provider · authenticated');
    });
    testWidgets('''what the host already holds is kept until replacing it is asked for''', (tester) async {
      await bddSetUp(tester);
      await theHostAlreadyHoldsOfKind(tester, 'an-agent', 'api-key');
      await theVaultHereHoldsOfKind(tester, 'an-agent', 'oauth');
      await iOpenTheProvider(tester, 'Another Provider');
      await iImportFromThisComputer(tester, 'other-provider');
      await iPickToCarry(tester, 'vault an-agent');
      await iPress(tester, 'Carry to elsewhere');
      await theCarrySays(tester, 'The host already holds an-agent and kept it');
      await theHostHoldsOfKind(tester, 'an-agent', 'api-key');
      await iPress(tester, 'Replace it on the host');
      await theCarrySays(tester, 'Carried: the host holds it as an-agent');
      await theHostHoldsOfKind(tester, 'an-agent', 'oauth');
    });
  });
}
