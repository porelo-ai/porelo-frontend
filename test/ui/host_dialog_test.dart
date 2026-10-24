// A stand-in `porelo-host` is a small `sh`, which only Linux has here.
@Tags(<String>['linux'])
library;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as path;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart';

import '../features/support/world.dart';
import '../../packages/porelo_host/test/support/pinned_ssh.dart';

import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';

import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_host/porelo_host.dart' as host;

void main() {
  late Directory scratch;
  late Machines machines;
  String fixture(String name) => path.join(scratch.path, name);
  const signingPublic = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4f fixture';
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('host-dialog-');
    for (final name in ['default', 'private', 'new', 'dialog identity', 'demo-key', 'collection.tar.gz']) {
      File(fixture(name)).writeAsStringSync('invented-private-or-setup-fixture');
    }
    for (final name in ['default.pub', 'public.pub', 'id_ed25519.pub', 'demo.pub', 'signing.pub']) {
      File(fixture(name)).writeAsStringSync(signingPublic);
    }
    machines = Machines(Settings(MemorySettingsStore()), reach: (_) => FakeBackend(const []), tunnels: _HostTunnels());
  });
  tearDown(() => machines.dispose());
  tearDown(() => scratch.delete(recursive: true));

  // Harm: a forgotten server keeps billing without anyone knowing how to find it.
  testWidgets('removing a host warns before forgetting and offers teardown beside removal', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    const machine = Machine(
      name: 'demo server',
      kind: 'host',
      socketPath: '/tmp/demo.sock',
      host: 'porelo@203.0.113.7',
      identity: '/keys/host',
      remoteSocket: '/run/user/1007/porelo/porelod.sock',
    );
    await World.machines.add(machine);
    World.shell.goTo(Section.machines);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('machines-menu demo server')));
    await World.settle(tester);
    expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('machine.takeDown'))).enabled, isFalse);
    expect(
      find.textContaining('nothing was kept from putting it on a server; use Put this project on a server…'),
      findsOneWidget,
    );
    await tester.tap(find.text('Remove from this list'));
    await World.settle(tester);
    expect(World.machines.all, contains(machine), reason: 'opening removal must not forget a billing server');
    expect(find.textContaining('running and billing'), findsOneWidget);
    expect(find.textContaining('tag'), findsOneWidget);
    expect(find.text('Take this server down'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await World.settle(tester);
    expect(World.machines.all, contains(machine));
    await tester.tap(find.byKey(const Key('machines-menu demo server')));
    await World.settle(tester);
    await tester.tap(find.text('Remove from this list'));
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('forget-it')));
    await World.settle(tester);
    expect(World.machines.all, isNot(contains(machine)));
  });

  /// A stand-in `porelo-host`: the first start stops for the drive and a new vault, the second
  /// records stdin and ends done. Every start's arguments are kept.
  StartHostCommand stopsThenGoesOn({List<String> needs = const <String>['drive', 'vault-new']}) {
    var starts = 0;
    final waiting = host.Step(
      'person',
      host.StepState.waiting,
      needs: needs,
      address: '203.0.113.7',
      account: 'actual-account',
    ).toLine();
    final done = const host.Step(
      'up',
      host.StepState.done,
      address: '203.0.113.7',
      account: 'porelo',
      socket: '/run/user/1007/porelo/porelod.sock',
    ).toLine();
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
    await World.settle(tester);
  }

  Future<void> navigate(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await World.settle(tester);
  }

  /// Gives each answer on its own step, without bypassing the wizard's checks.
  Future<void> fillSteps(
    WidgetTester tester,
    Map<String, String> values, {
    int? stopAt,
    Future<void> Function()? onDrive,
    void Function(TextField field, String key)? beforeFill,
  }) async {
    final answers = <String, String>{
      'host-identity': fixture('default'),
      'host-public-key': fixture('default.pub'),
      ...values,
    };
    const fields = [
      ['host-scaleway-project', 'host-account'],
      ['host-tresor', 'host-repository', 'host-signing-key'],
      ['host-identity', 'host-public-key'],
      ['host-collection'],
    ];
    for (var step = 0; step < fields.length; step++) {
      if (step == 1) await onDrive?.call();
      if (step == 1 &&
          !answers.containsKey('host-signing-key') &&
          find.byKey(const Key('host-signing-key')).evaluate().isNotEmpty) {
        answers['host-signing-key'] = fixture('signing.pub');
      }
      for (final key in fields[step]) {
        if (!answers.containsKey(key)) continue;
        await tester.ensureVisible(find.byKey(Key(key)));
        beforeFill?.call(tester.widget<TextField>(find.byKey(Key(key))), key);
        await tester.enterText(find.byKey(Key(key)), answers[key]!);
      }
      await tester.pump();
      if (step == stopAt) return;
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed,
        isNotNull,
        reason: 'the supplied answers must pass step ${step + 1}',
      );
      await navigate(tester, 'wizard-next');
    }
  }

  // Harm: losing the last setup answers makes a rented server impossible to recover or take down.
  testWidgets('up keeps its arguments before answering and reopening restores every editable step', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemorySettingsStore();
    final settings = Settings(store);
    await settings.rememberTresorFolder('demo', scratch.path);
    final answers = {
      'host-scaleway-project': 'project',
      'host-account': 'worker',
      'host-tresor': 'remote-drive',
      'host-repository': 'https://example.org/demo.git',
      'host-signing-key': fixture('signing.pub'),
      'host-identity': fixture('private'),
      'host-public-key': fixture('public.pub'),
      'host-collection': fixture('collection.tar.gz'),
    };
    final process = _HostProcess();
    final commands = <List<String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          project: 'demo',
          machines: machines,
          settings: settings,
          secretStore: _MemorySecrets(),
          start: (_, arguments) async {
            final persisted = Settings(store);
            await persisted.load();
            expect(
              persisted.hostUp('demo')!.arguments('demo'),
              arguments.skip(1).toList(),
              reason: 'the record must be durable before starting a billing host',
            );
            commands.add(List.of(arguments));
            return process;
          },
        ),
      ),
    );
    await fillSteps(tester, answers);
    await tapAndRun(tester, const Key('host-up'));
    expect(commands, hasLength(1));
    process.end(65);
    await World.settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    final reopened = Settings(store);
    await reopened.load();
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(project: 'demo', machines: machines, settings: reopened),
      ),
    );
    final seen = <String>{};
    await fillSteps(
      tester,
      answers,
      beforeFill: (field, key) {
        seen.add(key);
        expect(field.controller!.text, answers[key], reason: '$key must restore the last up answer');
        expect(field.readOnly, isFalse, reason: 'reopened answers remain editable');
      },
      onDrive: () async => expect(find.text(scratch.path), findsOneWidget),
    );
    expect(seen, answers.keys.toSet());
  });

  for (final code in [65, 75, 0]) {
    for (final released in [null, '203.0.113.7', '203.0.113.8']) {
      // Harm: failed teardown loses the only route back, or teardown targets a different billing host.
      testWidgets('Machines teardown reuses kept arguments and removes only after exit $code releasing $released', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final settings = Settings(MemorySettingsStore());
        const record = HostUpRecord(
          scalewayProject: 'provider-project',
          account: 'worker',
          tresor: 'remote-drive',
          folder: '/not-needed-for-down',
          repository: 'https://example.org/demo.git',
          signingKey: '/keys/sign.pub',
          identity: '/keys/private',
          publicKey: '/keys/public.pub',
          collection: '/setup.tar.gz',
          vpnPeerPublicKey: 'public-half',
          vpnPeerAddress: '10.73.0.2/32',
        );
        await settings.rememberHostUp('demo', record);
        const machine = Machine(
          name: 'demo server',
          kind: 'host',
          hostProject: 'demo',
          socketPath: '/tmp/demo.sock',
          host: 'worker@203.0.113.7',
          identity: '/keys/private',
        );
        await machines.add(machine);
        final before = machines.all;
        final commands = <List<String>>[];
        final process = _HostProcess();
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: MachinesPage(
                  machines: machines,
                  onAdd: () {},
                  onDetails: (_) {},
                  onForget: (_) {},
                  hostCommands: (machine) => hostMachineCommands(
                    machine: machine,
                    settings: settings,
                    takeDown: () => unawaited(
                      openHostTakeDownDialog(
                        context,
                        project: machine.hostProject,
                        machines: machines,
                        settings: settings,
                        start: (_, arguments) async {
                          commands.add(List.of(arguments));
                          return process;
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('machines-menu demo server')));
        await World.settle(tester);
        await tester.tap(find.text('Take this server down'));
        await World.settle(tester);
        expect(commands, isEmpty, reason: 'teardown must wait for the explicit confirmation');
        expect(find.textContaining('tasks'), findsOneWidget);
        expect(find.textContaining('room'), findsOneWidget);
        expect(find.textContaining('files'), findsOneWidget);
        expect(find.byType(TextField), findsNothing, reason: 'no setup answer is typed again');
        await tester.tap(find.byKey(const Key('host-down')));
        await World.settle(tester);
        expect(commands, [
          [
            'down',
            '--project',
            'demo',
            '--tresor',
            'remote-drive',
            '--account',
            'worker',
            '--public-key',
            '/keys/public.pub',
            '--identity',
            '/keys/private',
            '--collection',
            '/setup.tar.gz',
            '--vpn-peer-public-key',
            'public-half',
            '--vpn-peer-address',
            '10.73.0.2/32',
            '--scaleway-project',
            'provider-project',
          ],
        ]);
        expect(machines.all, before);
        process.line(host.Step('give-back', host.StepState.done, address: released));
        await World.settle(tester);
        expect(machines.all, before, reason: 'a progress line does not confirm a successful exit');
        process.end(code);
        await World.settle(tester);
        expect(
          machines.all,
          code == 0 && released == '203.0.113.7' ? before.where((each) => each != machine).toList() : before,
        );
        if (code == 65) expect(find.byKey(const Key('host-fix')), findsOneWidget);
        if (code == 75) expect(find.textContaining('has not completed teardown'), findsOneWidget);
      });
    }
  }

  for (final field in [
    (key: 'host-signing-key', label: 'public key for signing commits', step: 1),
    (key: 'host-identity', label: 'private ssh key', step: 2),
    (key: 'host-public-key', label: 'public ssh key', step: 2),
    (key: 'host-collection', label: 'server setup file', step: 3),
    (key: 'vault-entry', label: 'vault entry deployment', step: 1),
  ]) {
    for (final directory in [false, true]) {
      // Harm: finding an unusable input only after renting leaves a billing host without setup.
      testWidgets('${field.key} refuses a ${directory ? 'directory' : 'missing file'} in its own step', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final previousDesk = desk;
        desk = Desk.of('linux', {'HOME': scratch.path});
        addTearDown(() => desk = previousDesk);
        final selected = fixture('unusable');
        if (directory) Directory(selected).createSync();
        final settings = Settings(MemorySettingsStore());
        await settings.rememberTresorFolder('demo', scratch.path);
        var starts = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HostDialog(
                project: 'demo',
                machines: machines,
                settings: settings,
                secretStore: _MemorySecrets(),
                pickFile: () async => '~/unusable',
                start: (_, _) async {
                  starts++;
                  return _HostProcess();
                },
              ),
            ),
          ),
        );
        await fillSteps(tester, {
          'host-scaleway-project': 'project',
          'host-tresor': 'drive',
          'host-repository': 'https://example.org/demo.git',
          'host-collection': fixture('collection.tar.gz'),
          if (field.key != 'vault-entry') field.key: '~/unusable',
        }, stopAt: field.step);
        if (field.key == 'vault-entry') {
          await tester.ensureVisible(find.byKey(const Key('host-key-name')));
          await tester.enterText(find.byKey(const Key('host-key-name')), 'deployment');
          await tester.ensureVisible(find.text('Choose a file for this vault entry'));
          await tester.tap(find.text('Choose a file for this vault entry'));
          await World.settle(tester);
        }
        expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
        expect(find.textContaining(selected), findsOneWidget, reason: 'the refusal names the expanded path');
        expect(tester.widget<Text>(find.textContaining(selected)).data, contains(field.label));
        expect(find.textContaining(directory ? 'not a regular file' : 'does not exist'), findsOneWidget);
        expect(find.byKey(const Key('host-up')), findsNothing);
        expect(starts, 0, reason: 'the bad path must be corrected before renting');
      });
    }
  }

  // Harm: an input refusal without its field and step prevents correcting setup before renting.
  testWidgets('a preparation refusal names the input and back correct next retries with the new file', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    await settings.rememberTresorFolder('demo', scratch.path);
    final unreadable = File(fixture('unreadable.pub'))..writeAsBytesSync([0xff]);
    final replacement = File(fixture('replacement.pub'))..writeAsStringSync(signingPublic);
    final commands = <List<String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            project: 'demo',
            machines: machines,
            settings: settings,
            secretStore: _MemorySecrets(),
            start: (_, arguments) async {
              commands.add(List.of(arguments));
              final process = _HostProcess();
              process.line(const host.Step('up', host.StepState.done));
              process.end(0);
              return process;
            },
          ),
        ),
      ),
    );
    await fillSteps(tester, {
      'host-scaleway-project': 'project',
      'host-tresor': 'drive',
      'host-repository': 'https://example.org/demo.git',
      'host-signing-key': unreadable.path,
      'host-collection': fixture('collection.tar.gz'),
    });
    await tapAndRun(tester, const Key('host-up'));
    expect(commands, isEmpty, reason: 'unreadable setup input must stop before renting');
    final refusal = find.textContaining(unreadable.path);
    expect(refusal, findsOneWidget);
    final words = tester.widget<Text>(refusal).data!;
    expect(words, contains('Public key for signing commits (.pub)'));
    expect(words, contains('The drive'));
    expect(words, contains('cannot be read'));
    for (var back = 0; back < 4; back++) {
      await navigate(tester, 'wizard-back');
    }
    await tester.ensureVisible(find.byKey(const Key('host-signing-key')));
    await tester.enterText(find.byKey(const Key('host-signing-key')), replacement.path);
    await tester.pump();
    for (var next = 0; next < 3; next++) {
      await navigate(tester, 'wizard-next');
    }
    await tapAndRun(tester, const Key('host-up'));
    expect(commands, hasLength(1), reason: 'the corrected answers must run preparation and start the action');
    expect(find.textContaining(unreadable.path), findsNothing);
    expect(find.text('refused'), findsNothing);
    expect(find.byKey(const Key('host-done')), findsOneWidget);
    final yaml = File(fixture('porelo-host/machine.yml')).readAsStringSync();
    expect(yaml, contains(host.HostFiles.signingFingerprint(replacement.readAsStringSync())));
  });

  // Harm: confusing the local folder with the remote tresor syncs the wrong project on the server.
  testWidgets('the folder and its picker share a line and suggest only an unedited tresor name', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var folder = fixture('first-drive');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(project: 'demo', machines: machines, pickFolder: () async => folder),
        ),
      ),
    );
    await fillSteps(tester, {'host-scaleway-project': 'project'}, stopAt: 1);
    final button = find.byKey(const Key('host-folder'));
    expect(find.text('No folder chosen'), findsOneWidget);
    expect(find.descendant(of: button, matching: find.text('Choose…')), findsOneWidget);
    Future<void> choose() async {
      await tester.ensureVisible(button);
      await tester.tap(button);
      await World.settle(tester);
      final row = find.ancestor(of: button, matching: find.byType(Row)).first;
      expect(find.descendant(of: row, matching: find.text(folder)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.byType(TextField)), findsNothing);
      expect(tester.getTopLeft(row).dy, lessThan(tester.getTopLeft(find.byKey(const Key('host-tresor'))).dy));
    }

    String tresor() => tester.widget<TextField>(find.byKey(const Key('host-tresor'))).controller!.text;
    await choose();
    expect(tresor(), 'first-drive');
    folder = fixture('second-drive');
    await choose();
    expect(tresor(), 'second-drive');
    await tester.enterText(find.byKey(const Key('host-tresor')), 'remote-project');
    folder = fixture('third-drive');
    await choose();
    expect(tresor(), 'remote-project', reason: 'choosing a folder must preserve an edited remote name');
  });

  // Harm: renting with a public key as the identity leaves a billing host inaccessible.
  testWidgets('a public key path is refused before up starts', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            project: 'demo',
            machines: machines,
            secretStore: _MemorySecrets(),
            start: (_, _) async {
              starts++;
              final process = _HostProcess();
              process.end(65);
              return process;
            },
          ),
        ),
      ),
    );
    await fillSteps(tester, <String, String>{
      'host-scaleway-project': 'project',
      'host-tresor': 'drive',
      'host-identity': fixture('id_ed25519.pub'),
      'host-collection': fixture('collection.tar.gz'),
    }, stopAt: 2);
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
    expect(find.byKey(const Key('host-up')), findsNothing);
    expect(starts, 0, reason: 'a public key cannot log in to the rented host');
    expect(find.textContaining('Choose the private ssh key'), findsOneWidget);
  });

  for (final missing in {
    'host-scaleway-project': 0,
    'host-account': 0,
    'host-tresor': 1,
    'host-repository': 1,
    'host-signing-key': 1,
    'host-identity': 2,
    'host-public-key': 2,
    'host-collection': 3,
  }.entries) {
    // Harm: an incomplete answer rents a billing server that cannot be set up.
    testWidgets('${missing.key} must be given before the start decision can be reached', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = Settings(MemorySettingsStore());
      await settings.rememberTresorFolder('demo', scratch.path);
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              project: 'demo',
              machines: machines,
              settings: settings,
              secretStore: _MemorySecrets(),
              start: (_, _) async {
                starts++;
                return _HostProcess();
              },
            ),
          ),
        ),
      );
      await fillSteps(tester, {
        'host-scaleway-project': 'project',
        'host-account': 'porelo',
        'host-tresor': 'drive',
        'host-repository': 'https://example.org/demo.git',
        'host-signing-key': fixture('signing.pub'),
        'host-collection': fixture('collection.tar.gz'),
        missing.key: '   ',
      }, stopAt: missing.value);
      final next = tester.widget<FilledButton>(find.byKey(const Key('wizard-next')));
      expect(next.onPressed, isNull, reason: '${missing.key} cannot be skipped');
      await navigate(tester, 'wizard-next');
      expect(find.byKey(Key(missing.key)), findsOneWidget);
      expect(find.byKey(const Key('host-up')), findsNothing);
      expect(starts, 0, reason: 'nothing may be rented before all steps and review');
    });
  }

  // Harm: a renamed public key is accepted as an identity and setup rents an inaccessible host.
  testWidgets('a public key without a pub suffix is refused before up starts', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final public = File(path.join(scratch.path, 'identity'));
    public.writeAsStringSync('ssh-ed25519 public-key-fixture');
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            project: 'demo',
            machines: machines,
            secretStore: _MemorySecrets(),
            start: (_, _) async {
              starts++;
              return _HostProcess();
            },
          ),
        ),
      ),
    );
    await fillSteps(tester, {
      'host-scaleway-project': 'project',
      'host-tresor': 'drive',
      'host-identity': public.path,
    }, stopAt: 2);
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
    expect(find.textContaining('Choose the private ssh key'), findsOneWidget);
    expect(find.byKey(const Key('host-up')), findsNothing);
    expect(starts, 0);
  });

  // Harm: moving back loses a key path or changes the server that the review will start.
  testWidgets('back keeps every host answer before starting', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(project: 'demo', machines: machines, secretStore: _MemorySecrets()),
        ),
      ),
    );
    final answers = {
      'host-scaleway-project': 'project',
      'host-account': 'account',
      'host-tresor': 'drive',
      'host-identity': fixture('private'),
      'host-public-key': fixture('public.pub'),
      'host-collection': fixture('collection.tar.gz'),
    };
    await fillSteps(tester, answers);
    final seen = <String>{};
    for (var step = 0; step < 4; step++) {
      await navigate(tester, 'wizard-back');
      for (final answer in answers.entries) {
        final field = find.byKey(Key(answer.key));
        if (field.evaluate().isNotEmpty) {
          seen.add(answer.key);
          expect(tester.widget<TextField>(field).controller!.text, answer.value);
        }
      }
    }
    expect(seen, answers.keys.toSet(), reason: 'every supplied answer must have been inspected');
    expect(find.byKey(const Key('host-scaleway-project')), findsOneWidget);
  });

  // Harm: a confirmed leave crashes when the unfinished process delivers its final answer.
  testWidgets('leaving a running host action safely lets its process answer', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final process = _HostProcess();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => HostDialog(
                  project: 'demo',
                  machines: machines,
                  secretStore: _MemorySecrets(),
                  start: (_, _) async => process,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await World.settle(tester);
    await fillSteps(tester, {
      'host-scaleway-project': 'project',
      'host-tresor': 'drive',
      'host-collection': fixture('collection.tar.gz'),
    });
    await tapAndRun(tester, const Key('host-up'));
    await navigate(tester, 'wizard-leave');
    expect(find.byKey(const Key('wizard-confirm-leave')), findsOneWidget);
    await navigate(tester, 'wizard-confirm-leave');
    expect(find.byType(HostDialog), findsNothing);
    process.line(const host.Step('up', host.StepState.done));
    process.end(0);
    await World.settle(tester);
    expect(tester.takeException(), isNull, reason: 'a process answer must not notify a disposed dialog');
    expect(machines.all.where((machine) => machine.kind == 'host'), isEmpty);
  });

  for (final field in <String, String?>{
    'host-public-key': '--public-key',
    'host-identity': '--identity',
    'host-collection': '--collection',
    'host-signing-key': null,
  }.entries) {
    // Harm: up receives a nonexistent path or cannot prepare the host file.
    testWidgets('${field.key} expands a home path before preparing files and starting up', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final previousDesk = desk;
      desk = Desk.of('linux', {'HOME': scratch.path});
      addTearDown(() => desk = previousDesk);
      final settings = Settings(MemorySettingsStore());
      await settings.rememberTresorFolder('demo', scratch.path);
      late File signing;
      await tester.runAsync(() async {
        await Directory(path.join(scratch.path, '.ssh')).create();
        await File(path.join(scratch.path, '.ssh', 'key')).writeAsString('invented-private-or-setup-fixture');
        signing = await File(path.join(scratch.path, '.ssh', 'key.pub'))
            .writeAsString('ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4f fixture');
      });
      final commands = <List<String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              project: 'demo',
              machines: machines,
              settings: settings,
              secretStore: _MemorySecrets(),
              start: (_, arguments) async {
                commands.add(List.of(arguments));
                final process = _HostProcess();
                process.end(0);
                return process;
              },
            ),
          ),
        ),
      );
      await fillSteps(tester, <String, String>{
        'host-scaleway-project': 'project',
        'host-tresor': 'tresor',
        'host-collection': fixture('collection.tar.gz'),
        'host-repository': 'https://example.org/demo.git',
        'host-signing-key': signing.path,
        field.key: field.value == null ? '~/.ssh/key.pub' : '~/.ssh/key',
      });
      await tester.pump();
      await tapAndRun(tester, const Key('host-up'));
      expect(commands, hasLength(1), reason: 'the signing key must be readable and file preparation must finish');
      expect(commands.single.first, 'up');
      if (field.value != null) {
        expect(commands.single, containsAllInOrder([field.value!, path.join(scratch.path, '.ssh', 'key')]));
      }
    });

    // Harm: an unsupported home path starts provisioning with a nonexistent file.
    testWidgets('${field.key} refuses another user home path before up starts', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = Settings(MemorySettingsStore());
      await settings.rememberTresorFolder('demo', scratch.path);
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              project: 'demo',
              machines: machines,
              settings: settings,
              secretStore: _MemorySecrets(),
              start: (_, _) async {
                starts++;
                final process = _HostProcess();
                process.end(0);
                return process;
              },
            ),
          ),
        ),
      );
      await fillSteps(
        tester,
        <String, String>{
          'host-scaleway-project': 'project',
          'host-tresor': 'tresor',
          'host-collection': fixture('collection.tar.gz'),
          'host-repository': 'https://example.org/demo.git',
          field.key: '~user/key',
        },
        stopAt: switch (field.key) {
          'host-signing-key' => 1,
          'host-collection' => 3,
          _ => 2,
        },
      );
      await tester.pump();
      expect(find.byKey(const Key('host-up')), findsNothing);
      expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
      expect(starts, 0, reason: 'unsupported paths must block provisioning');
      expect(find.textContaining(RegExp(r'~user.*only ~/ is understood')), findsOneWidget);
    });
  }

  // Harm: a development walk accidentally launches the installed host provisioning command.
  testWidgets('the dialog runs the executable named by its injected environment', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final executable = File('${scratch.path}/host');
    final marker = File('${scratch.path}/ran');
    await tester.runAsync(() async {
      await executable.writeAsString('#!/bin/sh\ncat >/dev/null\nprintf ran > "${marker.path}"\nexit 65\n');
      expect((await Process.run('chmod', ['700', executable.path])).exitCode, 0);
    });
    String? launched;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            project: 'demo',
            machines: machines,
            secretStore: _MemorySecrets(),
            environment: {'PORELO_HOST_STANDIN': executable.path},
            start: (program, arguments) async {
              launched = program;
              // A wrong selection must fail without running a real provisioning command.
              return Process.start(program == executable.path ? program : '/bin/false', arguments);
            },
          ),
        ),
      ),
    );
    await fillSteps(tester, <String, String>{
      'host-scaleway-project': 'project',
      'host-tresor': 'drive',
      'host-collection': fixture('collection.tar.gz'),
    });
    await tester.pump();
    await tapAndRun(tester, const Key('host-up'));
    expect(launched, executable.path);
    expect(await tester.runAsync(() => marker.readAsString()), 'ran');
  });

  // Harm: a conflicting file is destroyed or a rented host starts with incomplete files.
  // Red: start the session before awaiting prepare, or truncate an existing machine.yml.
  testWidgets('a conflicting machine file is named and up never starts', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    await settings.rememberTresorFolder('demo', scratch.path);
    var starts = 0;
    late File conflict;
    late File signing;
    await tester.runAsync(() async {
      await Directory(path.join(scratch.path, 'porelo-host')).create();
      conflict = await File(path.join(scratch.path, 'porelo-host', 'machine.yml')).writeAsString('keep');
      signing = await File(path.join(scratch.path, 'signing.pub'))
          .writeAsString('ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4f fixture');
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            machines: machines,
            project: 'demo',
            settings: settings,
            secretStore: _MemorySecrets(),
            start: (_, _) async {
              starts++;
              return _HostProcess();
            },
          ),
        ),
      ),
    );
    await fillSteps(tester, <String, String>{
      'host-scaleway-project': 'project',
      'host-tresor': 'tresor',
      'host-collection': fixture('collection.tar.gz'),
      'host-repository': 'https://example.org/demo.git',
      'host-signing-key': signing.path,
    });
    await tester.pump();
    await tapAndRun(tester, const Key('host-up'));
    expect(starts, 0, reason: 'file conflicts must block renting');
    expect(find.textContaining(conflict.path), findsOneWidget);
    expect(await tester.runAsync(() => conflict.readAsString()), 'keep');
  });

  // Harm: the private key reaches a process/log/UI, or repeated up/down configure the wrong peer.
  // Red: pass a private key as the peer option, show it in a step, or omit the options on repeated up/down.
  // Export red: omit chmod, put the host private half in the export, or export before the button is used.
  testWidgets('folder picker prepares files and only explicit export reads out the stored private half', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settingsStore = MemorySettingsStore();
    final settings = Settings(settingsStore);
    final store = _MemorySecrets();
    final commands = <List<String>>[];
    final processes = <_HostProcess>[];
    Future<void> deliver(void Function() send) async {
      await tester.runAsync(() async {
        send();
        // The process listener awaits in runAsync's real zone; fake-clock pumps cannot finish it.
        await Future<void>.delayed(Duration.zero);
      });
      await World.settle(tester);
    }

    final terminal = FakeTerminal([]);
    final exported = File(path.join(scratch.path, 'requested.conf'));
    late File signing;
    await tester.runAsync(() async {
      signing = await File(path.join(scratch.path, 'signing.pub'))
          .writeAsString('ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4f fixture');
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            machines: machines,
            project: 'demo',
            settings: settings,
            secretStore: store,
            pickFolder: () async => scratch.path,
            saveTunnel: () async => exported.path,
            openTerminal: (_, _, {columns = 80, rows = 24}) => terminal,
            start: (_, arguments) async {
              commands.add(List.of(arguments));
              final process = _HostProcess();
              processes.add(process);
              return process;
            },
          ),
        ),
      ),
    );
    await fillSteps(
      tester,
      <String, String>{
        'host-scaleway-project': 'project',
        'host-tresor': 'tresor',
        'host-collection': fixture('collection.tar.gz'),
        'host-repository': 'https://example.org/demo.git',
        'host-signing-key': signing.path,
      },
      onDrive: () async {
        expect(find.textContaining('Supply the host files manually'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('host-folder')));
        await tester.tap(find.byKey(const Key('host-folder')));
        await World.settle(tester);
        expect(settings.tresorFolder('demo'), scratch.path);
      },
    );
    await tester.pump();
    await tapAndRun(tester, const Key('host-up'));
    expect(commands.length, 1);
    await deliver(() {
      processes.last.line(
        const host.Step('person', host.StepState.waiting, needs: ['vault'], address: '203.0.113.8', account: 'porelo'),
      );
      processes.last.end(75);
    });
    expect(find.byKey(const Key('host-stop')), findsOneWidget);
    await tapAndRun(tester, const Key('host-open-terminal'));
    terminal.endsWith(0);
    await World.settle(tester);
    await tapAndRun(tester, const Key('unlock-done'));
    expect(commands.length, 2);
    await deliver(
      () => processes.last.line(
        const host.Step(
          'up',
          host.StepState.done,
          address: '203.0.113.8',
          account: 'porelo',
          socket: '/run/user/1007/porelo/porelod.sock',
        ),
      ),
    );
    expect(
      find.byKey(const Key('host-step-up')),
      findsOneWidget,
      reason: 'the done line must arrive before testing exit',
    );
    expect(find.byKey(const Key('host-export-tunnel')), findsNothing, reason: 'a done step needs exit 0');
    await deliver(() => processes.last.end(0));
    final private = store.values[host.HostFiles.keyName('demo')]!;
    final peer = await host.HostFiles.publicKey(private);
    final hostPrivate = (await tester.runAsync(
      () => File(path.join(scratch.path, 'porelo-host', 'wireguard.key')).readAsString(),
    ))!.trim();
    final hostPublic = await host.HostFiles.publicKey(hostPrivate);
    expect(find.textContaining(hostPublic), findsOneWidget);
    expect(await tester.runAsync(() => exported.exists()), isFalse);
    for (final secret in [private, hostPrivate]) {
      expect(
        tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').join(' '),
        isNot(contains(secret)),
        reason: 'private halves never appear in labels, steps or refusal text',
      );
    }
    await tapAndRun(tester, const Key('host-export-tunnel'));
    final config = await tester.runAsync(() => exported.readAsString());
    expect(config, contains('PrivateKey = $private'));
    expect(config, contains('PublicKey = $hostPublic'));
    final reopened = Settings(settingsStore);
    await reopened.load();
    expect(
      reopened.hostUp('demo')!.vpnFile,
      exported.path,
      reason: 'VPN actions must use the explicitly exported file after restarting',
    );
    expect((await tester.runAsync(() => exported.stat()))!.mode & 0x1ff, 0x180);
    await tapAndRun(tester, const Key('host-down'));
    expect(commands.map((a) => a.first), ['up', 'up', 'down']);
    for (final command in commands) {
      expect(command, containsAllInOrder(['--vpn-peer-public-key', peer, '--vpn-peer-address', '10.73.0.2/32']));
      for (final secret in [private, hostPrivate]) {
        expect(command.join(' '), isNot(contains(secret)));
      }
    }
    await deliver(() {
      processes.last.line(const host.Step('give-back', host.StepState.done, address: '203.0.113.8'));
      processes.last.end(0);
    });
  });

  // Harm: a store transport failure escapes the dialog or exposes its exception/value.
  // Red: remove the store Exception boundary or show the raw SocketException message.
  for (final operation in ['setup', 'export', 'teardown']) {
    testWidgets('a store SocketException during $operation is a safe dialog refusal', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = Settings(MemorySettingsStore());
      final store = _BrokenSecrets();
      final processes = <_HostProcess>[];
      final destination = File(path.join(scratch.path, 'asked.conf'));
      File? signing;
      if (operation == 'export') {
        await settings.rememberTresorFolder('demo', scratch.path);
        await tester.runAsync(() async {
          signing = await File(
            path.join(scratch.path, 'signing.pub'),
          ).writeAsString('ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4f fixture');
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              machines: machines,
              project: 'demo',
              settings: settings,
              secretStore: store,
              saveTunnel: () async => destination.path,
              start: (_, _) async {
                final process = _HostProcess();
                processes.add(process);
                return process;
              },
            ),
          ),
        ),
      );
      await fillSteps(tester, <String, String>{
        'host-scaleway-project': 'project',
        'host-tresor': 'tresor',
        'host-collection': fixture('collection.tar.gz'),
        if (signing != null) ...{'host-repository': 'url', 'host-signing-key': signing!.path},
      });
      await tester.pump();
      if (operation == 'export') {
        await tapAndRun(tester, const Key('host-up'));
        expect(processes.length, 1);
        await tester.runAsync(() async {
          processes.last.line(
            const host.Step(
              'up',
              host.StepState.done,
              address: '203.0.113.8',
              account: 'porelo',
              socket: '/run/user/1007/porelo/porelod.sock',
            ),
          );
          processes.last.end(0);
          await Future<void>.delayed(Duration.zero);
        });
        await World.settle(tester);
      }
      store.fail = true;
      await tapAndRun(
        tester,
        Key(switch (operation) {
          'setup' => 'host-up',
          'export' => 'host-export-tunnel',
          _ => 'host-down',
        }),
      );
      expect(tester.takeException(), isNull, reason: 'store failures must be rendered instead of escaping');
      expect(find.textContaining('The system secret store could not'), findsOneWidget);
      expect(
        tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').join(),
        isNot(contains('private-value')),
        reason: 'raw store errors are never shown',
      );
      expect(processes.length, operation == 'export' ? 1 : 0, reason: 'store refusal cannot launch a command');
      expect(await tester.runAsync(() => destination.exists()), isFalse);
    });
  }

  // Harm: setup rents a host using a person key that cannot be recovered from the store.
  // Red: remove the store read-back equality check or start the command before preparation.
  for (final alter in [false, true]) {
    testWidgets('a ${alter ? 'different read-back' : 'dropped store write'} blocks the host command', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              machines: machines,
              project: 'demo',
              secretStore: _BrokenSecrets()
                ..drop = !alter
                ..alter = alter,
              start: (_, _) async {
                starts++;
                return _HostProcess();
              },
            ),
          ),
        ),
      );
      await fillSteps(tester, <String, String>{
        'host-scaleway-project': 'project',
        'host-tresor': 'tresor',
        'host-collection': fixture('collection.tar.gz'),
      });
      await tester.pump();
      await tapAndRun(tester, const Key('host-up'));
      expect(starts, 0);
      expect(find.textContaining('The secret store did not keep the WireGuard key'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // Prevents connecting before setup succeeds, losing an existing host on a failed down,
  // or saving the form's account instead of the destination the command confirmed.
  // Red: offer Add on the done step before exit 0, add automatically, ignore the done values,
  // skip replacing a same-name host, or forget it when down starts or fails.
  testWidgets('confirmed up uses its destination and down for another account keeps the host', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const old = Machine(
      name: 'demo server',
      kind: 'host',
      socketPath: '/tmp/old.sock',
      host: 'old@192.0.2.1',
      remoteSocket: '/run/user/42/porelo/porelod.sock',
      identity: '/keys/old',
    );
    await machines.add(old);
    await machines.forget(machines.all.firstWhere((machine) => machine.kind != 'host'));
    expect(machines.all, <Machine>[old], reason: 'replacement must work for the sole machine too');
    final processes = <_HostProcess>[];
    final starts = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            secretStore: _MemorySecrets(),
            machines: machines,
            project: 'demo',
            start: (_, arguments) async {
              starts.add(arguments.first);
              final process = _HostProcess();
              processes.add(process);
              return process;
            },
          ),
        ),
      ),
    );
    await fillSteps(tester, <String, String>{
      'host-scaleway-project': 'project-1',
      'host-tresor': 'drive',
      'host-collection': fixture('collection.tar.gz'),
      'host-identity': fixture('new'),
      'host-account': 'form-account',
    });
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('host-up')));
    await tester.tap(find.byKey(const Key('host-up')));
    await World.settle(tester);
    const done = host.Step(
      'up',
      host.StepState.done,
      address: '203.0.113.9',
      account: 'actual-account',
      socket: '/run/user/1099/porelo/porelod.sock',
    );
    processes.last.line(done);
    await World.settle(tester);
    expect(find.byKey(const Key('host-add')), findsNothing, reason: 'a done line is not exit 0');
    expect(machines.all, <Machine>[old]);
    processes.last.end(65);
    await World.settle(tester);
    expect(find.byKey(const Key('host-add')), findsNothing, reason: 'a refused up must not be added');
    expect(machines.all, <Machine>[old]);
    await navigate(tester, 'wizard-back');
    await tester.tap(find.byKey(const Key('host-up')));
    await World.settle(tester);
    processes.last.line(done);
    processes.last.end(0);
    await World.settle(tester);
    expect(machines.all, <Machine>[old], reason: 'adding is a separate decision');
    await tester.ensureVisible(find.byKey(const Key('host-add')));
    await tester.tap(find.byKey(const Key('host-add')));
    await World.settle(tester);
    final added = machines.all.single;
    expect(added.name, 'demo server');
    expect(added.kind, 'host');
    expect(added.hostProject, 'demo');
    expect(
      Machine.fromStored(added.stored).hostProject,
      'demo',
      reason: 'teardown must still find its record after restart',
    );
    expect(added.host, 'actual-account@203.0.113.9');
    expect(added.remoteSocket, '/run/user/1099/porelo/porelod.sock');
    expect(added.identity, fixture('new'));
    expect(added.socketPath, Machine.endpointFor('demo server'));
    for (final code in <int>[65, 75, 0]) {
      await tester.ensureVisible(find.byKey(const Key('host-down')));
      await tester.tap(find.byKey(const Key('host-down')));
      await World.settle(tester);
      expect(machines.all, <Machine>[added], reason: 'down has not answered');
      processes.last.line(const host.Step('give-back', host.StepState.done, address: '203.0.113.9'));
      await World.settle(tester);
      expect(machines.all, <Machine>[added], reason: 'a done step is not a successful command exit');
      processes.last.end(code);
      await World.settle(tester);
      if (code != 0) expect(machines.all, <Machine>[added], reason: 'failed or waiting down keeps the machine');
    }
    expect(machines.all, <Machine>[added], reason: 'down used form-account, not the account in the saved destination');
    expect(starts, <String>['up', 'up', 'down', 'down', 'down']);
  });

  // Prevents forgetting a still-billed server after down found no host or a different account.
  // Red: remove by project name, remove all hosts, ignore account, or forget without an address.
  for (final found in <bool>[false, true]) {
    testWidgets('down ${found ? 'removes only the matching destination' : 'without an address keeps every machine'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const named = Machine(
        name: 'demo server',
        kind: 'host',
        socketPath: '/tmp/named.sock',
        host: 'porelo@203.0.113.8',
        remoteSocket: '/run/user/1007/porelo/porelod.sock',
        identity: '/keys/host',
      );
      const matching = Machine(
        name: 'other server',
        kind: 'host',
        socketPath: '/tmp/matching.sock',
        host: 'porelo@203.0.113.9',
        remoteSocket: '/run/user/1007/porelo/porelod.sock',
        identity: '/keys/host',
      );
      const otherAccount = Machine(
        name: 'another account',
        kind: 'host',
        socketPath: '/tmp/account.sock',
        host: 'other@203.0.113.9',
        remoteSocket: '/run/user/1008/porelo/porelod.sock',
        identity: '/keys/host',
      );
      const ordinary = Machine(
        name: 'ordinary',
        socketPath: '/tmp/ordinary.sock',
        host: 'porelo@203.0.113.9',
        remoteSocket: '/run/user/1007/porelo/porelod.sock',
      );
      for (final machine in <Machine>[named, matching, otherAccount, ordinary]) {
        await machines.add(machine);
      }
      final before = machines.all;
      final processes = <_HostProcess>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              secretStore: _MemorySecrets(),
              machines: machines,
              project: 'demo',
              start: (_, _) async {
                final process = _HostProcess();
                processes.add(process);
                return process;
              },
            ),
          ),
        ),
      );
      await fillSteps(tester, <String, String>{
        'host-scaleway-project': 'project-1',
        'host-tresor': 'drive',
        'host-collection': fixture('collection.tar.gz'),
      });
      await tester.pump();
      for (final code in <int>[65, 75, 0]) {
        await tester.ensureVisible(find.byKey(const Key('host-down')));
        await tester.tap(find.byKey(const Key('host-down')));
        await World.settle(tester);
        expect(machines.all, before);
        processes.last.line(host.Step('give-back', host.StepState.done, address: found ? '203.0.113.9' : null));
        await World.settle(tester);
        expect(machines.all, before, reason: 'a line alone cannot confirm successful teardown');
        processes.last.end(code);
        await World.settle(tester);
        expect(
          machines.all,
          found && code == 0 ? before.where((machine) => machine != matching).toList() : before,
          reason: 'only the matching destination after exit 0 can be removed',
        );
      }
      if (!found) expect(find.textContaining('No host was found'), findsOneWidget);
    });
  }

  // Prevents an incomplete or malformed completion from creating an unintended SSH destination.
  // Red: accept missing destination fields, option-like addresses or a non-account socket.
  for (final done in <host.Step>[
    const host.Step('up', host.StepState.done),
    const host.Step(
      'up',
      host.StepState.done,
      address: '-bad',
      account: 'user',
      socket: '/run/user/1/porelo/porelod.sock',
    ),
    const host.Step('up', host.StepState.done, address: 'host', account: 'user', socket: '/tmp/other.sock'),
    const host.Step(
      'up',
      host.StepState.done,
      address: 'host',
      account: '-bad',
      socket: '/run/user/1/porelo/porelod.sock',
    ),
    const host.Step(
      'up',
      host.StepState.done,
      address: 'host',
      account: 'user; touch bad',
      socket: '/run/user/1/porelo/porelod.sock',
    ),
  ]) {
    testWidgets('an invalid completion is refused when adding: ${done.toLine()}', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final process = _HostProcess();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              secretStore: _MemorySecrets(),
              machines: machines,
              project: 'demo',
              start: (_, _) async => process,
            ),
          ),
        ),
      );
      await fillSteps(tester, <String, String>{
        'host-scaleway-project': 'p',
        'host-tresor': 'd',
        'host-collection': fixture('collection.tar.gz'),
      });
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('host-up')));
      await tester.tap(find.byKey(const Key('host-up')));
      await World.settle(tester);
      process.line(done);
      process.end(0);
      await World.settle(tester);
      await tester.ensureVisible(find.byKey(const Key('host-add')));
      await tester.tap(find.byKey(const Key('host-add')));
      await World.settle(tester);
      expect(machines.all.where((machine) => machine.kind == 'host'), isEmpty);
      expect(find.textContaining('did not name a valid'), findsOneWidget);
    });
  }

  // Changing the host identity can make down report success while the rented host keeps billing.
  testWidgets('host fields stay read-only after up and down targets exactly the same host', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            secretStore: _MemorySecrets(),
            machines: machines,
            project: 'demo',
            start: stopsThenGoesOn(),
          ),
        ),
      ),
    );
    final fields = <String, String>{
      'host-scaleway-project': 'project-1',
      'host-tresor': 'demo-drive',
      'host-account': 'demo-user',
      'host-public-key': fixture('demo.pub'),
      'host-identity': fixture('demo-key'),
      'host-collection': fixture('collection.tar.gz'),
    };
    await fillSteps(tester, fields, beforeFill: (field, _) => expect(field.readOnly, isFalse));
    await tester.pump();
    await tapAndRun(tester, const Key('host-up'));
    expect(find.byKey(const Key('host-stop')), findsOneWidget);
    Future<void> checkLockedFields() async {
      for (var step = 0; step < 5; step++) {
        await navigate(tester, 'wizard-back');
        if (find.byKey(const Key('wizard-confirm-back')).evaluate().isNotEmpty) {
          await navigate(tester, 'wizard-confirm-back');
        }
      }
      final seen = <String>{};
      for (var step = 0; step < 4; step++) {
        for (final entry in fields.entries) {
          final found = find.byKey(Key(entry.key));
          if (found.evaluate().isEmpty) continue;
          seen.add(entry.key);
          final field = tester.widget<TextField>(found);
          expect(
            field.readOnly,
            isTrue,
            reason: '${entry.key} must not redirect teardown after a host has been rented',
          );
          expect(field.controller!.text, entry.value, reason: 'host identity stays locked for the rest of the dialog');
        }
        await navigate(tester, 'wizard-next');
      }
      expect(seen, fields.keys.toSet(), reason: 'every host identity field must have been inspected');
    }

    await checkLockedFields();
    await tapAndRun(tester, const Key('host-down'));
    final up = File(path.join(scratch.path, 'arguments-1')).readAsLinesSync();
    expect(File(path.join(scratch.path, 'arguments-2')).readAsLinesSync(), <String>[
      'down',
      ...up.skip(1),
    ], reason: 'teardown must find the host that up rented');
    expect(find.byKey(const Key('host-done')), findsOneWidget);
    await checkLockedFields();
  });

  // Unknown stops must not be hidden or repeatedly resumed with answers that cannot satisfy them.
  for (final needs in <List<String>>[
    <String>['agent-login:pi'],
    <String>['drive', 'vault', 'agent-login:pi'],
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
              secretStore: _MemorySecrets(),
              machines: machines,
              project: 'demo',
              start: stopsThenGoesOn(needs: needs),
            ),
          ),
        ),
      );
      await fillSteps(tester, {
        'host-scaleway-project': 'project-1',
        'host-tresor': 'demo-drive',
        'host-collection': fixture('collection.tar.gz'),
      });
      await tester.pump();
      await tapAndRun(tester, const Key('host-up'));
      expect(find.byKey(const Key('host-stop')), findsOneWidget);
      if (needs.isEmpty) {
        expect(find.textContaining('without saying for what'), findsOneWidget);
      } else {
        expect(
          find.textContaining(needs.last),
          findsOneWidget,
          reason: 'the command requirement must be shown verbatim',
        );
        expect(find.textContaining('this interface cannot answer it yet'), findsOneWidget);
      }
      expect(find.byKey(const Key('host-agent-login')), findsNothing);
      expect(
        File(path.join(scratch.path, 'arguments-2')).existsSync(),
        isFalse,
        reason: 'a stop must never rerun up on its own',
      );
      if (needs.contains('drive')) {
        await tester.enterText(find.byKey(const Key('host-drive-email')), 'me@example.org');
        await tester.pump();
      }
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FilledButton && widget.key == const Key('host-open-terminal') && widget.onPressed != null,
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
          body: HostDialog(
            secretStore: _MemorySecrets(),
            machines: machines,
            project: 'demo',
            start: stopsThenGoesOn(),
          ),
        ),
      ),
    );
    await fillSteps(tester, {'host-scaleway-project': 'project-1'}, stopAt: 1);
    expect(find.byKey(const Key('host-up')), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed,
      isNull,
      reason: 'the drive must be named before a host can be rented',
    );
    await tester.enterText(find.byKey(const Key('host-tresor')), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('host-tresor')), 'demo-drive');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNotNull);
    await navigate(tester, 'wizard-next');
    await tester.enterText(find.byKey(const Key('host-identity')), fixture('default'));
    await tester.enterText(find.byKey(const Key('host-public-key')), fixture('default.pub'));
    await tester.pump();
    await navigate(tester, 'wizard-next');
    await tester.enterText(find.byKey(const Key('host-collection')), fixture('collection.tar.gz'));
    await tester.pump();
    await navigate(tester, 'wizard-next');
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-up'))).onPressed, isNotNull);
  });

  const prefix = r'export XDG_RUNTIME_DIR=/run/user/$(id -u) && ';
  const login =
      r"printf '%s\n' 'The one-time code will show as you type it.' && "
      "tresorit-cli login --email 'me@example.org' --password-on-stdin && ";
  const loginLast = r"printf '%s\n' 'Logged in to Tresorit; close this terminal to continue host setup.'";
  const loginNext = r"printf '%s\n' 'Logged in to Tresorit; the vault comes next.' && ";
  const init =
      "porelo vault init && "
      r"printf '%s\n' 'Vault initialized; close this terminal to continue host setup.'";
  const unlock =
      "porelo vault unlock && "
      r"printf '%s\n' 'Vault unlocked; close this terminal to continue host setup.'";
  final commands = <List<String>, String>{
    ['drive']: '$prefix$login$loginLast',
    ['vault-new']: '$prefix$init',
    ['vault']: '$prefix$unlock',
    ['drive', 'vault-new']: '$prefix$login$loginNext$init',
    ['drive', 'vault']: '$prefix$login$loginNext$unlock',
  };

  // Harm: a secret enters the interface widgets, or SSH trusts a key setup did not pin.
  for (final entry in commands.entries) {
    testWidgets('stop ${entry.key} takes no secret and opens exactly its pinned host command', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final terminals = <FakeTerminal>[];
      final before = machines.all;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              secretStore: _MemorySecrets(),
              machines: machines,
              project: 'demo',
              start: stopsThenGoesOn(needs: entry.key),
              openTerminal: (program, arguments, {columns = 80, rows = 24}) {
                final terminal = FakeTerminal([program, ...arguments]);
                terminals.add(terminal);
                return terminal;
              },
            ),
          ),
        ),
      );
      await fillSteps(tester, <String, String>{
        'host-scaleway-project': 'project-1',
        'host-tresor': 'drive',
        'host-collection': fixture('collection.tar.gz'),
        'host-identity': fixture('dialog identity'),
        'host-account': 'form-account',
      });
      await tester.pump();
      await tapAndRun(tester, const Key('host-up'));
      final fields = tester
          .widgetList<TextField>(
            find.descendant(of: find.byKey(const Key('host-stop')), matching: find.byType(TextField)),
          )
          .toList();
      expect(fields.map((field) => field.key), entry.key.contains('drive') ? [const Key('host-drive-email')] : isEmpty);
      for (final field in fields) {
        expect(field.obscureText, isFalse, reason: 'no secret belongs in the stop widgets');
        expect(field.key.toString(), isNot(matches('password|code|passphrase|again')));
      }
      for (final key in ['host-drive-password', 'host-drive-code', 'host-passphrase', 'host-passphrase-again']) {
        expect(find.byKey(Key(key)), findsNothing);
      }
      if (entry.key.contains('drive')) {
        await tester.enterText(find.byKey(const Key('host-drive-email')), 'me@example.org');
        await tester.pump();
      }
      await tapAndRun(tester, const Key('host-open-terminal'));
      expect(terminals, hasLength(1));
      final command = terminals.single.command;
      expect(
        pinnedCommandProblems(command, knownHosts: host.poreloHostKnownHosts(), identity: fixture('dialog identity')),
        isEmpty,
      );
      expect(command.first, 'ssh');
      expect(command.skip(1 + expectedPinnedOptions.length), [
        '-t',
        'actual-account@203.0.113.7',
        host.inTheLoginShell(entry.value),
      ]);
      expect(machines.all, before, reason: 'the momentary terminal machine is never saved');
      expect(File('${scratch.path}/arguments-2').existsSync(), isFalse, reason: 'up waits for terminal dismissal');
      terminals.single.endsWith(65);
      await World.settle(tester);
      expect(find.byKey(const Key('host-done')), findsNothing, reason: 'terminal exit is no setup verdict');
      await tapAndRun(tester, const Key('unlock-done'));
      expect(find.byKey(const Key('host-done')), findsOneWidget, reason: 'only the second up confirms completion');
      final first = File('${scratch.path}/arguments-1').readAsLinesSync();
      expect(File('${scratch.path}/arguments-2').readAsLinesSync(), first);
      for (var n = 1; n <= 2; n++) {
        expect(File('${scratch.path}/input-$n').readAsStringSync(), isEmpty);
      }
    });
  }

  // Harm: a shell metacharacter in the e-mail changes what runs on the host.
  for (final email in [
    "me'@example.org",
    r'me$(id)@example.org',
    'me;@example.org',
    'me @example.org',
    '-me@example.org',
  ]) {
    testWidgets('unsafe e-mail $email is refused without opening a terminal', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              secretStore: _MemorySecrets(),
              machines: machines,
              project: 'demo',
              start: stopsThenGoesOn(),
              openTerminal: (_, _, {columns = 80, rows = 24}) {
                opened++;
                return FakeTerminal([]);
              },
            ),
          ),
        ),
      );
      await fillSteps(tester, <String, String>{
        'host-scaleway-project': 'p',
        'host-tresor': 't',
        'host-collection': fixture('collection.tar.gz'),
      });
      await tester.pump();
      await tapAndRun(tester, const Key('host-up'));
      await tester.enterText(find.byKey(const Key('host-drive-email')), email);
      await tester.pump();
      await tapAndRun(tester, const Key('host-open-terminal'));
      expect(opened, 0);
      expect(find.textContaining('Enter a plain Tresorit e-mail address'), findsOneWidget);
      expect(find.byKey(const Key('unlock-terminal')), findsNothing);
      expect(File('${scratch.path}/arguments-2').existsSync(), isFalse);
    });
  }
}

