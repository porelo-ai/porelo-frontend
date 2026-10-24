import 'dart:async';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';
import 'package:porelo_frontend/src/ui/host_dialog.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/host_process.dart';

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
                  builder: (_) => HostDialog(
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
      final row = find.byKey(const Key('host-preparing demo'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('In preparation')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Install the operating system')), findsOneWidget);
      expect(find.textContaining('left in all'), findsOneWidget);
      expect(find.textContaining('left in this step'), findsOneWidget);
      expect(machines.all.where((machine) => machine.kind == 'host'), isEmpty);
      await tester.tap(row);
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('host-full-protocol')));
      await World.settle(tester);
      expect(find.textContaining('The provider accepted the request.'), findsWidgets);
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
}
