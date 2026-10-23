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
  StartHostCommand stopsThenGoesOn({List<String> needs = const <String>['drive', 'vault-new']}) {
    var starts = 0;
    final waiting = host.Step('person', host.StepState.waiting, needs: needs).toLine();
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
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(key));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pump();
  }

  // Changing the host identity can make down report success while the rented host keeps billing.
  testWidgets('host fields stay read-only after up and down targets exactly the same host', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(project: 'demo', start: stopsThenGoesOn()),
        ),
      ),
    );
    const fields = <String, String>{
      'host-scaleway-project': 'project-1',
      'host-tresor': 'demo-drive',
      'host-account': 'demo-user',
      'host-public-key': '/tmp/demo.pub',
      'host-identity': '/tmp/demo-key',
      'host-collection': '/tmp/porelo-host.tar.gz',
    };
    for (final field in fields.entries) {
      expect(tester.widget<TextField>(find.byKey(Key(field.key))).readOnly, isFalse);
      await tester.enterText(find.byKey(Key(field.key)), field.value);
    }
    await tester.pump();
    await tapAndRun(tester, const Key('host-up'));
    expect(find.byKey(const Key('host-stop')), findsOneWidget);
    for (final key in fields.keys) {
      expect(
        tester.widget<TextField>(find.byKey(Key(key))).readOnly,
        isTrue,
        reason: '$key must not redirect teardown after a host has been rented',
      );
    }
    await tapAndRun(tester, const Key('host-down'));
    final up = File('${scratch.path}/arguments-1').readAsLinesSync();
    expect(File('${scratch.path}/arguments-2').readAsLinesSync(), <String>[
      'down',
      ...up.skip(1),
    ], reason: 'teardown must find the host that up rented');
    expect(find.byKey(const Key('host-done')), findsOneWidget);
    for (final field in fields.entries) {
      final widget = tester.widget<TextField>(find.byKey(Key(field.key)));
      expect(widget.readOnly, isTrue, reason: 'host identity stays locked for the rest of the dialog');
      expect(widget.controller!.text, field.value);
    }
  });

  // Unknown stops must not be hidden or repeatedly resumed with answers that cannot satisfy them.
  for (final needs in <List<String>>[
    <String>['tresor-2fa'],
    <String>['drive', 'vault', 'tresor-2fa'],
    <String>[],
  ]) {
    testWidgets('unsupported stop $needs explains what is missing and cannot resume', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              project: 'demo',
              start: stopsThenGoesOn(needs: needs),
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('host-scaleway-project')), 'project-1');
      await tester.enterText(find.byKey(const Key('host-tresor')), 'demo-drive');
      await tester.enterText(find.byKey(const Key('host-collection')), '/tmp/porelo-host.tar.gz');
      await tester.pump();
      await tapAndRun(tester, const Key('host-up'));
      expect(find.byKey(const Key('host-stop')), findsOneWidget);
      if (needs.isEmpty) {
        expect(find.textContaining('without saying for what'), findsOneWidget);
      } else {
        expect(
          find.textContaining('tresor-2fa'),
          findsOneWidget,
          reason: 'the command requirement must be shown verbatim',
        );
        expect(find.textContaining('this interface cannot answer it yet'), findsOneWidget);
      }
      if (needs.contains('drive')) {
        await tester.enterText(find.byKey(const Key('host-drive-email')), 'me@example.org');
        await tester.enterText(find.byKey(const Key('host-drive-password')), 'drive-secret');
        await tester.enterText(find.byKey(const Key('host-passphrase')), 'vault-secret');
        await tester.pump();
      }
      expect(
        find.byWidgetPredicate(
          (widget) => widget is FilledButton && widget.key == const Key('host-resume') && widget.onPressed != null,
        ),
        findsNothing,
        reason: 'answers to known needs cannot satisfy an unknown or unspecified need',
      );
    });
  }

  // Renting without a tresor would leave the project's drive unsynced.
  testWidgets('a host cannot be brought up without the project tresor', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
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
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('host-up'))).onPressed,
      isNull,
      reason: 'the drive must be named before a host can be rented',
    );
    await tester.enterText(find.byKey(const Key('host-tresor')), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-up'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('host-tresor')), 'demo-drive');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-up'))).onPressed, isNotNull);
  });

  // Resuming without an agent sign-in would repeat the same stop without resolving it.
  testWidgets('an agent sign-in stop names the agent and cannot resume with empty answers', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            project: 'demo',
            start: stopsThenGoesOn(needs: const <String>['agent-login:claude']),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('host-scaleway-project')), 'project-1');
    await tester.enterText(find.byKey(const Key('host-collection')), '/tmp/porelo-host.tar.gz');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('host-tresor')), ' demo-drive ');
    await tester.pump();
    await tapAndRun(tester, const Key('host-up'));

    expect(find.byKey(const Key('host-stop')), findsOneWidget);
    expect(find.byKey(const Key('host-drive-email')), findsNothing);
    expect(find.byKey(const Key('host-drive-password')), findsNothing);
    expect(find.byKey(const Key('host-passphrase')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is FilledButton && widget.key == const Key('host-resume') && widget.onPressed != null,
      ),
      findsNothing,
      reason: 'empty answers cannot resolve the agent sign-in',
    );
    expect(find.textContaining('claude'), findsOneWidget, reason: 'the unresolved sign-in must be identified');
  });

  testWidgets('mixed stops send secrets only on stdin and keep exactly the same host arguments', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            project: 'demo',
            start: stopsThenGoesOn(
              needs: const <String>['drive', 'vault-new', 'agent-login:claude', 'agent-login:codex'],
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('host-scaleway-project')), 'project-1');
    await tester.enterText(find.byKey(const Key('host-collection')), '/tmp/porelo-host.tar.gz');
    await tester.pump();

    await tester.enterText(find.byKey(const Key('host-tresor')), ' demo-drive ');
    await tester.pump();
    await tapAndRun(tester, const Key('host-up'));

    expect(find.byKey(const Key('host-stop')), findsOneWidget);
    expect(find.byKey(const Key('host-fix')), findsNothing, reason: 'a stop is no refusal');
    expect(find.textContaining('claude'), findsOneWidget);
    expect(find.textContaining('codex'), findsOneWidget);
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

    await tapAndRun(tester, const Key('host-down'));
    final commands = <List<String>>[
      for (var n = 1; n <= 3; n++) File('${scratch.path}/arguments-$n').readAsLinesSync(),
    ];
    expect(commands.map((arguments) => arguments.first), <String>['up', 'up', 'down']);
    expect(commands.first, containsAllInOrder(<String>['--tresor', 'demo-drive']));
    expect(commands[1], <String>[
      ...commands.first,
      '--answers-on-stdin',
    ], reason: 'resume must use every original host argument and add only the stdin flag');
    expect(commands[2], <String>[
      'down',
      ...commands.first.skip(1),
    ], reason: 'down must target exactly the host that up rented');
  });
}
