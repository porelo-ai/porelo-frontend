// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_laptop_key_copy_dialog.dart';
import './step/i_copy_my_public_keys_twice_for.dart';
import './step/only_the_public_halves_reach_the_clipboard.dart';

void main() {
  group('''Sharing this laptop's public host keys''', () {
    testWidgets('''copying again keeps the same host identity and exports no private half''', (tester) async {
      await aLaptopKeyCopyDialog(tester);
      await iCopyMyPublicKeysTwiceFor(tester, 'orchard');
      await onlyThePublicHalvesReachTheClipboard(tester);
    });
  });
}
