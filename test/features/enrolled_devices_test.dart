// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/enrolling_is_offered_in_the_machines_menu.dart';
import './step/the_title_bar_carries_no_enrolling.dart';
import './step/the_stores_lock_says.dart';
import './step/i_enroll_this_device_as.dart';
import './step/it_says.dart';
import './step/i_close_the_answer.dart';
import './step/i_show_the_vault.dart';
import './step/this_device_keeps_the_key_the_machine_was_given.dart';
import './step/enrolling_is_unavailable_in_the_machines_menu_because.dart';
import './step/i_begin_enrolling_this_device.dart';
import './step/the_key_this_device_keeps_is_nowhere_on_screen.dart';
import './step/the_store_is_shut.dart';
import './step/this_device_keeps_a_key_the_machine_no_longer_has_a_slot_for.dart';
import './step/the_machine_is_a_socket_somebody_else_forwards.dart';
import './step/the_stores_lock_does_nothing.dart';
import './step/i_shut_the_store.dart';
import './step/i_begin_opening_the_store_with_this_device.dart';
import './step/it_cannot_be_opened_until_a_length_is_chosen.dart';
import './step/i_open_the_store_with_this_device.dart';
import './step/the_machine_was_asked_to_open_it_for_minutes.dart';
import './step/the_machine_was_asked_to_open_it_without_a_bound.dart';
import './step/another_device_can_open_the_store.dart';
import './step/i_revoke.dart';
import './step/this_device_keeps_no_key_for_the_machine.dart';
import './step/the_recovery_passphrase_cannot_be_revoked_from_here.dart';
import './step/the_machine_cannot_enroll_devices_yet.dart';
import './step/i_shut_the_store_from_the_machines_menu.dart';
import './step/the_key_of_this_device_reached_the_machine_as_and_its_answer_did_not.dart';
import './step/the_machine_holds_devices.dart';
import './step/the_keystore_of_this_device_refuses_with.dart';
import './step/no_key_was_sent_to_the_machine.dart';
import './step/the_machine_refuses_enrolling_with.dart';
import './step/the_connection_goes_while_enrolling.dart';
import './step/this_device_keeps_a_key_for_the_machine.dart';
import './step/the_machine_takes_away_the_slot_of.dart';
import './step/i_begin_revoking.dart';
import './step/another_device_keeps_its_key.dart';

