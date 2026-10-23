// A stand-in `porelo-host` is a small `sh`, which only Linux has here.
@Tags(<String>['linux'])
library;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_session.dart';

import '../features/support/world.dart';

import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';

import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_host/porelo_host.dart' as host;

void main() {
  late Directory scratch;
  late Machines machines;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('host-dialog-');
    machines = Machines(Settings(MemorySettingsStore()), reach: (_) => FakeBackend(const []), tunnels: _HostTunnels());
  });
  tearDown(() => machines.dispose());
  tearDown(() => scratch.delete(recursive: true));

  /// A stand-in `porelo-host`: the first start stops for the drive and a new vault, the second
  /// keeps what came on its standard input and ends done. Every start's arguments are kept.
  StartHostCommand stopsThenGoesOn({List<String> needs = const <String>['drive', 'vault-new']}) {
    var starts = 0;
    final waiting = host.Step('person', host.StepState.waiting, needs: needs).toLine();
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
      await Directory('${scratch.path}/porelo-host').create();
      conflict = await File('${scratch.path}/porelo-host/machine.yml').writeAsString('keep');
      signing = await File('${scratch.path}/signing.pub')
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
    for (final entry in <String, String>{
      'host-scaleway-project': 'project',
      'host-tresor': 'tresor',
      'host-collection': 'collection',
      'host-repository': 'https://example.org/demo.git',
      'host-signing-key': signing.path,
    }.entries) {
      await tester.enterText(find.byKey(Key(entry.key)), entry.value);
    }
    await tester.pump();
    await tapAndRun(tester, const Key('host-up'));
    expect(starts, 0, reason: 'file conflicts must block renting');
    expect(find.textContaining(conflict.path), findsOneWidget);
    expect(await tester.runAsync(() => conflict.readAsString()), 'keep');
  });

  // Harm: the private key reaches a process/log/UI, or resume/down configure the wrong peer.
  // Red: pass a private key as the peer option, show it in a step, or omit the options on resume/down.
  // Export red: omit chmod, put the host private half in the export, or export before the button is used.
  testWidgets('folder picker prepares files and only explicit export reads out the stored private half', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
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

    final exported = File('${scratch.path}/requested.conf');
    late File signing;
    await tester.runAsync(() async {
      signing = await File('${scratch.path}/signing.pub')
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
    expect(find.textContaining('Copy machine.yml'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('host-folder')));
    await tester.tap(find.byKey(const Key('host-folder')));
    await World.settle(tester);
    expect(settings.tresorFolder('demo'), scratch.path);
    for (final entry in <String, String>{
      'host-scaleway-project': 'project',
      'host-tresor': 'tresor',
      'host-collection': 'collection',
      'host-repository': 'https://example.org/demo.git',
      'host-signing-key': signing.path,
    }.entries) {
      await tester.enterText(find.byKey(Key(entry.key)), entry.value);
    }
    await tester.pump();
    await tapAndRun(tester, const Key('host-up'));
    expect(commands.length, 1);
    await deliver(() {
      processes.last.line(const host.Step('person', host.StepState.waiting, needs: ['vault']));
      processes.last.end(75);
    });
    expect(find.byKey(const Key('host-stop')), findsOneWidget);
    final passphrase = find.byKey(const Key('host-passphrase'));
    expect(passphrase, findsOneWidget, reason: 'exit 75 with a vault need must build the secret field');
    await tester.ensureVisible(passphrase);
    await tester.enterText(passphrase, 'vault-answer');
    await tester.pump();
    await tapAndRun(tester, const Key('host-resume'));
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
    final hostPrivate = (await tester.runAsync(() => File('${scratch.path}/porelo-host/wireguard.key').readAsString()))!
        .trim();
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
      final destination = File('${scratch.path}/asked.conf');
      File? signing;
      if (operation == 'export') {
        await settings.rememberTresorFolder('demo', scratch.path);
        await tester.runAsync(() async {
          signing = await File(
            '${scratch.path}/signing.pub',
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
      for (final entry in <String, String>{
        'host-scaleway-project': 'project',
        'host-tresor': 'tresor',
        'host-collection': 'collection',
        if (signing != null) ...{'host-repository': 'url', 'host-signing-key': signing!.path},
      }.entries) {
        await tester.enterText(find.byKey(Key(entry.key)), entry.value);
      }
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
      for (final entry in {
        'host-scaleway-project': 'project',
        'host-tresor': 'tresor',
        'host-collection': 'collection',
      }.entries) {
        await tester.enterText(find.byKey(Key(entry.key)), entry.value);
      }
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
    for (final entry in <String, String>{
      'host-scaleway-project': 'project-1',
      'host-tresor': 'drive',
      'host-collection': '/tmp/collection.tar.gz',
      'host-identity': '/keys/new',
      'host-account': 'form-account',
    }.entries) {
      await tester.enterText(find.byKey(Key(entry.key)), entry.value);
    }
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
    expect(added.host, 'actual-account@203.0.113.9');
    expect(added.remoteSocket, '/run/user/1099/porelo/porelod.sock');
    expect(added.identity, '/keys/new');
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
      for (final entry in <String, String>{
        'host-scaleway-project': 'project-1',
        'host-tresor': 'drive',
        'host-collection': 'collection',
      }.entries) {
        await tester.enterText(find.byKey(Key(entry.key)), entry.value);
      }
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
      for (final entry in <String, String>{
        'host-scaleway-project': 'p',
        'host-tresor': 'd',
        'host-collection': 'c',
      }.entries) {
        await tester.enterText(find.byKey(Key(entry.key)), entry.value);
      }
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
          find.textContaining(needs.last),
          findsOneWidget,
          reason: 'the command requirement must be shown verbatim',
        );
        expect(find.textContaining('this interface cannot answer it yet'), findsOneWidget);
      }
      expect(find.byKey(const Key('host-agent-login')), findsNothing);
      expect(
        File('${scratch.path}/arguments-2').existsSync(),
        isFalse,
        reason: 'a stop must never rerun up on its own',
      );
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
          body: HostDialog(
            secretStore: _MemorySecrets(),
            machines: machines,
            project: 'demo',
            start: stopsThenGoesOn(),
          ),
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

  testWidgets('drive and vault stops send secrets only on stdin and keep exactly the same host arguments', (
    tester,
  ) async {
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
            start: stopsThenGoesOn(needs: const <String>['drive', 'vault-new']),
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
    expect(find.byKey(const Key('host-agent-login')), findsNothing, reason: 'host setup never signs agents in');
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
