import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';

import '../support/world.dart';

/// Usage: the forge lists my signing keys {'Laptop'} and {'Desktop'}
///
/// The first is the key the person's agent holds; the second is one from another computer.
Future<void> theForgeListsMySigningKeysAnd(WidgetTester tester, String first, String second) async {
  World.forge.signing = <ForgeSigningKey>[
    ForgeSigningKey(title: first, key: 'ssh-ed25519 AAAAperson'),
    ForgeSigningKey(title: second, key: 'ssh-ed25519 AAAAdesktop'),
  ];
}
