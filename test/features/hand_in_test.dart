// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_backend_with_work_on_it.dart';
import './step/this_machine_takes_files_handed_to_work_up_to_bytes.dart';
import './step/the_app_is_running.dart';
import './step/i_go_to_the_work.dart';
import './step/i_select_the_project.dart';
import './step/i_select_the_work.dart';
import './step/a_file_of_bytes_is_picked.dart';
import './step/i_choose_from_the_menu_of_the_tile.dart';
import './step/the_file_is_read_and_sent.dart';
import './step/the_status_line_mentions.dart';
import './step/i_open_the_selection.dart';
import './step/it_says.dart';
import './step/the_machine_will_keep_the_parts_but_never_place_the_file.dart';
import './step/it_does_not_say.dart';
import './step/no_part_was_sent.dart';
import './step/the_machine_will_lose_the_reply_to_the_next_part.dart';
import './step/the_parts_sent_started_at.dart';
import './step/the_file_arrived_whole.dart';
import './step/the_machine_will_refuse_the_next_file_with.dart';
import './step/i_choose.dart';
import './step/the_work_was_handed_by_porelo.dart';
import './step/this_machine_cannot_hand_files_to_work.dart';
import './step/i_open_the_actions_for.dart';
import './step/the_action_is_offered_as_unavailable.dart';

