import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/project_developers_dialog.dart';

import '../support/project_access.dart';

void main() {
  // Harm: a registry revocation must remove a selectable cached grant immediately.
  testWidgets('the open picker drops refused candidates after registry refresh', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = Settings(MemorySettingsStore());
    final fixture = ProjectAccessFixture();
    addTearDown(settings.dispose);
    addTearDown(fixture.registry.dispose);
    final access = await fixture.access(settings);
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDevelopersDialog(project: 'demo', access: access),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>)).items, hasLength(1));
    fixture.registrySource.refusedPerson = true;
    await fixture.registry.refresh();
    await tester.pump();
    expect(tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>)).items, isEmpty);
  });

  // Harm: the picker must send the selected scoped registry identity, never typed keys or another person.
  testWidgets('the registry picker publishes only the selected developer', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = Settings(MemorySettingsStore());
    final fixture = ProjectAccessFixture();
    addTearDown(settings.dispose);
    addTearDown(fixture.registry.dispose);
    final access = await fixture.access(settings);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectDevelopersDialog(project: 'demo', access: access),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Bob (bob)').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final add = find.widgetWithText(OutlinedButton, 'Add a developer');
    await tester.ensureVisible(add);
    await tester.tap(add);
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump();
    }
    expect(fixture.members.keys, ['bob']);
    expect(fixture.hostPeople, {
      'demo': {'bob': 'active'},
      'other': {'bob': 'active'},
    });
    expect(fixture.changes.values.single.person!.login, 'bob');
    expect(fixture.changes.values.single.person!.role, 'developer');
  });
}
