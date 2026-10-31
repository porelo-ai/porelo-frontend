import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/registry.dart';

import '../support/host_registry.dart';

import 'package:porelo_frontend/src/ui/project_developers_dialog.dart';

import '../support/project_access.dart';

void main() {
  // Harm: recovery must remain reachable after authority changes, before mutation is allowed.
  for (final stage in ['filed', 'unfiled']) {
    testWidgets('Retry resolves a $stage receipt after the actor key changes', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = Settings(MemorySettingsStore());
      final fixture = ProjectAccessFixture();
      addTearDown(settings.dispose);
      addTearDown(fixture.registry.dispose);
      final access = await fixture.access(settings);
      fixture.fail = stage == 'filed' ? 'upload' : 'file-after-commit';
      if (stage == 'unfiled') {
        fixture.lookupFailureAfterFile = const FormatException('Core lookup unavailable');
      }
      await expectLater(access.register(), throwsFormatException);
      final id = settings.projectAccess('demo')!.change.id;
      fixture.fail = null;
      fixture.lookupFailure = null;
      fixture.lookupFailureAfterFile = null;
      fixture.actor = const HostAdminIdentity('alice', personFingerprint);
      // Core refuses what the old key signed; only its verdict supersedes the change.
      fixture.deliveryAuthorized = false;
      fixture.calls.clear();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectDevelopersDialog(project: 'demo', access: access),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final retry = find.widgetWithText(OutlinedButton, 'Retry project delivery');
      expect(tester.widget<OutlinedButton>(retry).onPressed, isNotNull);
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump();
      }
      expect(find.widgetWithText(OutlinedButton, 'Discard'), findsOneWidget);
      expect(access.supersededChangeId, id);
      expect(settings.projectAccess('demo')!.revision, fixture.filed[id]);
      expect(fixture.filed.keys, [id]);
      expect(fixture.calls, isEmpty);
    });
  }

  // Harm: a superseded signed change must be discardable without erasing confirmed work.
  testWidgets('a superseded receipt exposes Discard and releases only pending work', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = Settings(MemorySettingsStore());
    final fixture = ProjectAccessFixture();
    addTearDown(settings.dispose);
    addTearDown(fixture.registry.dispose);
    final access = await fixture.access(settings);
    await access.register();
    final confirmed = settings.projectRegistration('demo')!.stored;
    fixture.fail = 'upload';
    await expectLater(
      access.change(
        'demo',
        AccessDeveloper(login: 'bob', role: 'developer', fingerprint: personFingerprint),
        remove: false,
      ),
      throwsFormatException,
    );
    fixture.fail = null;
    fixture.currentAccess = 'c' * 40;
    // Core no longer authorizes the filed revision; only its verdict supersedes the change.
    fixture.deliveryAuthorized = false;
    await expectLater(access.retry(), throwsA(isA<RegistryRefusal>()));
    fixture.calls.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectDevelopersDialog(project: 'demo', access: access),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final discard = find.widgetWithText(OutlinedButton, 'Discard');
    expect(discard, findsOneWidget);
    await tester.ensureVisible(discard);
    await tester.tap(discard);
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump();
    }
    expect(settings.projectAccess('demo'), isNull);
    expect(settings.projectRegistration('demo')!.stored, confirmed);
    expect(fixture.calls, isEmpty);
  });

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
