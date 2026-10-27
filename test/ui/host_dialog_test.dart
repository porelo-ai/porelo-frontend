// Private-file protection uses Linux libc without starting a permission process.
@Tags(<String>['linux'])
library;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' hide Size;

import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/host_protocol.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';
import '../../packages/porelo_host/test/support/pinned_ssh.dart';

import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/tunnel.dart';

import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_frontend/src/ui/wizard.dart';
import 'package:porelo_frontend/src/ui/host_vpn_dialog.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';
import 'package:porelo_frontend/src/ui/host_stop_dialog.dart';
import 'package:porelo_host/porelo_host.dart' as host;

import '../support/expand_list_rows.dart';

Future<Process> _acceptedKey(String executable, List<String> arguments) async => _HostProcess()..end(0);

void main() {
  late Directory scratch;
  late Machines machines;
  late HostRuns runs;
  late _HostFileWork fileWork;
  final settingsModels = <Settings>[];

  Settings newSettings(SettingsStore store) {
    final settings = Settings(store);
    settingsModels.add(settings);
    return settings;
  }

  host.HostFiles filesFor(host.SecretStore store) => _ControlledHostFiles(store, fileWork);
  String fixture(String name) => path.join(scratch.path, name);
  final collectionDigest = sha256.convert(utf8.encode('invented-private-or-setup-fixture')).toString();
  // The key the project's commit is signed with: the drive puts only a commit the chosen key signed.
  late String signingPublic;
  setUp(() async {
    fileWork = _HostFileWork();
    scratch = await Directory.systemTemp.createTemp('host-dialog-');
    final keygen = await Process.run('ssh-keygen', [
      '-q',
      '-t',
      'ed25519',
      '-N',
      '',
      '-C',
      'fixture',
      '-f',
      fixture('signer'),
    ]);
    expect(keygen.exitCode, 0, reason: 'ssh-keygen: ${keygen.stderr}');
    signingPublic = File(fixture('signer.pub')).readAsStringSync();
    for (final name in ['default', 'private', 'new', 'dialog identity', 'demo-key', 'collection.tar.gz']) {
      File(fixture(name)).writeAsStringSync('invented-private-or-setup-fixture');
    }
    for (final name in ['default.pub', 'public.pub', 'id_ed25519.pub', 'demo.pub', 'signing.pub']) {
      File(fixture(name)).writeAsStringSync(signingPublic);
    }
    final source = Directory(fixture('project source'))..createSync();
    Future<String> git(List<String> arguments) async {
      final result = await Process.run(
        'git',
        arguments,
        workingDirectory: source.path,
        environment: {'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'},
      );
      expect(result.exitCode, 0, reason: 'git $arguments: ${result.stderr}');
      return '${result.stdout}'.trim();
    }

    await git(['init', '--initial-branch=main']);
    File(path.join(source.path, 'project.yml')).writeAsStringSync('name: demo\n');
    await git(['add', 'project.yml']);
    await git([
      '-c',
      'user.name=Fixture',
      '-c',
      'user.email=fixture@example.invalid',
      '-c',
      'gpg.format=ssh',
      '-c',
      'user.signingkey=${fixture('signer')}',
      'commit',
      '-S',
      '-m',
      'Project fixture',
    ]);
    final commit = await git(['rev-parse', 'HEAD']);
    final backend = FakeBackend(const [])
      ..theProjectsItHas = [
        Project.from({
          'name': 'demo',
          'following': {'name': 'demo', 'url': source.path, 'commit': commit},
        }),
      ];
    machines = Machines(newSettings(MemorySettingsStore()), reach: (_) => backend, tunnels: _HostTunnels());
    runs = HostRuns(
      machines,
      endpointFor: (name) => '/tmp/${Machine.slug(name)}.sock',
      probeLink: () async => false,
      ping: () async => false,
    );
  });

  void hostWidgets(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.runAsync(fileWork.complete);
        await tester.pumpWidget(const SizedBox.shrink());
        runs.dispose();
        machines.dispose();
        for (final settings in settingsModels) {
          settings.dispose();
        }
        settingsModels.clear();
      }
    });
  }

  tearDown(() => scratch.delete(recursive: true));

  for (final outcome in [
    'down',
    'cancelled',
    'already down',
    'still up',
    'terminal failed',
    'probe refused',
    'recheck refused',
  ]) {
    // Harm: unchecked give-back hides a dead tunnel or runs an unnecessary root command.
    hostWidgets('give-back waits for the local VPN when $outcome', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var linkUp = outcome != 'already down';
      var probeRefused = outcome == 'probe refused';
      runs.dispose();
      runs = HostRuns(
        machines,
        probeLink: () async {
          if (probeRefused) throw const host.HostFilesRefused('The local VPN interface could not be checked.');
          return linkUp;
        },
        ping: () async => false,
      );
      final attention = Attention(machines, machines.settings)..hostRuns = runs;
      addTearDown(attention.dispose);
      const server = Machine(
        name: 'demo server',
        kind: 'host',
        hostProject: 'demo',
        socketPath: '/unused',
        host: 'porelo@203.0.113.9',
        remoteSocket: '/run/user/1007/porelo/porelod.sock',
      );
      await machines.add(server);
      await machines.settings.rememberHostUp(
        'demo',
        const HostUpRecord(
          scalewayProject: 'provider',
          account: 'porelo',
          tresor: 'drive',
          folder: null,
          repository: '',
          signingKey: '',
          identity: '/keys/private',
          publicKey: '/keys/public.pub',
          collection: '/setup',
          vpnPeerPublicKey: '',
          vpnPeerAddress: '',
        ),
      );
      final process = _HostProcess();
      var providerCalls = 0;
      final terminal = FakeTerminal([]);
      final commands = <List<String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HostDialog(
            openSecretsFile: _secretsOpened,
            project: 'demo',
            machines: machines,
            settings: machines.settings,
            hostRuns: runs,
            takeDownOnly: true,
            start: (_, _) async {
              providerCalls++;
              return process;
            },
            openTerminal: (executable, arguments, {int columns = 80, int rows = 24}) {
              commands.add([executable, ...arguments]);
              return terminal;
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('host-down')));
      await World.settle(tester);
      process.line(const host.Step('give-back', host.StepState.done, address: '203.0.113.9'));
      await World.settle(tester);
      expect(commands, isEmpty, reason: 'a provider step without exit zero cannot authorize VPN teardown');
      process.end(0);
      await World.settle(tester);
      if (outcome == 'already down') {
        expect(commands, isEmpty, reason: 'an absent tunnel must not open a sudo terminal');
      } else if (probeRefused) {
        expect(commands, isEmpty, reason: 'an unreadable link cannot authorize a sudo command');
        expect(
          find.byKey(const Key('vpn-problem')),
          findsOneWidget,
          reason: 'a failed probe must be refused before any terminal opens',
        );
        await tester.tap(
          find.descendant(
            of: find.ancestor(of: find.byKey(const Key('vpn-problem')), matching: find.byType(AlertDialog)),
            matching: find.widgetWithText(TextButton, 'Close'),
          ),
        );
        await World.settle(tester);
      } else {
        expect(commands, [
          ['/usr/bin/sudo', 'wg-quick', 'down', 'porelo'],
        ], reason: 'confirmed server release must take the local tunnel down as its last step');
        expect(machines.all.contains(server), isFalse, reason: 'the provider release is confirmed before VPN cleanup');
        expect(
          find.byKey(const Key('host-done')),
          findsNothing,
          reason: 'provider release alone cannot complete teardown while the VPN is up',
        );
        if (outcome == 'cancelled') {
          await tester.tap(find.byKey(const Key('unlock-cancel')));
          await World.settle(tester);
          await tester.tap(find.byKey(const Key('unlock-cancel-yes')));
        } else {
          linkUp = outcome != 'down';
          probeRefused = outcome == 'recheck refused';
          terminal.endsWith(outcome == 'terminal failed' ? 65 : 0);
          await World.settle(tester);
          await tester.tap(find.byKey(const Key('unlock-done')));
        }
        await World.settle(tester);
      }
      final completed = outcome == 'down' || outcome == 'already down';
      expect(
        find.byKey(const Key('host-done')),
        completed ? findsOneWidget : findsNothing,
        reason: 'only a measured absent tunnel can complete give-back',
      );
      final leftovers = attention.openRows.where((row) => row.machine == server.name);
      expect(
        leftovers,
        completed ? isEmpty : hasLength(1),
        reason: 'removing the server from Machines must not discard unfinished tunnel cleanup',
      );
      if (!completed) {
        if (outcome == 'cancelled') {
          expect(
            find.text('The server is given back; the VPN on this computer is still up'),
            findsOneWidget,
            reason: 'cancelling sudo must leave the unfinished cleanup visible',
          );
        }
        final retryTerminal = FakeTerminal([]);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => AttentionView(
                  attention: attention,
                  onDecide: (_, _, {required allow}) {},
                  onReview: (_) {},
                  actionsFor: (_) => [],
                  onTakeVpnDown: (machine) async {
                    expect(machine.hostProject, 'demo', reason: 'cleanup must name the server that was given back');
                    await openHostVpnDialog(
                      context,
                      machine: machine,
                      settings: machines.settings,
                      up: false,
                      probeLink: runs.probeVpnLink,
                      open: (executable, arguments, {int columns = 80, int rows = 24}) {
                        commands.add([executable, ...arguments]);
                        return retryTerminal;
                      },
                    );
                    await runs.refreshVpns();
                  },
                ),
              ),
            ),
          ),
        );
        await World.settle(tester);
        probeRefused = false;
        final beforeRetry = commands.length;
        if (outcome == 'still up') linkUp = false;
        await expandListRows(tester);
        final row = find.byKey(const ValueKey('vpn-cleanup demo'));
        final action = find.descendant(of: row, matching: find.widgetWithText(TextButton, 'Take the VPN down'));
        expect(action, findsOneWidget, reason: 'a forgotten server still needs an executable cleanup action');
        await tester.tap(action);
        await World.settle(tester);
        if (linkUp) {
          expect(commands.skip(beforeRetry), [
            ['/usr/bin/sudo', 'wg-quick', 'down', 'porelo'],
          ], reason: 'Needs you must retry local teardown rather than bring the VPN back up');
          expect(
            attention.openRows.where((row) => row.kind == AttentionKind.vpnCleanup),
            hasLength(1),
            reason: 'opening the terminal cannot resolve cleanup before its effect is measured',
          );
          linkUp = false;
          retryTerminal.endsWith(0);
          await World.settle(tester);
          await tester.tap(find.byKey(const Key('unlock-done')));
          await World.settle(tester);
        } else {
          expect(commands.length, beforeRetry, reason: 'a retry with the link already gone must not ask for sudo');
        }
        expect(providerCalls, 1, reason: 'retrying VPN cleanup must never give the server back a second time');
        linkUp = false;
        expect(
          attention.openRows.where((row) => row.machine == server.name),
          isEmpty,
          reason: 'cleanup resolves only once the local link is observed gone',
        );
        expect(
          attention.recentlyResolved.where((row) => row.row.kind == AttentionKind.vpnCleanup),
          hasLength(1),
          reason: 'the cleanup result stays readable even though its server has left Machines',
        );
      }
    });
  }

  // Harm: lock contention offers credential-stop actions against a host owned by another setup.
  hostWidgets('a lock refusal does not offer or open the host person stop', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final process = _HostProcess();
    final session = HostSession(
      executable: 'fake',
      arguments: const ['--project', 'demo'],
      start: (_, _) async => process,
    );
    final run = runs.start(
      project: 'demo',
      session: session,
      record: const HostUpRecord(
        scalewayProject: 'provider-project',
        account: 'worker',
        tresor: 'drive',
        folder: null,
        repository: '',
        signingKey: '',
        identity: '/keys/private',
        publicKey: '/keys/public.pub',
        collection: '',
        vpnPeerPublicKey: '',
        vpnPeerAddress: '',
      ),
    );
    process.line(
      const host.Step(
        'lock',
        host.StepState.refused,
        words: 'setup of demo is still running from before',
        fix: 'wait for it, or end it',
      ),
    );
    process.end(host.Exit.waiting);
    await tester.runAsync(() => run.finished);
    expect(session.state, isNot(HostRunState.waiting), reason: 'contention must not be treated as a credential stop');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(project: 'demo', machines: machines, hostRuns: runs, existingRun: run),
        ),
      ),
    );
    await World.settle(tester);
    expect(find.byKey(const Key('host-stop')), findsNothing, reason: 'no person stop may be offered for contention');
    expect(find.byKey(const Key('host-complete-setup')), findsNothing, reason: 'another setup owns the host');
    expect(find.byType(HostStopDialog), findsNothing, reason: 'contention must never open the credential dialog');
  });

  for (final code in [65, 69]) {
    // Harm: advancing with a refused key defers authentication failure until after server setup starts.
    hostWidgets('a key check ending with $code blocks setup until a successful retry', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final checks = <List<String>>[];
      final first = _HostProcess();
      await tester.pumpWidget(
        MaterialApp(
          home: HostDialog(
            openSecretsFile: _secretsOpened,
            project: 'demo',
            machines: machines,
            hostRuns: runs,
            environment: const {'PORELO_HOST_STANDIN': '/fake/porelo-host'},
            checkKey: (executable, arguments) async {
              checks.add([executable, ...arguments]);
              return checks.length == 1 ? first : (_HostProcess()..end(0));
            },
            start: (_, _) async => fail('Host setup must not start while the key is being checked.'),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('host-scaleway-project')), 'provider');
      // Entering text schedules the rebuild that enables Next; a tap does not pump that frame.
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed,
        isNotNull,
        reason: 'the valid project and default account must enable Next before the check can start',
      );
      await tester.tap(find.byKey(const Key('wizard-next')));
      await World.settle(tester);
      expect(checks, [
        ['/fake/porelo-host', 'key', 'check', 'scaleway'],
      ], reason: 'the key check must start before its response is supplied');
      expect(
        find.byKey(const Key('host-tresor')),
        findsNothing,
        reason: 'a pending authentication check must hold the current step',
      );
      first._errors.add(utf8.encode('provider refused or unreachable\n'));
      first.end(code);
      await World.settle(tester);
      expect(checks, [
        ['/fake/porelo-host', 'key', 'check', 'scaleway'],
      ], reason: 'the wizard must check using the configured host executable');
      expect(
        find.byKey(const Key('host-scaleway-project')),
        findsOneWidget,
        reason: 'a refused check must preserve the first step',
      );
      expect(
        find.byKey(const Key('host-scaleway-key-problem')),
        findsOneWidget,
        reason: 'a refused check must have its own visible reason',
      );
      expect(
        find.byKey(const Key('host-set-scaleway-key')),
        findsOneWidget,
        reason: 'a refused credential must be repairable before continuing',
      );
      await tester.tap(find.byKey(const Key('wizard-next')));
      await World.settle(tester);
      expect(checks.length, 2, reason: 'retrying must ask the command again');
      expect(
        find.byKey(const Key('host-tresor')),
        findsOneWidget,
        reason: 'only the successful check may allow step two',
      );
    });
  }

  // Harm: a forgotten server keeps billing without anyone knowing how to find it.
  hostWidgets('removing a host warns before forgetting and offers teardown beside removal', (tester) async {
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
    await expandListRows(tester);
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
    await expandListRows(tester);
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
      admin: 'image-user',
    );
    const done = host.Step(
      'up',
      host.StepState.done,
      address: '203.0.113.7',
      account: 'porelo',
      socket: '/run/user/1007/porelo/porelod.sock',
    );
    return (executable, arguments) async {
      final n = ++starts;
      File('${scratch.path}/arguments-$n').writeAsStringSync('${arguments.join('\n')}\n');
      final process = _HostProcess(inputPath: '${scratch.path}/input-$n');
      process.line(n == 1 ? waiting : done);
      process.end(n == 1 ? 75 : 0);
      return process;
    };
  }

  /// Completes the queued file work, then pumps the fake command or terminal in bounded frames.
  Future<void> tapAndRun(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tester.tap(find.byKey(key));
    await tester.pump();
    if (key == const Key('host-down') && find.byKey(const Key('host-confirm-down')).evaluate().isNotEmpty) {
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('host-confirm-down')));
      await tester.pump();
    }
    await tester.runAsync(fileWork.complete);
    await tester.pump();
    await tester.runAsync(fileWork.complete);
    await World.settle(tester);
  }

  Future<void> navigate(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
    await tester.runAsync(fileWork.complete);
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
      'host-collection-sha256': collectionDigest,
      ...values,
    };
    const fields = [
      ['host-scaleway-project', 'host-account'],
      ['host-tresor', 'host-signing-key'],
      ['host-identity', 'host-public-key'],
      ['host-secrets-file'],
      ['host-collection', 'host-collection-sha256'],
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

  // Harm: release setup can rent a host only after an arbitrary collection override is supplied.
  hostWidgets('release mode reaches review and starts up without a collection override', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final commands = <List<String>>[];
    final process = _HostProcess();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
            project: 'demo',
            machines: machines,
            debug: false,
            secretStore: _MemorySecrets(),
            start: (_, arguments) async {
              commands.add(List.of(arguments));
              return process;
            },
          ),
        ),
      ),
    );
    await fillSteps(tester, {'host-scaleway-project': 'provider', 'host-tresor': 'drive'}, stopAt: 3);
    await navigate(tester, 'wizard-next');
    expect(find.byKey(const Key('host-collection')), findsNothing);
    expect(find.byKey(const Key('host-collection-sha256')), findsNothing);
    expect(find.textContaining(host.hostCollection.version), findsWidgets);
    expect(find.byKey(const Key('host-up')), findsOneWidget);
    await tapAndRun(tester, const Key('host-up'));
    expect(commands, hasLength(1));
    expect(commands.single.first, 'up');
    expect(commands.single, isNot(contains('--collection')));
    expect(commands.single, isNot(contains('--collection-sha256')));
    process.end(65);
    await World.settle(tester);
  });

  // Harm: losing setup answers or the prepared public VPN key strands a rented server after restart.
  hostWidgets('up keeps its arguments before answering and reopening restores every editable step', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemorySettingsStore();
    final settings = newSettings(store);
    await settings.rememberTresorFolder('demo', scratch.path);
    final answers = {
      'host-scaleway-project': 'project',
      'host-account': 'worker',
      'host-tresor': 'remote-drive',
      'host-signing-key': fixture('signing.pub'),
      'host-identity': fixture('private'),
      'host-public-key': fixture('public.pub'),
      'host-collection': fixture('collection.tar.gz'),
      'host-collection-sha256': collectionDigest,
    };
    final process = _HostProcess();
    final commands = <List<String>>[];
    String? hostKeyAtStart;
    String? preparedHostKey;
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          openSecretsFile: _secretsOpened,
          hostFiles: filesFor,
          checkKey: _acceptedKey,
          hostRuns: runs,
          project: 'demo',
          machines: machines,
          settings: settings,
          secretStore: _MemorySecrets(),
          start: (_, arguments) async {
            final persisted = newSettings(store);
            await persisted.load();
            expect(
              hostArguments(persisted.hostUp('demo')!, 'demo'),
              arguments.skip(1).toList(),
              reason: 'the record must be durable before starting a billing host',
            );
            hostKeyAtStart = persisted.hostUp('demo')!.vpnHostPublicKey;
            preparedHostKey = runs.of('demo')!.tunnel!.hostPublicKey;
            commands.add(List.of(arguments));
            return process;
          },
        ),
      ),
    );
    await fillSteps(tester, answers);
    await tapAndRun(tester, const Key('host-up'));
    expect(commands, hasLength(1));
    expect(hostKeyAtStart, isNotEmpty, reason: 'the public host key must survive closing before setup completes');
    expect(hostKeyAtStart, preparedHostKey);
    process.end(65);
    await World.settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    final reopened = newSettings(store);
    await reopened.load();
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          openSecretsFile: _secretsOpened,
          hostFiles: filesFor,
          checkKey: _acceptedKey,
          hostRuns: runs,
          project: 'demo',
          machines: machines,
          settings: reopened,
        ),
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

  // Harm: an ended refusal traps a rented or attempted host behind immutable arguments that cannot be corrected.
  hostWidgets('a refused setup wizard starts a replacement with changed provider and account', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = machines.settings;
    final record = HostUpRecord(
      scalewayProject: 'mistyped-provider',
      account: 'worker',
      tresor: 'drive',
      folder: null,
      signingKey: '',
      identity: fixture('private'),
      publicKey: fixture('public.pub'),
      collection: fixture('collection.tar.gz'),
      collectionSha256: collectionDigest,
      vpnPeerPublicKey: '',
      vpnPeerAddress: '',
    );
    final refused = _HostProcess();
    final first = runs.start(
      project: 'demo',
      record: record,
      settings: settings,
      session: HostSession(
        executable: 'fake',
        arguments: hostArguments(record, 'demo'),
        start: (_, _) async => refused,
      ),
    );
    refused.line(const host.Step('rent', host.StepState.refused));
    refused.end(65);
    await World.settle(tester);
    await first.finished;
    final commands = <List<String>>[];
    final process = _HostProcess();
    await tester.pumpWidget(
      MaterialApp(
        home: HostDialog(
          openSecretsFile: _secretsOpened,
          hostFiles: filesFor,
          checkKey: _acceptedKey,
          hostRuns: runs,
          project: 'demo',
          machines: machines,
          settings: settings,
          secretStore: _MemorySecrets(),
          start: (_, args) async {
            commands.add(List.of(args));
            return process;
          },
        ),
      ),
    );
    await fillSteps(
      tester,
      {
        'host-scaleway-project': 'corrected-provider',
        'host-account': 'corrected-account',
        'host-tresor': 'drive',
        'host-identity': fixture('private'),
        'host-public-key': fixture('public.pub'),
        'host-collection': fixture('collection.tar.gz'),
        'host-collection-sha256': collectionDigest,
      },
      beforeFill: (field, key) {
        if (key == 'host-scaleway-project') expect(field.controller!.text, 'mistyped-provider');
        if (key == 'host-account') expect(field.controller!.text, 'worker');
      },
    );
    await tapAndRun(tester, const Key('host-up'));
    expect(commands, hasLength(1), reason: 'corrected answers must start a new attempt');
    expect(commands.single, containsAllInOrder(['--account', 'corrected-account']));
    expect(commands.single, containsAllInOrder(['--scaleway-project', 'corrected-provider']));
    process.end(65);
    await World.settle(tester);
  });

  for (final code in [65, 75, 0]) {
    for (final released in [null, '203.0.113.7', '203.0.113.8']) {
      // Harm: failed teardown loses the only route back, or teardown targets a different billing host.
      hostWidgets('Machines teardown reuses kept arguments and removes only after exit $code releasing $released', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final settings = newSettings(MemorySettingsStore());
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
                        hostRuns: runs,
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
        await expandListRows(tester);
        await tester.tap(find.byKey(const Key('machines-menu demo server')));
        await World.settle(tester);
        await tester.tap(find.text('Take this server down'));
        await World.settle(tester);
        expect(commands, isEmpty, reason: 'teardown must wait for the explicit confirmation');
        expect(find.byType(TextField), findsNothing, reason: 'no setup answer is typed again');
        await tapAndRun(tester, const Key('host-down'));
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
    (key: 'host-collection', label: 'test collection', step: 4),
    (key: 'vault-entry', label: 'vault entry deployment', step: 1),
  ]) {
    for (final directory in [false, true]) {
      // Harm: finding an unusable input only after renting leaves a billing host without setup.
      hostWidgets('${field.key} refuses a ${directory ? 'directory' : 'missing file'} in its own step', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final previousDesk = desk;
        desk = Desk.of('linux', {'HOME': scratch.path});
        addTearDown(() => desk = previousDesk);
        final selected = fixture('unusable');
        if (directory) Directory(selected).createSync();
        final settings = newSettings(MemorySettingsStore());
        await settings.rememberTresorFolder('demo', scratch.path);
        var starts = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HostDialog(
                openSecretsFile: _secretsOpened,
                hostFiles: filesFor,
                checkKey: _acceptedKey,
                hostRuns: runs,
                project: 'demo',
                machines: machines,
                settings: settings,
                secretStore: _MemorySecrets(),
                pickFile: (_) async => '~/unusable',
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
          'host-collection': fixture('collection.tar.gz'),
          'host-collection-sha256': collectionDigest,
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

  // Harm: a vault entry's file read through a link, an entry the stop refuses after renting, or none in the file.
  hostWidgets('a vault entry is a plain file named once, and goes into the secrets file and the record', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final previousDesk = desk;
    desk = Desk.of('linux', {'HOME': scratch.path});
    addTearDown(() => desk = previousDesk);
    final token = File(fixture('token'))..writeAsBytesSync([1, 2, 3]);
    Link(fixture('linked')).createSync(token.path);
    final picks = <String>[];
    final opened = <Map<String, String>>[];
    final settings = newSettings(MemorySettingsStore());
    await settings.rememberTresorFolder('demo', scratch.path);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: ({required file, required project, migrateKeyFrom, keys = const {}}) {
              opened.add(keys);
              return _secretsOpened(file: file, project: project);
            },
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
            project: 'demo',
            machines: machines,
            settings: settings,
            secretStore: _MemorySecrets(),
            pickFile: (_) async => picks.removeAt(0),
            start: stopsThenGoesOn(),
          ),
        ),
      ),
    );
    await fillSteps(tester, {
      'host-scaleway-project': 'project',
      'host-tresor': 'drive',
      'host-collection': fixture('collection.tar.gz'),
      'host-collection-sha256': collectionDigest,
    }, stopAt: 1);
    Future<void> add(String name, String file) async {
      picks.add(file);
      await tester.ensureVisible(find.byKey(const Key('host-key-name')));
      await tester.enterText(find.byKey(const Key('host-key-name')), name);
      await tester.ensureVisible(find.text('Choose a file for this vault entry'));
      await tester.tap(find.text('Choose a file for this vault entry'));
      await World.settle(tester);
    }

    await add('_forge', token.path);
    expect(find.textContaining('A vault entry name holds only'), findsOneWidget, reason: 'the stop takes no _forge');
    picks.clear();
    await add('forge', fixture('linked'));
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
    expect(find.textContaining('not a regular file'), findsOneWidget, reason: 'a link is refused');
    Future<void> remove() async {
      await tester.ensureVisible(find.byTooltip('Remove this file'));
      await tester.tap(find.byTooltip('Remove this file'));
      await World.settle(tester);
    }

    await remove();
    // As the secrets file's script refuses them, before anything is rented: an empty file, a folder that is a link.
    final empty = File(fixture('empty'))..writeAsBytesSync([]);
    await add('forge', empty.path);
    expect(find.textContaining('is empty'), findsOneWidget);
    await remove();
    final real = Directory(fixture('real'))..createSync();
    File(path.join(real.path, 'token')).writeAsBytesSync([4]);
    Link(fixture('via')).createSync(real.path);
    await add('forge', fixture('via/token'));
    expect(find.textContaining('reached through a link'), findsOneWidget);
    await remove();
    await add('forge', token.path);
    await add('forge', token.path);
    expect(find.textContaining('A vault entry forge is chosen already'), findsOneWidget);
    await navigate(tester, 'wizard-next');
    await tester.enterText(find.byKey(const Key('host-identity')), fixture('default'));
    await tester.enterText(find.byKey(const Key('host-public-key')), fixture('default.pub'));
    await tester.pump();
    await navigate(tester, 'wizard-next');
    // Opened on its step, then the entry's file changes: Start opens the file again, never the key kept for the old.
    await tapAndRun(tester, const Key('host-secrets-open'));
    expect(opened, hasLength(1));
    token.writeAsBytesSync([1, 2, 3, 4]);
    await navigate(tester, 'wizard-next');
    await tester.enterText(find.byKey(const Key('host-collection')), fixture('collection.tar.gz'));
    await tester.enterText(find.byKey(const Key('host-collection-sha256')), collectionDigest);
    await tester.pump();
    await navigate(tester, 'wizard-next');
    await tapAndRun(tester, const Key('host-up'));

    expect(opened, hasLength(2), reason: 'the changed file is taken again');
    expect(opened.last, {'forge': token.path}, reason: 'the chosen file goes into the secrets file');
    expect(settings.hostUps['demo']?.vaultKeys, ['forge'], reason: 'the stop sends this entry, and no other');
  });

  // Harm: every Choose… starting elsewhere makes a person walk back to the folder they were just in.
  hostWidgets('each picker starts in the folder of the file chosen before it', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final keys = Directory(fixture('keys'))..createSync();
    final picks = [fixture('keys/walk_ed25519'), fixture('keys/walk_ed25519.pub')];
    final startedIn = <String?>[];
    final settings = newSettings(MemorySettingsStore());
    await settings.rememberTresorFolder('demo', scratch.path);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
            project: 'demo',
            machines: machines,
            settings: settings,
            secretStore: _MemorySecrets(),
            pickFile: (initialDirectory) async {
              startedIn.add(initialDirectory);
              return picks.removeAt(0);
            },
            start: (_, _) async => _HostProcess(),
          ),
        ),
      ),
    );
    await fillSteps(tester, {'host-scaleway-project': 'project', 'host-tresor': 'drive'}, stopAt: 2);
    for (final choose in [0, 1]) {
      await tester.ensureVisible(find.text('Choose…').at(choose));
      await tester.tap(find.text('Choose…').at(choose));
      await World.settle(tester);
    }
    expect(startedIn, [null, keys.path]);
    expect(tester.widget<TextField>(find.byKey(const Key('host-public-key'))).controller!.text, endsWith('.pub'));
  });

  // Harm: an input refusal without its field and step prevents correcting setup before renting.
  hostWidgets('an unreadable signing key is refused on its own step and a corrected one goes on', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = newSettings(MemorySettingsStore());
    await settings.rememberTresorFolder('demo', scratch.path);
    final unreadable = File(fixture('unreadable.pub'))..writeAsBytesSync([0xff]);
    final replacement = File(fixture('replacement.pub'))..writeAsStringSync(signingPublic);
    final commands = <List<String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
            project: 'demo',
            machines: machines,
            settings: settings,
            secretStore: _MemorySecrets(),
            start: (_, arguments) async {
              commands.add(List.of(arguments));
              final process = _HostProcess();
              process.line(
                const host.Step(
                  'up',
                  host.StepState.done,
                  address: '203.0.113.7',
                  account: 'porelo',
                  socket: '/run/user/1007/porelo/porelod.sock',
                ),
              );
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
      'host-signing-key': unreadable.path,
    }, stopAt: 1);
    // A file that is no public key is refused by the step itself, before anything reads it whole.
    expect(tester.widget<FilledButton>(find.byKey(const Key('wizard-next'))).onPressed, isNull);
    expect(commands, isEmpty, reason: 'unreadable setup input must stop before renting');
    // The field still shows the path on this step, so the refusal is found by its own words.
    expect(find.textContaining('is not a public key (.pub): ${unreadable.path}'), findsOneWidget);
    expect(find.byKey(const Key('host-identity')), findsNothing, reason: 'the refused key stops the drive step');
    await tester.ensureVisible(find.byKey(const Key('host-signing-key')));
    await tester.enterText(find.byKey(const Key('host-signing-key')), replacement.path);
    await tester.pump();
    await navigate(tester, 'wizard-next');
    await tester.enterText(find.byKey(const Key('host-identity')), fixture('default'));
    await tester.enterText(find.byKey(const Key('host-public-key')), fixture('default.pub'));
    await tester.pump();
    await navigate(tester, 'wizard-next');
    // Your secrets file: its default place is taken.
    await navigate(tester, 'wizard-next');
    await tester.enterText(find.byKey(const Key('host-collection')), fixture('collection.tar.gz'));
    await tester.enterText(find.byKey(const Key('host-collection-sha256')), collectionDigest);
    await tester.pump();
    await navigate(tester, 'wizard-next');
    await tapAndRun(tester, const Key('host-up'));
    expect(commands, hasLength(1), reason: 'the corrected answers must run preparation and start the action');
    expect(find.textContaining(unreadable.path), findsNothing);
    expect(find.text('refused'), findsNothing);
    expect(runs.of('demo')!.awaitingVpn, isTrue, reason: 'corrected host setup still needs a verified local VPN');
    final yaml = File(fixture('porelo-host/machine.yml')).readAsStringSync();
    expect(yaml, contains(host.HostFiles.signingFingerprint(replacement.readAsStringSync())));
  });

  // Harm: confusing the local folder with the remote tresor syncs the wrong project on the server.
  hostWidgets('the folder and its picker share a line and suggest only an unedited tresor name', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var folder = fixture('first-drive');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
            project: 'demo',
            machines: machines,
            pickFolder: (_) async => folder,
          ),
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
  hostWidgets('a public key path is refused before up starts', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
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
      'host-collection-sha256': collectionDigest,
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

    'host-signing-key': 1,
    'host-identity': 2,
    'host-public-key': 2,
    'host-collection': 4,
  }.entries) {
    // Harm: an incomplete answer rents a billing server that cannot be set up.
    hostWidgets('${missing.key} must be given before the start decision can be reached', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = newSettings(MemorySettingsStore());
      await settings.rememberTresorFolder('demo', scratch.path);
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              openSecretsFile: _secretsOpened,
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
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
        'host-signing-key': fixture('signing.pub'),
        'host-collection': fixture('collection.tar.gz'),
        'host-collection-sha256': collectionDigest,
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
  hostWidgets('a public key without a pub suffix is refused before up starts', (tester) async {
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
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
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
  hostWidgets('back keeps every host answer before starting', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
            project: 'demo',
            machines: machines,
            secretStore: _MemorySecrets(),
          ),
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
      'host-collection-sha256': collectionDigest,
    };
    await fillSteps(tester, answers);
    final seen = <String>{};
    for (var step = 0; step < 5; step++) {
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

  // Harm: closing the wizard loses a billing run or crashes when its command finishes.
  hostWidgets('a host run survives closing its wizard and adds the confirmed machine', (tester) async {
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
                  openSecretsFile: _secretsOpened,
                  hostFiles: filesFor,
                  checkKey: _acceptedKey,
                  hostRuns: runs,
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
      'host-collection-sha256': collectionDigest,
    });
    await tapAndRun(tester, const Key('host-up'));
    expect(runs.of('demo')?.session.state, HostRunState.running, reason: 'the command must start before leaving');
    await navigate(tester, 'wizard-leave');
    expect(find.byKey(const Key('wizard-confirm-leave')), findsOneWidget);
    await navigate(tester, 'wizard-confirm-leave');
    expect(find.byType(HostDialog), findsNothing);
    process.line(
      const host.Step(
        'up',
        host.StepState.done,
        address: '203.0.113.7',
        account: 'porelo',
        socket: '/run/user/1007/porelo/porelod.sock',
      ),
    );
    process.end(0);
    await World.settle(tester);
    expect(tester.takeException(), isNull, reason: 'a process answer must not notify a disposed dialog');
    // No folder was chosen, so the host files were supplied by hand and there is no VPN to wait for.
    expect(machines.all.where((machine) => machine.kind == 'host').single.name, 'demo server');
    expect(runs.of('demo')!.ready, isTrue);
  });

  // Harm: losing unexpected host diagnostics hides failures when retrying or sharing a setup protocol.
  hostWidgets('unexpected diagnostics remain readable and copyable across attempts and restart', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final first = HostProcess();
    final second = HostProcess();
    final processes = [first, second].iterator;
    var now = DateTime.utc(2000);
    final session = HostSession(
      executable: 'fake',
      arguments: const [],
      now: () => now,
      start: (_, _) async {
        processes.moveNext();
        return processes.current;
      },
    );
    final run = runs.start(
      project: 'demo',
      session: session,
      record: const HostUpRecord(
        scalewayProject: 'provider',
        account: 'worker',
        tresor: 'drive',
        folder: null,
        signingKey: '',
        identity: '/keys/private',
        publicKey: '/keys/public',
        collection: '',
        vpnPeerPublicKey: '',
        vpnPeerAddress: '',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(project: 'demo', machines: machines, hostRuns: runs, existingRun: run),
        ),
      ),
    );
    first.line(const host.Step('check', host.StepState.done, text: 'Check the project'));
    await World.settle(tester);
    first.words('Unexpected public setup diagnostic');
    await World.settle(tester);
    first.line(const host.Step('rent', host.StepState.refused, text: 'Rent the server', fix: 'No server available'));
    now = now.add(const Duration(minutes: 1));
    first.end(65);
    await World.settle(tester);
    await run.finished;
    expect(
      find.descendant(
        of: find.byKey(const Key('host-protocol-list')),
        matching: find.text('Unexpected public setup diagnostic'),
      ),
      findsOneWidget,
      reason: 'an unexpected diagnostic must be readable without opening another protocol',
    );
    final resumed = runs.resume(run);
    second.line(const host.Step('check', host.StepState.done, text: 'Check the project again'));
    await World.settle(tester);
    second.words('Another public setup diagnostic');
    await World.settle(tester);
    second.line(const host.Step('rent', host.StepState.refused, text: 'Retry renting', fix: 'Still no server'));
    now = now.add(const Duration(minutes: 1));
    second.end(65);
    await World.settle(tester);
    await resumed;
    await tester.tap(find.byType(ExpansionTile));
    await World.settle(tester);
    for (final message in ['Unexpected public setup diagnostic', 'Another public setup diagnostic']) {
      expect(find.text(message), findsOneWidget, reason: 'each attempt must retain its unexpected failure message');
    }
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byKey(const Key('host-copy-protocol')));
    await World.settle(tester);
    final publicLines = [
      'Check the project',
      'Unexpected public setup diagnostic',
      'Rent the server',
      'Check the project again',
      'Another public setup diagnostic',
      'Retry renting',
    ];
    var previous = -1;
    for (final line in publicLines) {
      final index = copied?.indexOf(line) ?? -1;
      expect(index, greaterThan(previous), reason: 'copy must include the diagnostics with their original attempts');
      previous = index;
    }
    final stored = jsonDecode(jsonEncode([for (final entry in session.keptProtocol) entry.stored]));
    final restored = HostSession(executable: 'fake', arguments: const [])
      ..restoreProtocol(HostProtocolEntry.readMany(stored)!);
    addTearDown(restored.dispose);
    expect(restored.protocolText, copied, reason: 'restarting must retain all public diagnostic evidence for copying');
    expect(restored.attempts, hasLength(2), reason: 'restarting must not merge separate failed commands');
    expect(restored.steps.map((step) => step.text), [
      'Check the project again',
      'Retry renting',
    ], reason: 'old steps must never satisfy the current command completion checks');
  });

  // Harm: copying raw wire fields or setup inputs can disclose credentials to the clipboard.
  hostWidgets('copying the protocol exports only public presentation fields', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final process = HostProcess();
    final session = HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process);
    final run = runs.start(
      project: 'demo',
      session: session,
      record: const HostUpRecord(
        scalewayProject: 'provider',
        account: 'worker',
        tresor: 'drive',
        folder: null,
        signingKey: '',
        identity: '/keys/private',
        publicKey: '/keys/public',
        collection: '',
        vpnPeerPublicKey: '',
        vpnPeerAddress: '',
      ),
    );
    final nonpublic = String.fromCharCodes(List.generate(24, (index) => 65 + index % 26));
    process.raw(
      jsonEncode({
        'step': 'check',
        'state': 'refused',
        'text': 'Check the project',
        'fix': 'Public refusal',
        'password': nonpublic,
        'credentials': {'token': nonpublic},
      }),
    );
    process.words('check refused — Public refusal');
    process.end(65);
    await World.settle(tester);
    await run.finished;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(project: 'demo', machines: machines, hostRuns: runs, existingRun: run),
        ),
      ),
    );
    final copies = <Map<Object?, Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copies.add(Map<Object?, Object?>.from(call.arguments as Map));
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byKey(const Key('host-copy-protocol')));
    await World.settle(tester);
    expect(copies, hasLength(1), reason: 'one action must write the whole public protocol once');
    expect(copies.single.keys, ['text'], reason: 'the clipboard payload must contain only public text');
    final text = copies.single['text']! as String;
    expect(text.contains(nonpublic), isFalse, reason: 'unrecognized credential fields must never reach the clipboard');
    expect(text.contains('/keys/private'), isFalse, reason: 'copy must not export setup arguments');
    expect(text.contains('Check the project'), isTrue, reason: 'the safe export must still contain the actual step');
    expect(
      text.contains('Public refusal'),
      isTrue,
      reason: 'the safe export must retain the public failure explanation',
    );
    expect(
      text.contains('check refused — Public refusal'),
      isFalse,
      reason: 'stderr echoes must not become duplicate diagnostics',
    );
  });

  // Harm: a finished setup's protocol closes itself on the next change, so what the setup reported cannot be read.
  hostWidgets('a finished setup reopened stays open when its runs change', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final process = _HostProcess();
    final run = runs.start(
      project: 'demo',
      session: HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process),
      record: const HostUpRecord(
        scalewayProject: 'provider-project',
        account: 'worker',
        tresor: 'remote-drive',
        folder: null,
        repository: '',
        signingKey: '',
        identity: '/keys/private',
        publicKey: '/keys/public.pub',
        collection: '',
        vpnPeerPublicKey: '',
        vpnPeerAddress: '',
      ),
    );
    process.line(
      const host.Step(
        'up',
        host.StepState.done,
        address: '203.0.113.7',
        account: 'worker',
        socket: '/run/user/1007/porelo/porelod.sock',
      ),
    );
    process.end(0);
    await tester.runAsync(() => run.finished);
    await runs.vpnChecked(run, verified: true);
    expect(run.ready, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => HostDialog(project: 'demo', machines: machines, hostRuns: runs, existingRun: run),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await World.settle(tester);
    expect(find.byKey(const Key('host-protocol')), findsOneWidget);
    runs.vpnTerminalChanged(run, open: false);
    await World.settle(tester);
    expect(
      find.byKey(const Key('host-protocol')),
      findsOneWidget,
      reason: 'only the person closes a finished protocol',
    );
  });

  for (final field in <String, String?>{
    'host-public-key': '--public-key',
    'host-identity': '--identity',
    'host-collection': '--collection',
    'host-signing-key': null,
  }.entries) {
    // Harm: up receives a nonexistent path or cannot prepare the host file.
    hostWidgets('${field.key} expands a home path before preparing files and starting up', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final previousDesk = desk;
      desk = Desk.of('linux', {'HOME': scratch.path});
      addTearDown(() => desk = previousDesk);
      final settings = newSettings(MemorySettingsStore());
      await settings.rememberTresorFolder('demo', scratch.path);
      late File signing;
      await tester.runAsync(() async {
        await Directory(path.join(scratch.path, '.ssh')).create();
        await File(path.join(scratch.path, '.ssh', 'key')).writeAsString('invented-private-or-setup-fixture');
        signing = await File(path.join(scratch.path, '.ssh', 'key.pub')).writeAsString(signingPublic);
      });
      final commands = <List<String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              openSecretsFile: _secretsOpened,
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
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
        'host-collection-sha256': collectionDigest,

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
    hostWidgets('${field.key} refuses another user home path before up starts', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = newSettings(MemorySettingsStore());
      await settings.rememberTresorFolder('demo', scratch.path);
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              openSecretsFile: _secretsOpened,
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
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
          'host-collection-sha256': collectionDigest,

          field.key: '~user/key',
        },
        stopAt: switch (field.key) {
          'host-signing-key' => 1,
          'host-collection' => 4,
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
  hostWidgets('the dialog runs the executable named by its injected environment', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final executable = File('${scratch.path}/host');
    String? launched;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
            project: 'demo',
            machines: machines,
            secretStore: _MemorySecrets(),
            environment: {'PORELO_HOST_STANDIN': executable.path},
            start: (program, arguments) async {
              launched = program;
              final process = _HostProcess()..end(65);
              return process;
            },
          ),
        ),
      ),
    );
    await fillSteps(tester, <String, String>{
      'host-scaleway-project': 'project',
      'host-tresor': 'drive',
      'host-collection': fixture('collection.tar.gz'),
      'host-collection-sha256': collectionDigest,
    });
    await tester.pump();
    await tapAndRun(tester, const Key('host-up'));
    expect(launched, executable.path);
  });

  // Harm: a conflicting file is destroyed or a rented host starts with incomplete files.
  // Red: start the session before awaiting prepare, or truncate an existing machine.yml.
  hostWidgets('a conflicting machine file is named and up never starts', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = newSettings(MemorySettingsStore());
    await settings.rememberTresorFolder('demo', scratch.path);
    var starts = 0;
    late File conflict;
    late File signing;
    await tester.runAsync(() async {
      await Directory(path.join(scratch.path, 'porelo-host')).create();
      conflict = await File(path.join(scratch.path, 'porelo-host', 'machine.yml')).writeAsString('keep');
      signing = await File(path.join(scratch.path, 'signing.pub')).writeAsString(signingPublic);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
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
      'host-collection-sha256': collectionDigest,

      'host-signing-key': signing.path,
    });
    await tester.pump();
    await tapAndRun(tester, const Key('host-up'));
    expect(starts, 0, reason: 'file conflicts must block renting');
    expect(find.textContaining(conflict.path), findsOneWidget);
    expect(await tester.runAsync(() => conflict.readAsString()), 'keep');
  });

  // Harm: the secrets file can be made and checked only by renting a server; or the person types the master password
  // twice, once at the step and again at setup.
  hostWidgets('the secrets file is opened from its own step once, and setup takes the key it gave', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = newSettings(MemorySettingsStore());
    await settings.rememberTresorFolder('demo', scratch.path);
    final opened = <String>[];
    final commands = <List<String>>[];
    var refuse = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: ({required file, required project, migrateKeyFrom, keys = const {}}) async {
              opened.add(file);
              if (refuse) throw const host.HostFilesRefused('The secrets file was not opened, so setup did not start.');
              return _secretsOpened(file: file, project: project);
            },
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
            machines: machines,
            project: 'demo',
            settings: settings,
            secretStore: _MemorySecrets(),
            start: (_, arguments) async {
              commands.add(List.of(arguments));
              return _HostProcess()..end(65);
            },
          ),
        ),
      ),
    );
    await fillSteps(tester, {
      'host-scaleway-project': 'project',
      'host-tresor': 'drive',
      'host-signing-key': fixture('signing.pub'),
    }, stopAt: 3);

    await tapAndRun(tester, const Key('host-secrets-open'));
    expect(find.text('The secrets file was not opened, so setup did not start.'), findsOneWidget);
    refuse = false;
    await tapAndRun(tester, const Key('host-secrets-open'));
    expect(find.text('Ready: the file keeps the server’s keys.'), findsOneWidget);
    expect(commands, isEmpty, reason: 'opening the file rents nothing');
    expect(settings.secretsFile, opened.last, reason: 'the file is remembered once it opened');

    await navigate(tester, 'wizard-next');
    await tester.enterText(find.byKey(const Key('host-collection')), fixture('collection.tar.gz'));
    await tester.enterText(find.byKey(const Key('host-collection-sha256')), collectionDigest);
    await tester.pump();
    await navigate(tester, 'wizard-next');
    await tapAndRun(tester, const Key('host-up'));

    expect(opened, hasLength(2), reason: 'setup takes the key the step got, and asks no master password again');
    expect(commands, hasLength(1));
  });

  // Harm: a host rented without its key, or a secret on a command line every process on the desktop can read.
  hostWidgets(
    'the secrets file opens in a terminal here with no secret in its command, and a failed one rents nothing',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = newSettings(MemorySettingsStore());
      await settings.rememberTresorFolder('demo', scratch.path);
      final terminals = <FakeTerminal>[];
      final commands = <List<String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
              machines: machines,
              project: 'demo',
              settings: settings,
              secretStore: _MemorySecrets(),
              start: (_, arguments) async {
                commands.add(List.of(arguments));
                return _HostProcess()..end(65);
              },
              openTerminal: (program, arguments, {columns = 80, rows = 24}) {
                final terminal = FakeTerminal([program, ...arguments]);
                terminals.add(terminal);
                return terminal;
              },
            ),
          ),
        ),
      );
      await fillSteps(tester, {
        'host-scaleway-project': 'project',
        'host-tresor': 'drive',
        'host-signing-key': fixture('signing.pub'),
        'host-collection': fixture('collection.tar.gz'),
        'host-collection-sha256': collectionDigest,
      });
      await tapAndRun(tester, const Key('host-up'));
      // The secrets file's folder for the public half is made by real file work, which the test clock never runs.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await World.settle(tester);

      expect(terminals, hasLength(1), reason: 'the secrets file is opened before anything is rented');
      final command = terminals.single.command;
      expect(command.first, '/usr/bin/env', reason: 'a script of this desktop, run here');
      expect(
        command.join(' '),
        contains('-u BASH_ENV'),
        reason: 'no startup file of the caller runs beside the secrets',
      );
      expect(command.join(' '), contains('-u SHELLOPTS'), reason: 'no inherited trace prints a secret');
      expect(command, containsAllInOrder(<String>['/bin/bash', '--noprofile', '--norc', '-c']));
      expect(command.last, contains("'hosts/demo/wireguard'"));
      expect(command.last, contains('read -rs'), reason: 'the master password is typed into the terminal');
      expect(commands, isEmpty, reason: 'nothing is rented while the secrets file is open');

      terminals.single.endsWith(1);
      await World.settle(tester);
      await tapAndRun(tester, const Key('unlock-done'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await World.settle(tester);

      expect(commands, isEmpty, reason: 'a secrets file that did not open rents nothing');
      expect(find.textContaining('The secrets file was not opened'), findsOneWidget);
    },
  );

  // Harm: the private key reaches a process/log/UI, or repeated up/down configure the wrong peer.
  // Red: pass a private key as the peer option, show it in a step, or omit the options on repeated up/down.
  hostWidgets('folder picker prepares private files and up and down carry only public keys', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settingsStore = MemorySettingsStore();
    final settings = newSettings(settingsStore);
    final store = _MemorySecrets();
    final commands = <List<String>>[];
    final processes = <_HostProcess>[];
    Future<void> deliver(void Function() send) async {
      send();
      await World.settle(tester);
    }

    final terminal = FakeTerminal([]);
    late File signing;
    await tester.runAsync(() async {
      signing = await File(path.join(scratch.path, 'signing.pub')).writeAsString(signingPublic);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
            machines: machines,
            project: 'demo',
            settings: settings,
            secretStore: store,
            pickFolder: (_) async => scratch.path,
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
        'host-collection-sha256': collectionDigest,

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
        const host.Step(
          'person',
          host.StepState.waiting,
          needs: ['vault'],
          address: '203.0.113.8',
          account: 'porelo',
          admin: 'image-user',
        ),
      );
      processes.last.end(75);
    });
    expect(find.byKey(const Key('host-stop')), findsOneWidget);
    await tapAndRun(tester, const Key('host-complete-setup'));
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
    // The host's key is the secrets file's: its private half never reaches the drive.
    final hostPrivate = base64Encode(List<int>.filled(32, 5));
    expect(
      await tester.runAsync(() => File(path.join(scratch.path, 'porelo-host', 'wireguard.key')).exists()),
      isFalse,
      reason: 'with the secrets file the drive holds no host key',
    );
    final hostPublic = await host.HostFiles.publicKey(hostPrivate);
    expect(settings.hostUp('demo')!.vpnHostPublicKey, hostPublic);
    for (final secret in [private, hostPrivate]) {
      expect(
        tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').join(' '),
        isNot(contains(secret)),
        reason: 'private halves never appear in labels, steps or refusal text',
      );
    }
    final reopened = newSettings(settingsStore);
    await reopened.load();
    expect(reopened.hostUp('demo')!.vpnHostPublicKey, hostPublic);
    expect(reopened.hostUp('demo')!.vpnFile, isNull, reason: 'local bring-up does not save an export');
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
  for (final operation in ['setup', 'teardown']) {
    hostWidgets('a store SocketException during $operation is a safe dialog refusal', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = newSettings(MemorySettingsStore());
      final store = _BrokenSecrets();
      final processes = <_HostProcess>[];
      final destination = File(path.join(scratch.path, 'asked.conf'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              openSecretsFile: _secretsOpened,
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
              machines: machines,
              project: 'demo',
              settings: settings,
              secretStore: store,
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
        'host-collection-sha256': collectionDigest,
      });
      await tester.pump();
      store.fail = true;
      await tapAndRun(
        tester,
        Key(switch (operation) {
          'setup' => 'host-up',
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
      expect(processes, isEmpty, reason: 'store refusal cannot launch a command');
      expect(await tester.runAsync(() => destination.exists()), isFalse);
    });
  }

  // Harm: setup rents a host using a person key that cannot be recovered from the store.
  // Red: remove the store read-back equality check or start the command before preparation.
  for (final alter in [false, true]) {
    hostWidgets('a ${alter ? 'different read-back' : 'dropped store write'} blocks the host command', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              openSecretsFile: _secretsOpened,
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
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
        'host-collection-sha256': collectionDigest,
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
  // Red: add on the done step before exit 0, ignore the done values,
  // skip replacing a same-name host, or forget it when down starts or fails.
  hostWidgets('confirmed up uses its destination and down for another account keeps the host', (tester) async {
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
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
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
      'host-collection-sha256': collectionDigest,
      'host-identity': fixture('new'),
      'host-account': 'form-account',
    });
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('host-up')));
    await tapAndRun(tester, const Key('host-up'));
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
    await tapAndRun(tester, const Key('host-up'));
    await World.settle(tester);
    processes.last.line(done);
    processes.last.end(0);
    await World.settle(tester);
    expect(find.byKey(const Key('host-add')), findsNothing, reason: 'successful setup adds the host automatically');
    expect(runs.of('demo')!.ready, isTrue, reason: 'host files supplied by hand leave no VPN to wait for');
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
    expect(added.socketPath, '/tmp/demo-server.sock');
    for (final code in <int>[65, 75, 0]) {
      await tester.ensureVisible(find.byKey(const Key('host-down')));
      await tapAndRun(tester, const Key('host-down'));
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
    hostWidgets('down ${found ? 'removes only the matching destination' : 'without an address keeps every machine'}', (
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
              openSecretsFile: _secretsOpened,
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
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
        'host-collection-sha256': collectionDigest,
      });
      await tester.pump();
      for (final code in <int>[65, 75, 0]) {
        await tester.ensureVisible(find.byKey(const Key('host-down')));
        await tapAndRun(tester, const Key('host-down'));
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
    hostWidgets('an invalid completion is refused when adding: ${done.toLine()}', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final process = _HostProcess();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              openSecretsFile: _secretsOpened,
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
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
        'host-collection-sha256': collectionDigest,
      });
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('host-up')));
      await tapAndRun(tester, const Key('host-up'));
      await World.settle(tester);
      process.line(done);
      process.end(0);
      await World.settle(tester);
      expect(find.byKey(const Key('host-add')), findsNothing);
      expect(machines.all.where((machine) => machine.kind == 'host'), isEmpty);
      expect(find.textContaining('did not name a valid'), findsOneWidget);
    });
  }

  // Changing the host identity can make down report success while the rented host keeps billing.
  hostWidgets('host fields stay read-only after up and down targets exactly the same host', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
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
      'host-collection-sha256': collectionDigest,
    };
    await fillSteps(tester, fields, beforeFill: (field, _) => expect(field.readOnly, isFalse));
    await tester.pump();
    await tapAndRun(tester, const Key('host-up'));
    expect(find.byKey(const Key('host-stop')), findsOneWidget);
    Future<void> checkLockedFields() async {
      for (var step = 0; step < 6; step++) {
        await navigate(tester, 'wizard-back');
        if (find.byKey(const Key('wizard-confirm-back')).evaluate().isNotEmpty) {
          await navigate(tester, 'wizard-confirm-back');
        }
      }
      final seen = <String>{};
      for (var step = 0; step < 5; step++) {
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
    hostWidgets('unsupported stop $needs explains what is missing and cannot resume', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              openSecretsFile: _secretsOpened,
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
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
        'host-collection-sha256': collectionDigest,
      });
      await tester.pump();
      await tapAndRun(tester, const Key('host-up'));
      expect(find.byKey(const Key('host-stop')), findsOneWidget);
      await tapAndRun(tester, const Key('host-complete-setup'));
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
  // Harm: a server rented from where its keys cannot be kept, which then waits at a stop nothing here answers.
  hostWidgets('on Windows Start refuses, saying why, and nothing is rented', (tester) async {
    final previous = desk;
    addTearDown(() => desk = previous);
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
            secretStore: _MemorySecrets(),
            machines: machines,
            project: 'demo',
            start: (_, _) async {
              starts++;
              return _HostProcess();
            },
          ),
        ),
      ),
    );
    desk = Desk.of('windows', const {'USERPROFILE': r'C:\Users\person', 'SystemRoot': r'C:\Windows'});
    final wizard = tester.widget<Wizard>(find.byType(Wizard));
    await tester.runAsync(wizard.actionSteps.single.run);
    await World.settle(tester);
    expect(starts, 0);
    expect(
      find.textContaining('opens only on Linux so far'),
      findsOneWidget,
      reason: 'the reason, before any step check',
    );
  });

  hostWidgets('a host cannot be brought up without the project tresor', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
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
    // Your secrets file: its default place is taken.
    await navigate(tester, 'wizard-next');
    await tester.enterText(find.byKey(const Key('host-collection')), fixture('collection.tar.gz'));
    await tester.enterText(find.byKey(const Key('host-collection-sha256')), collectionDigest);
    await tester.pump();
    await navigate(tester, 'wizard-next');
    expect(tester.widget<FilledButton>(find.byKey(const Key('host-up'))).onPressed, isNotNull);
  });

  // Harm: a secret typed at the host where the file keeps it, or a stop the interface cannot answer offered anyway.
  hostWidgets(
    'a stop for the file\'s secrets feeds them from it on standard input, and without the file is not offered',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = newSettings(MemorySettingsStore());
      await settings.rememberTresorFolder('demo', scratch.path);
      final terminals = <FakeTerminal>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              openSecretsFile: _secretsOpened,
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
              secretStore: _MemorySecrets(),
              machines: machines,
              settings: settings,
              project: 'demo',
              start: stopsThenGoesOn(needs: ['vault-new', 'wireguard']),
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
        'host-collection-sha256': collectionDigest,
        'host-identity': fixture('dialog identity'),
      });
      await tapAndRun(tester, const Key('host-up'));
      expect(
        settings.secretsFile,
        isNotNull,
        reason: 'Start opens the secrets file and names it for the stop, with no drive folder too',
      );
      // A setup from before the file names none: nothing here can give the VPN key, and that is said.
      await settings.rememberSecretsFile(null);
      await tapAndRun(tester, const Key('host-complete-setup'));
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('host-open-terminal'))).onPressed,
        isNull,
        reason: 'without the secrets file nothing here can give the VPN key',
      );
      expect(find.textContaining('which comes from your secrets file'), findsOneWidget);
      await settings.rememberSecretsFile('/home/person/Porelo/secrets.kdbx');
      await World.settle(tester);
      await tapAndRun(tester, const Key('host-open-terminal'));

      final command = terminals.single.command;
      expect(command.first, '/usr/bin/env', reason: 'the pipe runs on this desktop');
      expect(command.last, contains('porelo-host-stop --stdin vault-new wireguard'));
      expect(command.last, contains("'hosts/demo/wireguard'"));
      expect(command.last, contains('image-user@203.0.113.7'), reason: 'the call runs as the host\'s login user');
    },
  );

  // Harm: a repository never brought over, or the central forge's token typed where the file keeps it.
  hostWidgets('up refused for the central forge\'s token gives it from the file and runs up again', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = newSettings(MemorySettingsStore());
    await settings.rememberSecretsFile('/home/person/Porelo/secrets.kdbx');
    final terminals = <FakeTerminal>[];
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostDialog(
            openSecretsFile: _secretsOpened,
            hostFiles: filesFor,
            checkKey: _acceptedKey,
            hostRuns: runs,
            secretStore: _MemorySecrets(),
            machines: machines,
            settings: settings,
            project: 'demo',
            start: (_, _) async {
              starts++;
              final process = _HostProcess();
              process.line(
                const host.Step(
                  'up',
                  host.StepState.started,
                  address: '203.0.113.7',
                  account: 'actual-account',
                  socket: '/run/user/1007/porelo/porelod.sock',
                ),
              );
              process.line(
                const host.Step(
                  'repositories',
                  host.StepState.refused,
                  fix: 'forge-central-token: stand-in still to migrate; give it with porelo-host-stop --stdin forge-central-token',
                  address: '203.0.113.7',
                  admin: 'image-user',
                ),
              );
              process.end(2);
              return process;
            },
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
      'host-collection-sha256': collectionDigest,
      'host-identity': fixture('dialog identity'),
    });
    await tapAndRun(tester, const Key('host-up'));
    expect(starts, 1);

    await tapAndRun(tester, const Key('host-complete-setup'));
    await tapAndRun(tester, const Key('host-open-terminal'));
    final command = terminals.single.command;
    expect(command.last, contains('porelo-host-stop --stdin forge-central-token'));
    expect(command.last, contains("'shared/forge-central-token'"));
    terminals.single.endsWith(0);
    await World.settle(tester);
    await tapAndRun(tester, const Key('unlock-done'));

    expect(starts, 2, reason: 'up runs again once the host has the token');
  });

  final commands = <List<String>, String>{
    ['drive']: "'/usr/local/bin/porelo-host-stop' '--email' 'me@example.org' 'drive'",
    ['vault-new']: "'/usr/local/bin/porelo-host-stop' 'vault-new'",
    ['vault']: "'/usr/local/bin/porelo-host-stop' 'vault'",
    ['drive', 'vault-new']: "'/usr/local/bin/porelo-host-stop' '--email' 'me@example.org' 'drive' 'vault-new'",
    ['drive', 'vault']: "'/usr/local/bin/porelo-host-stop' '--email' 'me@example.org' 'drive' 'vault'",
  };

  // Harm: a secret enters the interface widgets, or SSH trusts a key setup did not pin.
  for (final entry in commands.entries) {
    hostWidgets('stop ${entry.key} takes no secret and opens exactly its pinned host command', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final terminals = <FakeTerminal>[];
      final before = machines.all;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              openSecretsFile: _secretsOpened,
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
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
        'host-collection-sha256': collectionDigest,
        'host-identity': fixture('dialog identity'),
        'host-account': 'form-account',
      });
      await tester.pump();
      await tapAndRun(tester, const Key('host-up'));
      await tapAndRun(tester, const Key('host-complete-setup'));
      final fields = tester
          .widgetList<TextField>(
            find.descendant(of: find.byKey(const Key('host-stop-fields')), matching: find.byType(TextField)),
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
      terminals.single.endsWith(0);
      await World.settle(tester);
      expect(find.byKey(const Key('host-done')), findsNothing, reason: 'terminal exit is no setup verdict');
      await tapAndRun(tester, const Key('unlock-done'));
      expect(runs.of('demo')!.ready, isTrue, reason: 'the second up completes setup; no folder, so no VPN');
      final first = File('${scratch.path}/arguments-1').readAsLinesSync();
      expect(File('${scratch.path}/arguments-2').readAsLinesSync(), first);
      for (var n = 1; n <= 2; n++) {
        expect(File('${scratch.path}/input-$n').readAsStringSync(), isEmpty);
      }
    });
  }

  for (final code in [75, 64, 69, 65, 255]) {
    // Harm: cancelled or failed setup runs provisioning again and clears a stop without the person's completion.
    hostWidgets('terminal exit $code keeps the stop and starts no further host command', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final terminal = FakeTerminal([]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              openSecretsFile: _secretsOpened,
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
              secretStore: _MemorySecrets(),
              machines: machines,
              project: 'demo',
              start: stopsThenGoesOn(needs: ['vault']),
              openTerminal: (_, _, {columns = 80, rows = 24}) => terminal,
            ),
          ),
        ),
      );
      await fillSteps(tester, {
        'host-scaleway-project': 'project-1',
        'host-tresor': 'drive',
        'host-collection': fixture('collection.tar.gz'),
        'host-collection-sha256': collectionDigest,
      });
      await tapAndRun(tester, const Key('host-up'));
      final before = machines.all;
      await tapAndRun(tester, const Key('host-complete-setup'));
      await tapAndRun(tester, const Key('host-open-terminal'));
      terminal.endsWith(code);
      await World.settle(tester);
      await tapAndRun(tester, const Key('unlock-done'));
      expect(
        File('${scratch.path}/arguments-2').existsSync(),
        isFalse,
        reason: 'a nonzero terminal exit must never run up again',
      );
      expect(runs.of('demo')!.waiting, isTrue, reason: 'the unresolved stop remains under Needs you');
      expect(runs.preparing, [runs.of('demo')]);
      expect(machines.all, before);
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
    hostWidgets('unsafe e-mail $email is refused without opening a terminal', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostDialog(
              openSecretsFile: _secretsOpened,
              hostFiles: filesFor,
              checkKey: _acceptedKey,
              hostRuns: runs,
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
        'host-collection-sha256': collectionDigest,
      });
      await tester.pump();
      await tapAndRun(tester, const Key('host-up'));
      await tapAndRun(tester, const Key('host-complete-setup'));
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
  _HostProcess({String? inputPath}) {
    if (inputPath != null) File(inputPath).writeAsBytesSync([]);
    _input.stream.listen((bytes) {
      if (inputPath != null) File(inputPath).writeAsBytesSync(bytes, mode: FileMode.append);
    });
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

/// Keeps real file protections without waiting on a chmod process in a widget test.
class _WidgetFileWriter extends host.HostFileWriter {
  @override
  Future<void> protect(File file) async {
    final library = DynamicLibrary.process();
    final allocate = library.lookupFunction<Pointer<Void> Function(IntPtr), Pointer<Void> Function(int)>('malloc');
    final release = library.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('free');
    final chmod = library.lookupFunction<Int32 Function(Pointer<Uint8>, Uint32), int Function(Pointer<Uint8>, int)>(
      'chmod',
    );
    final bytes = [...utf8.encode(file.absolute.path), 0];
    final pointer = allocate(bytes.length).cast<Uint8>();
    try {
      pointer.asTypedList(bytes.length).setAll(0, bytes);
      if (chmod(pointer, 0x180) != 0) throw const host.HostFilesRefused('Cannot protect the widget test file.');
    } finally {
      release(pointer.cast<Void>());
    }
  }
}

/// Completes real file operations only when the test explicitly advances them.
class _HostFileWork {
  final _pending = <Future<void> Function()>[];

  Future<T> defer<T>(Future<T> Function() operation) {
    final answer = Completer<T>();
    _pending.add(() async {
      try {
        answer.complete(await operation());
      } catch (error, stack) {
        answer.completeError(error, stack);
      }
    });
    return answer.future;
  }

  Future<void> complete() async {
    final pending = List.of(_pending);
    _pending.clear();
    for (final operation in pending) {
      await operation();
    }
  }
}

/// Holds file preparation and export at a test-driven boundary without faking their contents.
class _ControlledHostFiles extends host.HostFiles {
  _ControlledHostFiles(super.store, this.work)
    : super(
        writer: _WidgetFileWriter(),
        gitEnvironment: const {
          'GIT_TERMINAL_PROMPT': '0',
          'GIT_CONFIG_GLOBAL': '/dev/null',
          'GIT_CONFIG_NOSYSTEM': '1',
        },
      );

  final _HostFileWork work;

  @override
  Future<List<int>> createBundle({
    required String project,
    required String url,
    required String commit,
    required File signingKey,
  }) => work.defer(() => super.createBundle(project: project, url: url, commit: commit, signingKey: signingKey));

  @override
  Future<void> publishBundle({required String project, required String folder, required List<int> bytes}) =>
      work.defer(() => super.publishBundle(project: project, folder: folder, bytes: bytes));

  @override
  Future<host.HostTunnel> prepare({
    required String project,
    String? folder,
    required String url,
    required File signingKey,
    List<host.HostKeyFile> keys = const [],
    String? hostPublicKey,
  }) => work.defer(
    () => super.prepare(
      project: project,
      folder: folder,
      url: url,
      signingKey: signingKey,
      keys: keys,
      hostPublicKey: hostPublicKey,
    ),
  );

  @override
  Future<void> exportTunnel({
    required String project,
    required host.HostTunnel tunnel,
    required String address,
    required File destination,
  }) => work.defer(
    () => super.exportTunnel(project: project, tunnel: tunnel, address: address, destination: destination),
  );
}

/// Stands in for the secrets file's terminal: the public half of a fixed host key, as the script would write it.
Future<String> _secretsOpened({
  required String file,
  required String project,
  String? migrateKeyFrom,
  Map<String, String> keys = const {},
}) => host.HostFiles.publicKey(base64Encode(List<int>.filled(32, 5)));
