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
}
