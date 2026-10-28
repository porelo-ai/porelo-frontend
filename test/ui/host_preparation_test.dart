import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_frontend/src/ui/host_stop_dialog.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';
import '../support/expand_list_rows.dart';

const _record = HostUpRecord(
  scalewayProject: 'provider',
  account: 'worker',
  tresor: 'drive',
  folder: null,
  repository: '',
  signingKey: '',
  identity: '/keys/private',
  publicKey: '/keys/public',
  collection: '',
  vpnPeerPublicKey: '',
  vpnPeerAddress: '',
  // A host key, so completion waits for the VPN; without one the host files were supplied by hand.
  vpnHostPublicKey: 'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc=',
  vpnEndpointAddress: '203.0.113.7',
);

void main() {
  // Harm: an unseen setup stop leaves a rented host billing and the person cannot reach its terminal.
  testWidgets('a preparing server opens its protocol and its Needs you stop reaches the same terminal', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    final runs = HostRuns(machines, endpointFor: (_) => '/tmp/prepared.sock');
    final attention = Attention(machines)..hostRuns = runs;
    final process = HostProcess();
    final resumed = HostProcess();
    final commands = <List<String>>[];
    final terminals = <FakeTerminal>[];
    final session = HostSession(
      executable: 'fake',
      arguments: const ['--project', 'demo'],
      start: (_, arguments) async {
        commands.add(List.of(arguments));
        return commands.length == 1 ? process : resumed;
      },
    );
    final run = runs.start(project: 'demo', session: session, record: _record);
    var needs = false;
    late StateSetter change;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              void open(HostPreparation run) => unawaited(
                showDialog<void>(
                  context: context,
                  builder: (_) => run.waiting
                      ? HostStopDialog(
                          run: run,
                          hostRuns: runs,
                          machines: machines,
                          settings: settings,
                          openTerminal: (program, arguments, {columns = 80, rows = 24}) {
                            final terminal = FakeTerminal([program, ...arguments]);
                            terminals.add(terminal);
                            return terminal;
                          },
                        )
                      : HostDialog(
                          project: run.project,
                          machines: machines,
                          settings: settings,
                          hostRuns: runs,
                          existingRun: run,
                          openTerminal: (program, arguments, {columns = 80, rows = 24}) {
                            final terminal = FakeTerminal([program, ...arguments]);
                            terminals.add(terminal);
                            return terminal;
                          },
                        ),
                ),
              );
              return Scaffold(
                body: needs
                    ? AttentionView(
                        attention: attention,
                        onDecide: (_, _, {required allow}) {},
                        actionsFor: (_) => [],
                        onReview: (_) {},
                        onOpenHost: (project) => open(runs.of(project)!),
                      )
                    : ListenableBuilder(
                        listenable: runs,
                        builder: (_, _) => MachinesPage(
                          machines: machines,
                          hostRuns: runs,
                          onAdd: () {},
                          onDetails: (_) {},
                          onForget: (_) {},
                          onHostProtocol: open,
                        ),
                      ),
              );
            },
          ),
        ),
      );
      process.line(
        const Step(
          'plan',
          StepState.plan,
          steps: [PlannedStep('install', 'Install the operating system', seconds: 60)],
        ),
      );
      process.line(const Step('install', StepState.started, text: 'Install the operating system', seconds: 60));
      process.words('The provider accepted the request.');
      await World.settle(tester);
      await expandListRows(tester);
      final row = find.byKey(const Key('host-preparing demo'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('In preparation')), findsWidgets);
      expect(find.descendant(of: row, matching: find.text('Install the operating system')), findsOneWidget);
      expect(find.textContaining('left in all'), findsOneWidget);
      expect(find.textContaining('left in this step'), findsOneWidget);
      expect(machines.all.where((machine) => machine.kind == 'host'), isEmpty);
      await tester.tap(find.text('demo server').first);
      await World.settle(tester);
      expect(
        find.textContaining('The provider accepted the request.'),
        findsWidgets,
        reason: 'the unexpected host message must remain readable from the running preparation',
      );
      await tester.tap(find.byKey(const Key('host-close')));
      await World.settle(tester);
      expect(row, findsOneWidget);
      process.line(
        const Step(
          'person',
          StepState.waiting,
          text: 'Unlock the project vault',
          needs: ['vault'],
          address: '203.0.113.7',
          account: 'worker',
        ),
      );
      process.end(75);
      await World.settle(tester);
      expect(find.text('Needs you'), findsOneWidget);
      change(() => needs = true);
      await World.settle(tester);
      await expandListRows(tester);
      final stop = find.byKey(const Key('host-needs demo'));
      expect(find.descendant(of: stop, matching: find.text('on demo server')), findsOneWidget);
      expect(find.descendant(of: stop, matching: find.text('Unlock the project vault')), findsOneWidget);
      await tester.tap(find.text('Complete setup on the host'));
      await World.settle(tester);
      await tester.ensureVisible(find.byKey(const Key('host-open-terminal')));
      await tester.tap(find.byKey(const Key('host-open-terminal')));
      await World.settle(tester);
      expect(terminals, hasLength(1));
      expect(terminals.single.command, contains('worker@203.0.113.7'));
      expect(commands, hasLength(1), reason: 'the terminal must finish before up resumes');
      terminals.single.endsWith(0);
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('unlock-done')));
      await World.settle(tester);
      expect(commands, [commands.first, commands.first]);
      resumed.line(
        const Step(
          'up',
          StepState.done,
          address: '203.0.113.7',
          account: 'worker',
          socket: '/run/user/1007/porelo/porelod.sock',
        ),
      );
      expect(run.ready, isFalse, reason: 'a line alone must not mark a host ready');
      resumed.end(0);
      await World.settle(tester);
      expect(run.ready, isFalse, reason: 'the host command does not confirm the local VPN');
      await runs.vpnChecked(run, verified: true);
      await World.settle(tester);
      expect(run.ready, isTrue);
      expect(find.byType(HostDialog), findsNothing, reason: 'verified setup closes itself');
      expect(find.byKey(const Key('recently-resolved')), findsOneWidget);
      await expandListRows(tester, within: find.byKey(const Key('recently-resolved')));
      final resolved = find.descendant(
        of: find.byKey(const Key('recently-resolved')),
        matching: find.byKey(const Key('host-needs demo')),
      );
      expect(resolved, findsOneWidget);
      expect(find.descendant(of: resolved, matching: find.text('on demo server')), findsOneWidget);
      change(() => needs = false);
      await World.settle(tester);
      expect(find.byKey(const Key('host-preparing demo')), findsNothing);
      expect(find.byKey(const Key('machines-row demo server')), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      attention.dispose();
      runs.dispose();
      machines.dispose();
      settings.dispose();
    }
  });

  // Harm: a refusal of up that asks for a secret on its own call, left without a way on, or answered with an entry
  // machine.yml does not name.
  for (final (need, fix, withFile) in [
    ('forge-central-token', 'forge-central-token: stand-in still to migrate', true),
    ('keys', 'keys: the vault lacks forge', true),
    ('matrix-token', 'matrix-token: the account has no token for the laptop\'s homeserver', true),
    // The token is this computer's Porelo's to give: no secrets file is needed for it.
    ('matrix-token', 'matrix-token: the account has no token for the laptop\'s homeserver', false),
  ]) {
    testWidgets('up refused for $need waits under Needs you and gives it on its own call (file $withFile)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = Settings(MemorySettingsStore());
      if (withFile) await settings.rememberSecretsFile('/home/person/Porelo/secrets.kdbx');
      final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
      final runs = HostRuns(machines, endpointFor: (_) => '/tmp/prepared.sock');
      final attention = Attention(machines)..hostRuns = runs;
      final process = HostProcess();
      final terminals = <FakeTerminal>[];
      var starts = 0;
      final run = runs.start(
        project: 'demo',
        session: HostSession(
          executable: 'fake',
          arguments: const ['--project', 'demo'],
          start: (_, _) async => starts++ == 0 ? process : HostProcess(),
        ),
        record: HostUpRecord.fromStored({
          ..._record.stored,
          'vaultKeys': ['forge'],
        })!,
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: AttentionView(
                  attention: attention,
                  onDecide: (_, _, {required allow}) {},
                  actionsFor: (_) => [],
                  onReview: (_) {},
                  onOpenHost: (project) => unawaited(
                    openHostStopDialog(
                      context,
                      run: runs.of(project)!,
                      hostRuns: runs,
                      machines: machines,
                      settings: settings,
                      needs: runs.of(project)!.asksOnItsOwn,
                      openTerminal: (program, arguments, {columns = 80, rows = 24}) {
                        final terminal = FakeTerminal([program, ...arguments]);
                        terminals.add(terminal);
                        return terminal;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        process.line(Step('repositories', StepState.refused, fix: fix, address: '203.0.113.7', admin: 'ubuntu'));
        process.end(2);
        await World.settle(tester);
        expect(run.needsYou, isTrue);
        await expandListRows(tester);
        final row = find.byKey(const Key('host-needs demo'));
        expect(find.descendant(of: row, matching: find.text(need)), findsOneWidget);
        await tester.tap(find.text('Complete setup on the host'));
        await World.settle(tester);
        await tester.ensureVisible(find.byKey(const Key('host-open-terminal')));
        await tester.tap(find.byKey(const Key('host-open-terminal')));
        await World.settle(tester);
        final script = terminals.single.command.last;
        expect(script, contains('porelo-host-stop --stdin $need'));
        expect(script, contains('ubuntu@203.0.113.7'), reason: 'as the refusal\'s own user');
        if (need == 'keys') expect(script, contains("'hosts/demo/keys/forge'"), reason: 'the entry machine.yml names');
        if (need == 'matrix-token') {
          expect(script, contains('porelo talk admit demo'), reason: 'this computer lets the host in');
          expect(script, isNot(contains('read -rs')), reason: 'no master password for a token the file has no part in');
        }
        terminals.single.endsWith(0);
        await World.settle(tester);
        await tester.tap(find.byKey(const Key('unlock-done')));
        await World.settle(tester);
        expect(starts, 2, reason: 'up runs again once the host has it');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        attention.dispose();
        runs.dispose();
        machines.dispose();
        settings.dispose();
      }
    });
  }

  // Harm: without a secrets file, the vault typed in the host's terminal and the token fed beside it, which one
  // terminal cannot do: the stop says it, and opens nothing half.
  testWidgets('without a secrets file, a stop for the vault and the token says it cannot give the token', (
    tester,
  ) async {
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    final runs = HostRuns(machines, endpointFor: (_) => '/tmp/prepared.sock');
    final process = HostProcess();
    final run = runs.start(
      project: 'demo',
      session: HostSession(executable: 'fake', arguments: const ['--project', 'demo'], start: (_, _) async => process),
      record: _record,
    );
    try {
      process.line(
        const Step(
          'person',
          StepState.waiting,
          needs: ['vault', 'matrix-token'],
          address: '203.0.113.7',
          account: 'worker',
          admin: 'ubuntu',
        ),
      );
      process.end(75);
      await run.finished;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostStopDialog(run: run, hostRuns: runs, machines: machines, settings: settings),
          ),
        ),
      );
      await World.settle(tester);
      expect(find.textContaining('porelo-host waits for matrix-token'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('host-open-terminal'))).onPressed, isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      runs.dispose();
      machines.dispose();
      settings.dispose();
    }
  });

  // Harm: a VPN key from the file fed to a host whose files, given by hand, carry the person's own.
  // Since the upload, the interface writes the host's files itself, with the file's key, into its setup folder.
  for (final byHand in [true, false]) {
    testWidgets('with host files given by hand ($byHand) the file gives the VPN key only for files it wrote', (
      tester,
    ) async {
      final record = byHand
          ? _record
          : HostUpRecord.fromStored({
              ..._record.stored,
              'setupFolder': path.join(Directory.systemTemp.path, 'conf', 'hosts', 'demo'),
            })!;
      final settings = Settings(MemorySettingsStore());
      await settings.rememberSecretsFile('/home/person/Porelo/secrets.kdbx');
      final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
      final runs = HostRuns(machines, endpointFor: (_) => '/tmp/prepared.sock');
      final process = HostProcess();
      final run = runs.start(
        project: 'demo',
        session: HostSession(
          executable: 'fake',
          arguments: const ['--project', 'demo'],
          start: (_, _) async => process,
        ),
        record: record,
      );
      try {
        process.line(
          const Step(
            'person',
            StepState.waiting,
            needs: ['vault', 'wireguard'],
            address: '203.0.113.7',
            account: 'worker',
            admin: 'ubuntu',
          ),
        );
        process.end(75);
        await run.finished;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HostStopDialog(run: run, hostRuns: runs, machines: machines, settings: settings),
            ),
          ),
        );
        await World.settle(tester);
        expect(record.folder, isNull);
        expect(
          tester.widget<FilledButton>(find.byKey(const Key('host-open-terminal'))).onPressed,
          byHand ? isNull : isNotNull,
        );
        expect(find.textContaining('porelo-host waits for wireguard'), byHand ? findsOneWidget : findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        runs.dispose();
        machines.dispose();
        settings.dispose();
      }
    });
  }

  // Harm: the lasting CA signed with but never trusted here, or a stale file of it left in the temporary folder.
  // Harm, too: a lasting CA that ends unseen, where the stop is the place a new one is made.
  testWidgets('a stop for the forge\'s certificate keeps the lasting CA it signed with, and its folder goes', (
    tester,
  ) async {
    final settings = Settings(MemorySettingsStore());
    await settings.rememberSecretsFile('/home/person/Porelo/secrets.kdbx');
    final scratch = (await tester.runAsync(() => Directory.systemTemp.createTemp('stop-forge-ca-')))!;
    addTearDown(() => scratch.delete(recursive: true));
    final made = (await tester.runAsync(
      () => Process.run('openssl', [
        'req', '-x509', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:P-256', '-nodes', '-days', '30', //
        '-subj', '/CN=forge-ca-test', '-keyout', '${scratch.path}/key.pem', '-out', '${scratch.path}/ca.pem',
      ]),
    ))!;
    expect(made.exitCode, 0, reason: '${made.stderr}');
    await settings.rememberForgeCa(File('${scratch.path}/ca.pem').readAsStringSync());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    final runs = HostRuns(machines, endpointFor: (_) => '/tmp/prepared.sock');
    final process = HostProcess();
    final terminals = <FakeTerminal>[];
    var starts = 0;
    final run = runs.start(
      project: 'demo',
      session: HostSession(
        executable: 'fake',
        arguments: const ['--project', 'demo'],
        start: (_, _) async => starts++ == 0 ? process : HostProcess(),
      ),
      record: HostUpRecord.fromStored({
        ..._record.stored,
        'setupFolder': path.join(Directory.systemTemp.path, 'conf', 'hosts', 'demo'),
      })!,
    );
    try {
      process.line(
        const Step(
          'person',
          StepState.waiting,
          needs: ['forge-certificate'],
          address: '203.0.113.7',
          account: 'worker',
          admin: 'ubuntu',
        ),
      );
      process.end(75);
      await run.finished;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostStopDialog(
              run: run,
              hostRuns: runs,
              machines: machines,
              settings: settings,
              openTerminal: (program, arguments, {columns = 80, rows = 24}) {
                final terminal = FakeTerminal([program, ...arguments]);
                terminals.add(terminal);
                return terminal;
              },
            ),
          ),
        ),
      );
      await World.settle(tester);
      expect(find.textContaining('signed on this computer by your lasting CA'), findsOneWidget);
      await tester.tap(find.byKey(const Key('host-open-terminal')));
      await World.settle(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('unlock-explained'))).data,
        allOf(contains('forges ends on'), contains('this stop makes the new one')),
        reason: 'said where a new one is made',
      );
      final caout = RegExp(r"caout='?([^'\n]+)'?\n").firstMatch(terminals.single.command.last)!.group(1)!;
      const pem = '-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n';
      File(caout).writeAsStringSync(pem);
      terminals.single.endsWith(0);
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('unlock-done')));
      await World.settle(tester);
      expect(settings.forgeCa, pem);
      expect(File(caout).parent.existsSync(), isFalse, reason: 'the folder goes once it is read');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      runs.dispose();
      machines.dispose();
      settings.dispose();
    }
    // The stop is fed from the file on Linux only, and openssl makes the CA.
  }, skip: !Platform.isLinux);

  group('a stopped setup', () {
    late Settings settings;
    late Machines machines;
    late HostRuns runs;
    late HostProcess process;
    late HostProcess resumed;
    late HostPreparation run;
    late List<FakeTerminal> terminals;

    setUp(() async {
      settings = Settings(MemorySettingsStore());
      machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
      runs = HostRuns(machines, endpointFor: (_) => '/tmp/prepared.sock');
      process = HostProcess();
      resumed = HostProcess();
      terminals = [];
      var starts = 0;
      run = runs.start(
        project: 'demo',
        session: HostSession(
          executable: 'fake',
          arguments: const ['--project', 'demo'],
          start: (_, _) async => starts++ == 0 ? process : resumed,
        ),
        record: _record,
      );
      process.line(
        const Step(
          'person',
          StepState.waiting,
          text: 'Unlock the project vault',
          needs: ['vault'],
          address: '203.0.113.7',
          account: 'worker',
        ),
      );
      process.end(75);
      await run.finished;
    });

    tearDown(() {
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });

    FakeTerminal openTerminal(String program, List<String> arguments, {int columns = 80, int rows = 24}) {
      final terminal = FakeTerminal([program, ...arguments]);
      terminals.add(terminal);
      return terminal;
    }

    Future<void> openFrom(WidgetTester tester, Future<void> Function(BuildContext context) open) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(onPressed: () => unawaited(open(context)), child: const Text('open')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await World.settle(tester);
    }

    // Harm: a stale stop dialog stays open over a finished run, and its terminal could run the host script again.
    testWidgets('no stop dialog is left open when setup resumes', (tester) async {
      expect(run.waiting, isTrue);
      await openFrom(
        tester,
        (context) => openHostStopDialog(
          context,
          run: run,
          hostRuns: runs,
          machines: machines,
          settings: settings,
          openTerminal: openTerminal,
        ),
      );
      expect(find.byType(HostStopDialog), findsOneWidget);
      unawaited(runs.resume(run));
      await World.settle(tester);
      expect(run.waiting, isFalse);
      expect(find.byType(HostStopDialog), findsNothing, reason: 'a run that no longer waits asks nothing');
      resumed.end(0);
      await World.settle(tester);
    });

    // Harm: stacked stop dialogs leave one open over a finished run, where its terminal reruns the host script.
    testWidgets('the setup protocol replaces the stop dialog and no stop is left once setup went on', (tester) async {
      await openFrom(
        tester,
        (context) => openHostStopDialog(
          context,
          run: run,
          hostRuns: runs,
          machines: machines,
          settings: settings,
          openTerminal: openTerminal,
        ),
      );
      await tester.tap(find.text('Show the setup protocol'));
      await World.settle(tester);
      expect(find.byType(HostDialog), findsOneWidget);
      expect(find.byType(HostStopDialog), findsNothing, reason: 'the protocol replaces the stop, it does not stack');
      await tester.tap(find.byKey(const Key('host-complete-setup')));
      await World.settle(tester);
      expect(find.byType(HostStopDialog), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('host-open-terminal')));
      await tester.tap(find.byKey(const Key('host-open-terminal')));
      await World.settle(tester);
      expect(terminals, hasLength(1), reason: 'the stop of the protocol uses the injected terminal');
      terminals.single.endsWith(0);
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('unlock-done')));
      await World.settle(tester);
      resumed.line(const Step('up', StepState.done, address: '203.0.113.7', account: 'worker', socket: '/run/s.sock'));
      resumed.end(0);
      await World.settle(tester);
      expect(run.waiting, isFalse);
      expect(find.byType(HostStopDialog), findsNothing, reason: 'no stop dialog stays over a finished run');
    });

    // Harm: a stop opened from the protocol runs a real SSH terminal instead of the one handed in.
    testWidgets('the stop opened from the run dialog uses the injected terminal', (tester) async {
      await openFrom(
        tester,
        (context) => openHostRunDialog(
          context,
          run: run,
          hostRuns: runs,
          machines: machines,
          settings: settings,
          openTerminal: openTerminal,
        ),
      );
      await tester.tap(find.byKey(const Key('host-complete-setup')));
      await World.settle(tester);
      await tester.ensureVisible(find.byKey(const Key('host-open-terminal')));
      await tester.tap(find.byKey(const Key('host-open-terminal')));
      await World.settle(tester);
      expect(terminals, hasLength(1), reason: 'the injected opener must start the terminal');
      expect(terminals.single.command, contains('worker@203.0.113.7'));
      terminals.single.endsWith(75);
      await World.settle(tester);
    });
  });
}
