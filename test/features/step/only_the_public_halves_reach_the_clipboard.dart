import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:yaml/yaml.dart';

import 'a_laptop_key_copy_dialog.dart';
import '../support/world.dart';

Future<void> onlyThePublicHalvesReachTheClipboard(WidgetTester tester) async {
  expect(laptopCopiedKeys, hasLength(2));
  expect(laptopCopiedKeys[1], laptopCopiedKeys[0]);
  final block = loadYaml(laptopCopiedKeys.first) as Map;
  expect(block.keys.toSet(), {'ssh_public_key', 'wireguard_public_key'});
  checkedEd25519(block['ssh_public_key'] as String);
  checkWireGuardPublicKey(block['wireguard_public_key'] as String);
  expect(
    laptopCopyStore.values.values.every((secret) => !laptopCopiedKeys.first.contains(secret)),
    isTrue,
    reason: 'neither private half may enter the clipboard',
  );
  await tester.tap(find.text('Close'));
  await World.settle(tester);
  await tester.pumpWidget(const SizedBox.shrink());
}
