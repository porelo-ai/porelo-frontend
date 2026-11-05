import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/host_preparation_settings.dart';
import 'package:porelo_host/porelo_host.dart';

void main() {
  // Harm: invalid limits reach setup or host service ports override the person's local choices.
  testWidgets('More settings accepts runner limits and distinct local ports only', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final choices = <HostPreparationSettings>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HostPreparationSettingsForm(value: const HostPreparationSettings(), onChanged: choices.add),
          ),
        ),
      ),
    );
    await tester.tap(find.text('More settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byKey(const Key('forge_runner_capacity')), '0');
    await tester.ensureVisible(find.text('Use settings'));
    await tester.tap(find.text('Use settings'));
    await tester.pump();
    expect(choices, isEmpty);
    await tester.enterText(find.byKey(const Key('forge_runner_capacity')), '1');
    await tester.enterText(find.byKey(const Key('forge_job_cpus')), '1');
    await tester.enterText(find.byKey(const Key('forge_job_memory')), '768m');
    await tester.enterText(find.byKey(const Key('matrix_port')), '3000');
    await tester.ensureVisible(find.text('Use settings'));
    await tester.tap(find.text('Use settings'));
    await tester.pump();
    expect(choices, isEmpty);
    await tester.enterText(find.byKey(const Key('matrix_port')), '8548');
    await tester.ensureVisible(find.text('Use settings'));
    await tester.tap(find.text('Use settings'));
    await tester.pump();
    expect(choices.single.roleSettings, {'forge_runner_capacity': 1, 'forge_job_cpus': 1, 'forge_job_memory': '768m'});
    expect(choices.single.matrixPort, 8548);
  });

  // Harm: a field nobody can see refuses the settings, or a limit nobody can see goes along.
  testWidgets('with the forge off its hidden fields neither refuse nor count', (tester) async {
    final choices = <HostPreparationSettings>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HostPreparationSettingsForm(
              value: const HostPreparationSettings(forge: false, forgeJobCpus: 1),
              onChanged: choices.add,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('More settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use settings'));
    await tester.tap(find.text('Use settings'));
    await tester.pump();
    expect(choices.single.forge, isFalse);
    expect(choices.single.roleSettings, isEmpty);
  });

  // Harm: a value that stays in a field the forge's going hid refuses the settings with no way to see why.
  testWidgets('a bad value in a field the forge took along does not refuse', (tester) async {
    final choices = <HostPreparationSettings>[];
    Widget form(bool forge) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HostPreparationSettingsForm(
            value: HostPreparationSettings(forge: forge),
            onChanged: choices.add,
          ),
        ),
      ),
    );
    await tester.pumpWidget(form(true));
    await tester.tap(find.text('More settings'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('forge_runner_capacity')), '0');
    await tester.pumpWidget(form(false));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use settings'));
    await tester.tap(find.text('Use settings'));
    await tester.pump();
    expect(choices, hasLength(1));
    expect(choices.single.roleSettings, isEmpty);
  });
}
