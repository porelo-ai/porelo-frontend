import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/machines_page.dart';

import '../features/support/tiles.dart';
import '../features/support/world.dart';
import '../support/menu_entries.dart';

/// A daemon that never answers, counting how often it was asked.
class _Silent extends FakeBackend {
  _Silent(this.name, this.opens) : super(const []);

  final String name;
  final List<String> opens;

  @override
  Future<ServiceInfo> open() {
    opens.add(name);
    throw const VarlinkDisconnected('nothing there');
  }
}

/// A server prepared with no project: no account of a project, no daemon, no socket.
const _serverOnly = Machine(
  name: 'orchard',
  socketPath: '',
  host: 'orchard.example.org',
  kind: 'host',
  hostProject: 'orchard',
);

void main() {
  group('the machines and what needs a person', () {
    late Settings settings;
    late Machines machines;
    late Attention attention;
    late List<String> opens;

    setUp(() {
      opens = [];
      settings = Settings(MemorySettingsStore());
      machines = Machines(
        settings,
        reach: (machine) => machine.kind == 'host' ? _Silent(machine.name, opens) : FakeBackend(const []),
        tunnels: FakeTunnels(),
      );
      attention = Attention(machines);
    });

    tearDown(() {
      attention.dispose();
      machines.dispose();
      settings.dispose();
    });

    List<String> silentRows() => [
      for (final row in attention.openRows)
        if (row.kind == AttentionKind.silent) row.machine,
    ];

    // Harm: a server prepared with no project, which has no daemon by design, is raised under Needs you as not
    // answering, and a person goes looking for a fault; while a host with a socket that does not answer is excused.
    test('a server with no project is neither tried nor silent, and a host with a socket that is silent is', () async {
      await machines.add(_serverOnly);
      await machines.add(const Machine(name: 'apple', socketPath: '/tmp/apple.sock', kind: 'host'));
      await machines.of(machines.all.firstWhere((each) => each.name == 'apple')).untilAsked();
      await pumpEventQueue();
      expect(opens.where((name) => name == 'orchard'), isEmpty, reason: 'nothing there to try');
      expect(attention.silent.map((each) => each.name), ['apple']);
      expect(silentRows(), ['apple']);
    });

    // Harm: a project put on the server leaves it excused for good, and its daemon going away is never said.
    test('a server that gets a socket counts as any other machine again', () async {
      await machines.add(_serverOnly);
      await pumpEventQueue();
      expect(attention.silent, isEmpty);
      await machines.add(
        const Machine(name: 'orchard', socketPath: '/tmp/orchard.sock', host: 'orchard.example.org', kind: 'host'),
      );
      await machines.of(machines.all.firstWhere((each) => each.name == 'orchard')).untilAsked();
      expect(opens, contains('orchard'));
      expect(attention.silent.map((each) => each.name), ['orchard']);
    });

    // Harm: one server with no project beside a machine that answers keeps every count of the window unread for good.
    test('a server with no project leaves the counts of the machines that answer read', () async {
      await machines.add(const Machine(name: 'lemon', socketPath: '/tmp/lemon.sock'));
      await machines.add(_serverOnly);
      await machines.of(machines.all.firstWhere((each) => each.name == 'lemon')).untilAsked();
      await pumpEventQueue();
      expect(attention.workRead(), isTrue);
      expect(attention.needsRead, isTrue);
      expect(attention.workCount, isNotNull);
      expect(attention.needingCount, isNotNull);
    });

    // Harm: F5 or Reconnect tries a server that has no daemon, turns it unreachable and retries it for good.
    test('refreshing or reconnecting a server with no project tries nothing and leaves it not unreachable', () async {
      await machines.add(_serverOnly);
      await pumpEventQueue();
      final fleet = machines.of(machines.all.firstWhere((each) => each.name == 'orchard'));
      await fleet.refresh();
      await fleet.connect();
      await pumpEventQueue();
      expect(opens, isEmpty, reason: 'nothing there to try');
      expect(fleet.reachability, isNot(Reachability.unreachable));
      expect(machines.unreachable, 0);
      expect(fleet.status, startsWith('No project yet'));
    });
  });

  // Harm: a person is offered Refresh and Reconnect on a server that has no daemon to reach, and its status line says
  // it is still being opened.
  testWidgets('Refresh and Reconnect are unavailable on a server with no project, and its status says so', (
    tester,
  ) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.machines.add(_serverOnly);
    await toTheMachinesPage(tester, 'orchard');
    expect(find.byKey(const Key('status-line')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('status-line'))).data, startsWith('No project yet'));
    expect(find.byTooltip('No project yet'), findsWidgets);
    expect(find.byTooltip('Connecting'), findsNothing);
    final refresh = find.byKey(const Key('fleet.refresh'));
    expect(tester.widget<ButtonStyleButton>(refresh).onPressed, isNull);
    expect(find.ancestor(of: refresh, matching: find.byTooltip(RegExp('^no project yet'))), findsOneWidget);
    await World.tapInView(tester, 'machine-menu');
    final reconnect = find.byKey(const ValueKey('fleet.reconnect'));
    expect(menuEntryEnabled(tester, reconnect), isFalse);
    expect(
      find.descendant(of: reconnect, matching: find.textContaining('Unavailable: no project yet')),
      findsOneWidget,
    );
  });

  // Harm: one server with no project keeps Work and Planning saying a machine is not answering or being opened.
  testWidgets('Work and Planning say nothing unread or being opened for a server with no project', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.machines.add(_serverOnly);
    await World.settle(tester);
    World.shell.goTo(Section.work);
    await World.settle(tester);
    expect(find.textContaining('Not read: a machine is not answering'), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('rail-work-count'))).data, isNot('?'));
    expect(find.byKey(const Key('needing-count-badge')), findsOneWidget);
    World.shell.goTo(Section.planning);
    await World.settle(tester);
    expect(find.textContaining('being opened'), findsNothing);
  });

  // Harm: the side bar entry of a server with no project, its page and its row say it is not answering or not
  // connected, as if something had failed.
  testWidgets('its side bar entry, its page and its row in Machines say No project yet', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.machines.add(_serverOnly);
    await toTheMachines(tester);
    final entry = find.byKey(const ValueKey('rail machine orchard'));
    expect(find.descendant(of: entry, matching: find.byTooltip('No project yet')), findsOneWidget);
    expect(find.descendant(of: entry, matching: find.byTooltip('Not answering')), findsNothing);
    expect(find.descendant(of: entry, matching: find.byTooltip('Connecting')), findsNothing);
    await toTheMachinesPage(tester, 'orchard');
    expect(find.textContaining('No project yet'), findsWidgets);
    expect(find.textContaining('Not answering'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MachinesPage(machines: World.machines, onAdd: () {}, onDetails: (_) {}, onForget: (_) {}),
        ),
      ),
    );
    await World.settle(tester);
    final row = find.byKey(const ValueKey('machines-row orchard'));
    expect(find.descendant(of: row, matching: find.textContaining('No project yet')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('not connected')), findsNothing);
    expect(find.byKey(const ValueKey('machines-menu orchard')), findsOneWidget);
  });
}