void main() {
  group('''Handing a file to running work, taking it back, and its record''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aBackendWithWorkOnIt(tester);
      await thisMachineTakesFilesHandedToWorkUpToBytes(tester, 8388608);
      await theAppIsRunning(tester);
      await iGoToTheWork(tester);
      await iSelectTheProject(tester, 'checkout');
      await iSelectTheWork(tester, 'porelo-checkout-shell');
    }

    testWidgets('''a file handed in is listed with its size and who handed it in''', (tester) async {
      await bddSetUp(tester);
      await aFileOfBytesIsPicked(tester, 'notes.txt', 300);
      await iChooseFromTheMenuOfTheTile(tester, 'Hand it a file from this computer', 'porelo-checkout-shell');
      await theFileIsReadAndSent(tester);
      await theStatusLineMentions(tester, 'notes.txt is in porelo-checkout-shell now');
      await iOpenTheSelection(tester);
      await itSays(tester, 'notes.txt, 300 bytes, by somebody');
      await itSays(tester, 'notes.txt given by somebody');
    });
    testWidgets('''a file the machine never places is not shown as handed in''', (tester) async {
      await bddSetUp(tester);
      await aFileOfBytesIsPicked(tester, 'notes.txt', 300);
      await theMachineWillKeepThePartsButNeverPlaceTheFile(tester);
      await iChooseFromTheMenuOfTheTile(tester, 'Hand it a file from this computer', 'porelo-checkout-shell');
      await theFileIsReadAndSent(tester);
      await theStatusLineMentions(tester, 'placed nothing');
      await iOpenTheSelection(tester);
      await itDoesNotSay(tester, 'notes.txt, 300 bytes');
    });
    testWidgets('''a file larger than the work takes is refused before anything is sent''', (tester) async {
      await bddSetUp(tester);
      await aFileOfBytesIsPicked(tester, 'big.bin', 9000000);
      await iChooseFromTheMenuOfTheTile(tester, 'Hand it a file from this computer', 'porelo-checkout-shell');
      await theFileIsReadAndSent(tester);
      await theStatusLineMentions(tester, 'takes at most 8 MiB. Nothing was sent.');
      await noPartWasSent(tester);
    });
    testWidgets('''a transfer cut off goes on where the machine says, not from the start''', (tester) async {
      await bddSetUp(tester);
      await aFileOfBytesIsPicked(tester, 'cut.bin', 2500000);
      await theMachineWillLoseTheReplyToTheNextPart(tester);
      await iChooseFromTheMenuOfTheTile(tester, 'Hand it a file from this computer', 'porelo-checkout-shell');
      await theFileIsReadAndSent(tester);
      await thePartsSentStartedAt(tester, '0, 0, 1048576, 2097152');
      await theFileArrivedWhole(tester, 'cut.bin');
    });
    testWidgets(
      '''Outline: a refusal says what to do about it, in its own words ('NotRunning', 'a file goes only to running work')''',
      (tester) async {
        await bddSetUp(tester);
        await aFileOfBytesIsPicked(tester, 'notes.txt', 300);
        await theMachineWillRefuseTheNextFileWith(tester, 'NotRunning');
        await iChooseFromTheMenuOfTheTile(tester, 'Hand it a file from this computer', 'porelo-checkout-shell');
        await theFileIsReadAndSent(tester);
        await theStatusLineMentions(tester, 'a file goes only to running work');
      },
    );
    testWidgets(
      '''Outline: a refusal says what to do about it, in its own words ('FileNameRefused', 'Hand it in under another name')''',
      (tester) async {
        await bddSetUp(tester);
        await aFileOfBytesIsPicked(tester, 'notes.txt', 300);
        await theMachineWillRefuseTheNextFileWith(tester, 'FileNameRefused');
        await iChooseFromTheMenuOfTheTile(tester, 'Hand it a file from this computer', 'porelo-checkout-shell');
        await theFileIsReadAndSent(tester);
        await theStatusLineMentions(tester, 'Hand it in under another name');
      },
    );
    testWidgets(
      '''Outline: a refusal says what to do about it, in its own words ('HandInInProgress', 'Wait for it, or hand this one in under another name')''',
      (tester) async {
        await bddSetUp(tester);
        await aFileOfBytesIsPicked(tester, 'notes.txt', 300);
        await theMachineWillRefuseTheNextFileWith(tester, 'HandInInProgress');
        await iChooseFromTheMenuOfTheTile(tester, 'Hand it a file from this computer', 'porelo-checkout-shell');
        await theFileIsReadAndSent(tester);
        await theStatusLineMentions(tester, 'Wait for it, or hand this one in under another name');
      },
    );
    testWidgets(
      '''Outline: a refusal says what to do about it, in its own words ('FileDiffers', 'nothing was placed. Hand it in again')''',
      (tester) async {
        await bddSetUp(tester);
        await aFileOfBytesIsPicked(tester, 'notes.txt', 300);
        await theMachineWillRefuseTheNextFileWith(tester, 'FileDiffers');
        await iChooseFromTheMenuOfTheTile(tester, 'Hand it a file from this computer', 'porelo-checkout-shell');
        await theFileIsReadAndSent(tester);
        await theStatusLineMentions(tester, 'nothing was placed. Hand it in again');
      },
    );
    testWidgets('''a file taken back is gone, and the record keeps both''', (tester) async {
      await bddSetUp(tester);
      await aFileOfBytesIsPicked(tester, 'brief.txt', 40);
      await iChooseFromTheMenuOfTheTile(tester, 'Hand it a file from this computer', 'porelo-checkout-shell');
      await theFileIsReadAndSent(tester);
      await iChooseFromTheMenuOfTheTile(tester, 'Take back a file it was handed', 'porelo-checkout-shell');
      await iChoose(tester, 'brief.txt, 40 bytes, by somebody');
      await theStatusLineMentions(tester, 'brief.txt is out of porelo-checkout-shell again');
      await iOpenTheSelection(tester);
      await itSays(tester, 'nothing, under /porelo/files');
      await itSays(tester, 'brief.txt taken back by somebody');
    });
    testWidgets('''what Porelo hands in itself reads as Porelo's, never as a person's''', (tester) async {
      await bddSetUp(tester);
      await theWorkWasHandedByPorelo(tester, 'porelo-checkout-shell', 'verdict.json');
      await iOpenTheSelection(tester);
      await itSays(tester, 'verdict.json, 120 bytes, by Porelo');
    });
    testWidgets('''a machine without hand-in offers it as unavailable, with why''', (tester) async {
      await bddSetUp(tester);
      await thisMachineCannotHandFilesToWork(tester);
      await iOpenTheActionsFor(tester, 'porelo-checkout-shell');
      await theActionIsOfferedAsUnavailable(tester, 'Hand it a file from this computer');
    });
    testWidgets('''a machine without hand-in shows no files, rather than none''', (tester) async {
      await bddSetUp(tester);
      await thisMachineCannotHandFilesToWork(tester);
      await iOpenTheSelection(tester);
      await itDoesNotSay(tester, 'Handed in');
    });
  });
}
