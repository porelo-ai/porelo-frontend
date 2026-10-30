// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_developer_settings_list_an_existing_developer.dart';
import './step/i_cancel_the_developer_removal.dart';
import './step/no_developer_access_change_has_been_requested.dart';
import './step/i_confirm_the_developer_removal.dart';
import './step/removal_was_requested_for_the_selected_developer.dart';
import './step/i_paste_a_private_key_at_the_developer_laptop_step.dart';
import './step/the_developer_public_key_field_contains_no_private_key.dart';
import './step/i_review_a_new_developer_with_two_laptops.dart';
import './step/i_publish_the_reviewed_developer.dart';
import './step/the_requested_developer_has_both_public_laptops.dart';

void main() {
  group('''Developer access changes require review''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theDeveloperSettingsListAnExistingDeveloper(tester);
    }

    testWidgets('''canceling a developer removal keeps access''', (tester) async {
      await bddSetUp(tester);
      await iCancelTheDeveloperRemoval(tester);
      await noDeveloperAccessChangeHasBeenRequested(tester);
    });
    testWidgets('''confirming a developer removal acts on that account''', (tester) async {
      await bddSetUp(tester);
      await iConfirmTheDeveloperRemoval(tester);
      await removalWasRequestedForTheSelectedDeveloper(tester);
    });
    testWidgets('''private key input never leaves the public key step''', (tester) async {
      await bddSetUp(tester);
      await iPasteAPrivateKeyAtTheDeveloperLaptopStep(tester);
      await theDeveloperPublicKeyFieldContainsNoPrivateKey(tester);
      await noDeveloperAccessChangeHasBeenRequested(tester);
    });
    testWidgets('''public laptop keys are reviewed before publication''', (tester) async {
      await bddSetUp(tester);
      await iReviewANewDeveloperWithTwoLaptops(tester);
      await noDeveloperAccessChangeHasBeenRequested(tester);
      await iPublishTheReviewedDeveloper(tester);
      await theRequestedDeveloperHasBothPublicLaptops(tester);
    });
  });
}
