import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_keys.dart';
import 'package:porelo_frontend/src/ui/host_key_dialog.dart';
import 'package:porelo_frontend/src/ui/leaving.dart';
import 'package:porelo_frontend/src/ui/prepare_view.dart';

/// Dialogs whose content grows with what a machine has, in a window shorter than that content.
void main() {
  Future<void> open(WidgetTester tester, void Function(BuildContext) show) async {
    tester.view
      ..physicalSize = const Size(1280, 480)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(onPressed: () => show(context), child: const Text('open')),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('closing with a lot running still reaches the answer', (tester) async {
    await open(tester, (context) => confirmQuit(
          context,
          running: <String>[for (var each = 0; each < 60; each++) 'porelo-project-task-$each'],
          waiting: 2,
        ));

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('what-will-be-missed')));
  });

  testWidgets('choosing how much to build fits a short window', (tester) async {
    await open(tester, (context) => askHowMuchToBuild(context, project: 'checkout'));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a changed host key with many fingerprints still reaches the answer', (tester) async {
    await open(tester, (context) => confirmHostKey(
          context,
          HostKeyCheck(
            destination: 'root@build',
            host: 'build',
            known: true,
            changed: true,
            fingerprints: <String>[for (var each = 0; each < 30; each++) 'SHA256:key$each (ED25519)'],
          ),
        ));

    expect(tester.takeException(), isNull);
  });
}
