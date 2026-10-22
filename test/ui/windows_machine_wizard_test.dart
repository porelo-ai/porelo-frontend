import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/connection_trial.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/host_keys.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/ui/machine_switcher.dart';

class _Keys implements HostKeys {
  final List<String> checked = <String>[];

  @override
  Future<HostKeyCheck> check(String destination) async {
    checked.add(destination);
    return HostKeyCheck(destination: destination, host: destination, known: true);
  }

  @override
  Future<void> accept(HostKeyCheck check) async => fail('Known keys need no acceptance.');
}

void main() {
  late Desk previous;
  setUp(() {
    previous = desk;
    desk = Desk.of('windows', const <String, String>{'SystemRoot': r'D:\Windows'});
  });
  tearDown(() => desk = previous);

  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final refused in <bool>[false, true]) {
    // Prevents persisting a local Unix endpoint or running a host as an ssh option.
    testWidgets(
      refused
          ? 'the Windows wizard refuses an option host before anything runs'
          : 'the Windows wizard offers ssh and saves no local socket',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final keys = _Keys();
        final tried = <Machine>[];
        Machine? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    saved = await askForAMachine(
                      context,
                      onWindows: true,
                      hostKeys: keys,
                      trying: (machine) async {
                        tried.add(machine);
                        return const Trial(reached: true, words: 'Reached Porelo.');
                      },
                      socketAt: (_) async => fail('The remote socket was provided.'),
                    );
                  },
                  child: const Text('Add machine'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Add machine'));
        await settle(tester);
        await tester.enterText(find.byKey(const Key('machine-name')), 'box');
        await tester.tap(find.byKey(const Key('machine-kind-choice')));
        await settle(tester);
        final sshChoice = find.text('A Porelo already running on a machine over ssh').last;
        expect(sshChoice, findsOneWidget);
        await tester.tap(sshChoice);
        await settle(tester);
        await tester.tap(find.byKey(const Key('wizard-next')));
        await settle(tester);
        await tester.enterText(find.byKey(const Key('machine-host')), refused ? '-oProxyCommand=wrong' : 'user@box');
        await tester.enterText(find.byKey(const Key('machine-remote-socket')), '/run/user/1000/porelo/porelod.sock');
        await tester.pump();
        final tryButton = find.text('Try the connection');
        await tester.ensureVisible(tryButton);
        await tester.tap(tryButton);
        await settle(tester);
        if (refused) {
          expect(find.textContaining('An ssh host must not start with a dash.'), findsOneWidget);
          expect(tried, isEmpty);
          expect(keys.checked, isEmpty);
          await tester.tap(find.byKey(const Key('watch-it')));
          await settle(tester);
          expect(saved, isNull);
          expect(keys.checked, isEmpty);
        } else {
          expect(tried.single.socketPath, isEmpty);
          await tester.tap(find.byKey(const Key('watch-it')));
          await settle(tester);
          expect(saved, isNotNull);
          expect(saved!.socketPath, isEmpty);
          expect(saved!.host, 'user@box');
        }
      },
    );
  }
}