void main() {
  group('''Opening the store with an enrolled device, never with a passphrase''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
    }

    testWidgets('''a device that is not enrolled is offered enrolling in the machine's menu, not in the title''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await enrollingIsOfferedInTheMachinesMenu(tester);
      await theTitleBarCarriesNoEnrolling(tester);
      await theStoresLockSays(tester, 'The vault is open. Shut it.');
    });
    testWidgets('''enrolling keeps a key here and the machine lists this device''', (tester) async {
      await bddSetUp(tester);
      await iEnrollThisDeviceAs(tester, 'laptop');
      await itSays(tester, 'This device can open the vault now, as "laptop".');
      await iCloseTheAnswer(tester);
      await iShowTheVault(tester);
      await itSays(tester, 'laptop — this device');
      await thisDeviceKeepsTheKeyTheMachineWasGiven(tester);
      await enrollingIsUnavailableInTheMachinesMenuBecause(tester, 'enrolled already');
    });
    testWidgets('''before a device is enrolled, it says what its key is kept in''', (tester) async {
      await bddSetUp(tester);
      await iBeginEnrollingThisDevice(tester);
      await itSays(tester, 'anything running as this user can read it');
    });
    testWidgets('''the key itself is never on screen''', (tester) async {
      await bddSetUp(tester);
      await iEnrollThisDeviceAs(tester, 'laptop');
      await iCloseTheAnswer(tester);
      await iShowTheVault(tester);
      await theKeyThisDeviceKeepsIsNowhereOnScreen(tester);
    });
    testWidgets('''a key kept for a slot the machine no longer has is not taken for an enrollment''', (tester) async {
      await bddSetUp(tester);
      await theStoreIsShut(tester);
      await thisDeviceKeepsAKeyTheMachineNoLongerHasASlotFor(tester);
      await theStoresLockSays(tester, 'Shut. Open it with its passphrase, in a terminal on the machine');
      await enrollingIsUnavailableInTheMachinesMenuBecause(tester, 'the vault is shut');
    });
    testWidgets('''a shut store and a device that is not enrolled say where it is opened instead''', (tester) async {
      await bddSetUp(tester);
      await theStoreIsShut(tester);
      await theMachineIsASocketSomebodyElseForwards(tester);
      await theStoresLockSays(
        tester,
        'The vault is shut, and this device is not enrolled. Unlock it at the machine with `porelo vault unlock`, then enroll this device.',
      );
      await theStoresLockDoesNothing(tester);
      await enrollingIsUnavailableInTheMachinesMenuBecause(tester, 'the vault is shut');
    });
    testWidgets('''opening it asks how long, and chooses nothing for the person''', (tester) async {
      await bddSetUp(tester);
      await iEnrollThisDeviceAs(tester, 'laptop');
      await iCloseTheAnswer(tester);
      await iShutTheStore(tester);
      await iCloseTheAnswer(tester);
      await iBeginOpeningTheStoreWithThisDevice(tester);
      await itCannotBeOpenedUntilALengthIsChosen(tester);
    });
    testWidgets('''opening it for an hour asks the machine for sixty minutes, and it is open''', (tester) async {
      await bddSetUp(tester);
      await iEnrollThisDeviceAs(tester, 'laptop');
      await iCloseTheAnswer(tester);
      await iShutTheStore(tester);
      await iCloseTheAnswer(tester);
      await iOpenTheStoreWithThisDevice(tester, 'for an hour');
      await theMachineWasAskedToOpenItForMinutes(tester, 60);
      await itSays(tester, 'The vault is open until');
      await iCloseTheAnswer(tester);
      await theStoresLockSays(tester, 'The vault is open. Shut it.');
    });
    testWidgets('''opening it until it is shut asks for no bound''', (tester) async {
      await bddSetUp(tester);
      await iEnrollThisDeviceAs(tester, 'laptop');
      await iCloseTheAnswer(tester);
      await iShutTheStore(tester);
      await iCloseTheAnswer(tester);
      await iOpenTheStoreWithThisDevice(tester, 'until it is shut');
      await theMachineWasAskedToOpenItWithoutABound(tester);
    });
    testWidgets('''revoking another device keeps this one''', (tester) async {
      await bddSetUp(tester);
      await anotherDeviceCanOpenTheStore(tester, 'old phone');
      await iEnrollThisDeviceAs(tester, 'laptop');
      await iCloseTheAnswer(tester);
      await iShowTheVault(tester);
      await iRevoke(tester, 'old phone');
      await itSays(tester, '"old phone" can no longer open the vault.');
      await thisDeviceKeepsTheKeyTheMachineWasGiven(tester);
    });
    testWidgets('''revoking this device forgets its key here, and enrolling is offered again''', (tester) async {
      await bddSetUp(tester);
      await iEnrollThisDeviceAs(tester, 'laptop');
      await iCloseTheAnswer(tester);
      await iShowTheVault(tester);
      await iRevoke(tester, 'laptop');
      await thisDeviceKeepsNoKeyForTheMachine(tester);
      await enrollingIsOfferedInTheMachinesMenu(tester);
    });
    testWidgets('''the recovery passphrase is listed and cannot be revoked from here''', (tester) async {
      await bddSetUp(tester);
      await iShowTheVault(tester);
      await itSays(tester, 'The passphrase, used at the machine.');
      await theRecoveryPassphraseCannotBeRevokedFromHere(tester);
    });
    testWidgets('''a machine whose Porelo predates devices has the lock, and says why not enrolling''', (tester) async {
      await bddSetUp(tester);
      await theMachineCannotEnrollDevicesYet(tester);
      await theStoresLockSays(tester, 'The vault is open. Shut it.');
      await enrollingIsUnavailableInTheMachinesMenuBecause(tester, 'cannot enroll devices yet');
      await iShowTheVault(tester);
      await itSays(tester, 'that arrives with a later Porelo');
    });
    testWidgets('''the machine's menu shuts the store too''', (tester) async {
      await bddSetUp(tester);
      await theMachineIsASocketSomebodyElseForwards(tester);
      await iShutTheStoreFromTheMachinesMenu(tester);
      await itSays(tester, 'The vault is shut.');
      await iCloseTheAnswer(tester);
      await theStoresLockSays(
        tester,
        'The vault is shut, and this device is not enrolled. Unlock it at the machine with `porelo vault unlock`, then enroll this device.',
      );
    });
    testWidgets('''a key the machine already took is said as enrolled already, and makes no second slot''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theKeyOfThisDeviceReachedTheMachineAsAndItsAnswerDidNot(tester, 'desk');
      await iEnrollThisDeviceAs(tester, 'laptop');
      await itSays(tester, 'This device was enrolled already, as "desk".');
      await theMachineHoldsDevices(tester, 1);
    });
    testWidgets('''a keystore that refuses is said as that, and nothing is sent''', (tester) async {
      await bddSetUp(tester);
      await theKeystoreOfThisDeviceRefusesWith(tester, 'no Secret Service is running');
      await iEnrollThisDeviceAs(tester, 'laptop');
      await itSays(tester, 'keystore refused (no Secret Service is running)');
      await noKeyWasSentToTheMachine(tester);
    });
    testWidgets('''a machine that refuses the enrollment leaves no key here''', (tester) async {
      await bddSetUp(tester);
      await theMachineRefusesEnrollingWith(tester, 'VAULT_WITHOUT_KEYSLOTS');
      await iEnrollThisDeviceAs(tester, 'laptop');
      await itSays(tester, 'This machine has no vault that devices can open.');
      await thisDeviceKeepsNoKeyForTheMachine(tester);
    });
    testWidgets('''a connection lost while enrolling keeps the key, for the same key to be sent again''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theConnectionGoesWhileEnrolling(tester);
      await iEnrollThisDeviceAs(tester, 'laptop');
      await itSays(tester, 'Lost contact with the machine');
      await thisDeviceKeepsAKeyForTheMachine(tester);
    });
    testWidgets('''a device whose slot was taken away elsewhere is told so when it opens the store''', (tester) async {
      await bddSetUp(tester);
      await iEnrollThisDeviceAs(tester, 'laptop');
      await iCloseTheAnswer(tester);
      await iShutTheStore(tester);
      await iCloseTheAnswer(tester);
      await theMachineTakesAwayTheSlotOf(tester, 'laptop');
      await iOpenTheStoreWithThisDevice(tester, 'for an hour');
      await itSays(tester, 'it was revoked, or never enrolled on this machine');
    });
    testWidgets('''the list says of each device when it was enrolled and when it last opened the store''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await anotherDeviceCanOpenTheStore(tester, 'old phone');
      await iEnrollThisDeviceAs(tester, 'laptop');
      await iCloseTheAnswer(tester);
      await iShowTheVault(tester);
      await itSays(tester, 'Enrolled 2026-09-10, last used 2026-09-17.');
      await itSays(tester, 'Enrolled 2026-09-18, not used yet.');
    });
    testWidgets('''revoking this device says before it is done that this device will not open the store''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iEnrollThisDeviceAs(tester, 'laptop');
      await iCloseTheAnswer(tester);
      await iShowTheVault(tester);
      await iBeginRevoking(tester, 'laptop');
      await itSays(tester, 'This device will no longer open the vault, and forgets its key.');
    });
    testWidgets('''revoking another device names it before it is done''', (tester) async {
      await bddSetUp(tester);
      await anotherDeviceCanOpenTheStore(tester, 'old phone');
      await iShowTheVault(tester);
      await iBeginRevoking(tester, 'old phone');
      await itSays(tester, '"old phone" will no longer open the vault.');
    });
    testWidgets('''a key kept in a keyring that opens at login is said to be readable by this user''', (tester) async {
      await bddSetUp(tester);
      await anotherDeviceKeepsItsKey(tester, 'desk', 'USER_SCOPED');
      await iShowTheVault(tester);
      await itSays(tester, 'Kept in a keyring that opens at login: anything running as this user can read it.');
    });
    testWidgets('''a key only its application can read is said as that''', (tester) async {
      await bddSetUp(tester);
      await anotherDeviceKeepsItsKey(tester, 'phone', 'APPLICATION_SCOPED');
      await iShowTheVault(tester);
      await itSays(tester, 'Kept where only this application can read it.');
    });
    testWidgets('''a key released by a security key is said as that''', (tester) async {
      await bddSetUp(tester);
      await anotherDeviceKeepsItsKey(tester, 'token', 'FIDO2');
      await iShowTheVault(tester);
      await itSays(tester, 'Released only with a touch on a security key.');
    });
    testWidgets('''a key released by a TPM is said as that''', (tester) async {
      await bddSetUp(tester);
      await anotherDeviceKeepsItsKey(tester, 'server', 'TPM2');
      await iShowTheVault(tester);
      await itSays(tester, 'Released only with a PIN, by this machine');
    });
    testWidgets('''a way of keeping a key this build does not know claims nothing''', (tester) async {
      await bddSetUp(tester);
      await anotherDeviceKeepsItsKey(tester, 'future', 'ENCLAVE');
      await iShowTheVault(tester);
      await itSays(tester, 'Kept in a way this build cannot describe, so nothing is claimed for it.');
    });
    testWidgets('''the answer to enrolling says what the machine recorded''', (tester) async {
      await bddSetUp(tester);
      await iEnrollThisDeviceAs(tester, 'laptop');
      await itSays(tester, 'Recorded as slot-1. Kept in a keyring that opens at login');
    });
    testWidgets('''the answer to revoking says what can still open the store''', (tester) async {
      await bddSetUp(tester);
      await anotherDeviceCanOpenTheStore(tester, 'old phone');
      await iEnrollThisDeviceAs(tester, 'laptop');
      await iCloseTheAnswer(tester);
      await iShowTheVault(tester);
      await iRevoke(tester, 'old phone');
      await itSays(tester, 'Still able to open it: "laptop" and the passphrase, at the machine.');
    });
  });
}
