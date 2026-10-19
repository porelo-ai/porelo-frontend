// A stand-in `porelo-host` is a small `sh`, which only Linux has here.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_host/porelo_host.dart' as host;

void main() {
  late Directory scratch;
  setUp(() async => scratch = await Directory.systemTemp.createTemp('host-dialog-'));
  tearDown(() => scratch.delete(recursive: true));

  /// A stand-in `porelo-host`: the first start stops for the drive and a new vault, the second
  /// keeps what came on its standard input and ends done. Every start's arguments are kept.
  StartHostCommand stopsThenGoesOn() {
    var starts = 0;
    final waiting = const host.Step('person', host.StepState.waiting, needs: <String>['drive', 'vault-new']).toLine();
    final done = const host.Step('tasks', host.StepState.done).toLine();
    return (executable, arguments) {
      starts++;
      final n = starts;
      return Process.start('sh', <String>[
        '-c',
        'printf "%s\\n" "\$@" > "${scratch.path}/arguments-$n"; cat > "${scratch.path}/input-$n"; '
            '${n == 1 ? "printf '%s\\n' '$waiting'; exit 75" : "printf '%s\\n' '$done'; exit 0"}',
        'porelo-host',
        ...arguments,
      ]);
    };
  }

  /// Taps [key] in the real world, where the stand-in can start and end, then shows what it said.
  Future<void> tapAndRun(WidgetTester tester, Key key) async {
    await tester.runAsync(() async {
      await tester.tap(find.byKey(key));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pump();
  }

  testWidgets('the stop asks for the drive and a new vault twice, and sends them on standard input only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(project: 'demo', start: stopsThenGoesOn()),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('host-scaleway-project')), 'project-1');
    await tester.enterText(find.byKey(const Key('host-collection')), '/tmp/porelo-host.tar.gz');
    await tester.pump();

    await tapAndRun(tester, const Key('host-up'));

    expect(find.byKey(const Key('host-stop')), findsOneWidget);
    expect(find.byKey(const Key('host-fix')), findsNothing, reason: 'a stop is no refusal');
    await tester.enterText(find.byKey(const Key('host-drive-email')), 'me@example.org');
    await tester.enterText(find.byKey(const Key('host-drive-password')), 'drive-secret');
    await tester.enterText(find.byKey(const Key('host-drive-code')), '654321');
    await tester.enterText(find.byKey(const Key('host-passphrase')), 'vault-secret');
    await tester.enterText(find.byKey(const Key('host-passphrase-again')), 'vault-other');
    await tester.pump();
    expect(find.byKey(const Key('host-passphrases-differ')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-resume'))).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('host-passphrase-again')), 'vault-secret');
    await tester.pump();
    await tapAndRun(tester, const Key('host-resume'));

    expect(find.byKey(const Key('host-done')), findsOneWidget);
    final second = File('${scratch.path}/arguments-2').readAsStringSync();
    expect(second, contains('--answers-on-stdin'));
    expect(second, isNot(contains('secret')), reason: 'a secret never stands in the arguments');
    expect(second, isNot(contains('654321')), reason: 'nor the one-time code');
    final input = File('${scratch.path}/input-2').readAsStringSync();
    expect(input, contains('drive-secret'));
    expect(input, contains('"driveCode":"654321"'));
    expect(input, contains('vault-secret'));
    expect(File('${scratch.path}/arguments-1').readAsStringSync(), contains('--scaleway-project\nproject-1\n'));
  });
}
