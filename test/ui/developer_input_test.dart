import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/support/developer_settings.dart';
import '../features/support/world.dart';

void main() {
  // Harm: quoted or flow YAML secrets and unfinished commented keys must not enter the public form.
  testWidgets('unsupported public key blocks are refused before their values appear', (tester) async {
    await openDeveloperFixture(tester);
    await developerLaptopStep(tester);
    for (final block in [
      '"token": sensitive-fixture',
      '{token: sensitive-fixture}',
      'ssh_public_key: "$developerSsh laptop-comment"',
      'ssh_public_key: "$developerSsh"\nwireguard_private_key: "$developerWg"',
    ]) {
      await tester.enterText(find.byKey(const Key('developer-public-keys')), block);
      await World.settle(tester);
      expect(tester.widget<TextField>(find.byKey(const Key('developer-public-keys'))).controller!.text, isEmpty);
      expect(find.textContaining('sensitive-fixture'), findsNothing);
      expect(find.textContaining('laptop-comment'), findsNothing);
    }
    expect(developerSettings.additions, isEmpty);
  });
}