/// A command whose output and exit are independently controlled by the test.
class _HostProcess extends Fake implements Process {
  _HostProcess() {
    _input.stream.listen((_) {});
    _stdin = IOSink(_input.sink);
  }
  final _input = StreamController<List<int>>();
  final _output = StreamController<List<int>>();
  final _errors = StreamController<List<int>>();
  final _exit = Completer<int>();
  late final IOSink _stdin;
  void line(host.Step step) => _output.add(utf8.encode('${step.toLine()}\n'));
  void end(int code) {
    unawaited(_output.close());
    unawaited(_errors.close());
    _exit.complete(code);
  }

  @override
  IOSink get stdin => _stdin;
  @override
  Stream<List<int>> get stdout => _output.stream;
  @override
  Stream<List<int>> get stderr => _errors.stream;
  @override
  Future<int> get exitCode => _exit.future;
}

/// Keeps transport out of the dialog tests; the SSH argv has its own guards.
class _HostTunnels extends Tunnels {
  @override
  Future<bool> raiseFor(Machine machine) async => true;
  @override
  Future<void> dropFor(Machine machine) async {}
}

class _MemorySecrets implements host.SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> write(String name, String value) async {
    values[name] = value;
  }

  @override
  Future<void> remove(String name) async => values.remove(name);
  @override
  Future<void> close() async {}
}

class _BrokenSecrets extends _MemorySecrets {
  bool fail = false;
  bool drop = false;
  bool alter = false;
  @override
  Future<String?> read(String name) async {
    if (fail) throw const SocketException('private-value');
    return super.read(name);
  }

  @override
  Future<void> write(String name, String value) async {
    if (fail) throw const SocketException('private-value');
    if (!drop) await super.write(name, alter ? base64Encode(List.filled(32, 7)) : value);
  }
}
