import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/ui/project_developers_dialog.dart';

import '../features/support/developer_settings.dart';
import '../features/support/world.dart';

void main() {
  // Harm: opening Add on an exhausted network must not crash the settings dialog.
  testWidgets('a full VPN network refuses another developer without a crash', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = DeveloperSettingsFixture();
    addTearDown(model.dispose);
    model.listed = parseAccessDevelopers('''host: {network: 10.77.0.0/30, ssh_host_key: "$developerSsh"}
developers:
  alice:
    laptops:
      - ssh_public_key: "$developerSsh"
        wireguard_public_key: "$developerWg"
        vpn_address: 10.77.0.2
''');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProjectDevelopersDialog(developers: model)),
      ),
    );
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('developers.add')));
    await World.settle(tester);
    expect(tester.takeException(), isNull, reason: 'allocation failure must remain a refusal in settings');
    expect(model.additions, isEmpty);
    expect(tester.widget<TextButton>(find.byKey(const Key('developers.add'))).onPressed, isNull);
  });
}
