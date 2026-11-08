import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/where_you_were.dart';
import 'package:porelo_frontend/src/app/connections.dart';
import 'package:porelo_frontend/src/ui/shell_rail.dart';
import 'package:porelo_frontend/src/ui/vault_view.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

Future<void> _start(WidgetTester tester) async {
  await World.startBackend(World.work);
  await World.startApp(tester);
}

Future<void> _tap(WidgetTester tester, String key) => World.tapInView(tester, key);

String _machineKey([String? name]) => 'rail ${ShellPlace.machineKey(name ?? World.machines.current.name)}';
String _leafKey(String leaf, [String? name]) => '${_machineKey(name)} $leaf';

void main() {
  // Harm: a credential shown from one machine can be removed from another while its read waits.
  test('changing the connections owner clears old rows before the new read answers', () async {
    final connections = Connections();
    addTearDown(connections.dispose);
    final first = FakeBackend([])..theConnections = [const Connection(match: 'first.example.org')];
    await connections.lookAt(first, 'first');
    final second = _WaitingCredentials();
    final read = connections.lookAt(second, 'second');
    expect(connections.all, isEmpty);
    second.reply.complete(const VaultState(vault: '', exists: true, readable: true, credentials: []));
    await read;
    await first.stop();
    await second.stop();
  });

  // Harm: a late response replaces the selected machine's credentials with another's.
  test('a superseded credentials read cannot replace the new owner rows', () async {
    final connections = Connections();
    addTearDown(connections.dispose);
    final first = _WaitingCredentials();
    final oldRead = connections.lookAt(first, 'first');
    final second = FakeBackend([])..theConnections = [const Connection(match: 'second.example.org')];
    await connections.lookAt(second, 'second');
    first.reply.complete(
      const VaultState(
        vault: '',
        exists: true,
        readable: true,
        credentials: [],
        connections: [Connection(match: 'first.example.org')],
      ),
    );
    await oldRead;
    expect(connections.all.map((row) => row.match), ['second.example.org']);
    expect(connections.machine, 'second');
    await first.stop();
    await second.stop();
  });

  // Harm: unrestricted names collide with section keys and crash navigation.
  test('machine and organization parent identities cannot collide with leaves', () {
    const first = Machine(name: 'lab', socketPath: '/first');
    const second = Machine(name: 'lab vault', socketPath: '/second');
    expect(
      const ShellPlace(Section.machine, machine: first, machineSection: MachineSection.vault).key,
      isNot(const ShellPlace(Section.machine, machine: second).key),
    );
    expect(
      const ShellPlace(Section.organization, organization: 'acme', organizationSection: OrganizationSection.people).key,
      isNot(const ShellPlace(Section.organization, organization: 'acme people').key),
    );
  });
  // Harm: a machine tool is unreachable without discovering a hidden menu.
  testWidgets('a machine vault is reached from the side bar without its menu', (tester) async {
    await _start(tester);
    await _tap(tester, _leafKey('vault'));
    expect(find.byKey(const Key('vault-view')), findsOneWidget);
  });

  // Harm: credentials or vault actions are shown for a different machine.
  testWidgets('a section under the second machine shows the second machine', (tester) async {
    await _start(tester);
    final first = World.machines.current;
    const second = Machine(name: 'elsewhere', socketPath: '/unused');
    World.elsewhere.theStoreIs = VaultState.from(const {
      'vault': '/unused',
      'exists': true,
      'readable': true,
      'credentials': [
        {'name': 'second-machine-entry', 'type': 'api-key', 'characters': 24},
      ],
    });
    await World.machines.add(second);
    World.machines.select(first);
    await World.settle(tester);
    await _tap(tester, _machineKey('elsewhere'));
    await _tap(tester, _leafKey('vault', 'elsewhere'));
    expect(tester.widget<VaultView>(find.byType(VaultView)).vault.about, 'elsewhere');
    expect(find.byKey(const Key('vault-view')), findsOneWidget);
    expect(find.text('second-machine-entry'), findsOneWidget);
    expect(find.text('a-provider'), findsNothing);
    expect(World.machines.current, second);
  });

  // Harm: a machine destination displays work belonging to a different machine.
  testWidgets('a machine Tasks leaf keeps work from other machines out', (tester) async {
    await _start(tester);
    final first = World.machines.current;
    await World.machines.add(const Machine(name: 'elsewhere', socketPath: '/unused'));
    await World.settle(tester);
    await _tap(tester, _leafKey('tasks', first.name));
    expect(find.byKey(ValueKey('tile ${first.name} porelo-checkout-shell')), findsOneWidget);
    expect(find.byKey(const Key('tile elsewhere porelo-shared-shell')), findsNothing);
  });

  // Harm: a command on one machine silently starts work on another.
  testWidgets('New work on a silent machine cannot start work on another machine', (tester) async {
    await _start(tester);
    final first = World.machines.current;
    await World.machines.add(const Machine(name: 'elsewhere', socketPath: '/unused'));
    await World.settle(tester);
    World.backend.absent = const VarlinkDisconnected('gone');
    World.backend.lose();
    await World.settle(tester);
    await _tap(tester, _leafKey('tasks', first.name));
    final action = tester.widget<FilledButton>(find.byKey(const Key('new-work')));
    expect(action.onPressed, isNull);
    expect(World.elsewhere.starts, isEmpty);
  });

  // Harm: duplicate navigation obscures the actions belonging to a parent.
  testWidgets('an entry with entries under it shows no list of them', (tester) async {
    await _start(tester);
    await _tap(tester, 'rail machines');
    expect(find.byKey(const Key('facts-page')), findsOneWidget);
    expect(find.byKey(const Key('machine-tree')), findsNothing);
    await _tap(tester, _machineKey());
    expect(find.byKey(const Key('facts-page')), findsOneWidget);
    expect(find.byKey(ValueKey('machine-projects ${World.machines.current.name}')), findsNothing);
  });

  // Harm: folding loses the current place or prevents reaching its children.
  testWidgets('a second click on the chosen entry folds it', (tester) async {
    await _start(tester);
    await _tap(tester, 'rail machines');
    expect(find.byKey(ValueKey(_machineKey())), findsOneWidget);
    await _tap(tester, 'rail machines');
    expect(find.byKey(ValueKey(_machineKey())), findsNothing);
    expect(find.byKey(const Key('facts-page')), findsOneWidget);
  });

  // Harm: tablet navigation hides the page behind a drawer.
  testWidgets('a window 700 wide keeps the side bar beside the page', (tester) async {
    await _start(tester);
    tester.view.physicalSize = const Size(700, 800);
    await World.settle(tester);
    expect(find.byKey(const Key('shell-rail')).hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('open-rail')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Harm: the phone drawer either covers the destination or closes too early.
  testWidgets('a phone drawer stays for a parent and closes for a leaf', (tester) async {
    await _start(tester);
    tester.view.physicalSize = const Size(390, 800);
    await World.settle(tester);
    await _tap(tester, 'open-rail');
    await _tap(tester, 'rail machines');
    expect(find.byKey(const Key('shell-rail')).hitTestable(), findsOneWidget);
    await _tap(tester, _leafKey('vault'));
    expect(find.byKey(const Key('shell-rail')).hitTestable(), findsNothing);
    expect(find.byKey(const Key('vault-view')), findsOneWidget);
  });

  // Harm: different counts imply that some watched data was lost.
  testWidgets('each count in the side bar is the rows of the page it opens', (tester) async {
    await _start(tester);
    for (final (key, count) in [
      ('rail-work-count', World.fleet.tasks.length),
      ('rail-machines-count', World.machines.all.length),
      ('rail-projects-count', projectsOnMachine(World.machines, World.machines.current).length),
      ('rail-forges-count', 0),
      ('rail-organizations-count', 0),
    ]) {
      expect(tester.widget<Text>(find.byKey(Key(key))).data, '$count');
    }
    final badge = tester.widget<Badge>(find.byKey(const Key('needing-count-badge')));
    await _tap(tester, 'rail attention');
    final rows = find
        .descendant(
          of: find.byKey(const Key('open-attention')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('attention-row '),
          ),
        )
        .evaluate()
        .length;
    expect(badge.isLabelVisible, rows > 0);
    expect((badge.label! as Text).data, '$rows');
  });

  // Harm: a silent machine is mistaken for a healthy one.
  testWidgets('a machine that does not answer says so in the side bar', (tester) async {
    await _start(tester);
    World.backend.absent = const VarlinkDisconnected('gone');
    World.backend.lose();
    await World.settle(tester);
    expect(find.byTooltip('Not answering'), findsOneWidget);
  });

  // Harm: the visible emergency stop leaves other machines running.
  for (final width in [390.0, 700.0, 1280.0]) {
    testWidgets('the title bar stop at $width stops every machine', (tester) async {
      await _start(tester);
      await World.machines.add(const Machine(name: 'elsewhere', socketPath: '/unused'));
      tester.view.physicalSize = Size(width, 800);
      await World.settle(tester);
      expect(find.byKey(const Key('stop-everywhere-bar')).hitTestable(), findsOneWidget);
      expect(
        find.ancestor(of: find.byKey(const Key('stop-everywhere-bar')), matching: find.byType(AppBar)),
        findsOneWidget,
      );
      if (width != 1280) {
        await _tap(tester, 'bar-overflow');
        expect(find.text('Stop everything on every machine'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await World.settle(tester);
      }
      await _tap(tester, 'stop-everywhere-bar');
      await _tap(tester, 'stop-everywhere-now');
      expect(World.backend.panics, contains(false));
      expect(World.elsewhere.panics, contains(false));
      expect(tester.takeException(), isNull);
    });
  }

  // Harm: on a tablet the organization's button moves behind the actions, away from where the desktop keeps it.
  for (final width in [390.0, 700.0, 1000.0, 1280.0]) {
    testWidgets('the title bar at $width puts the organization where its design does', (tester) async {
      await _start(tester);
      tester.view.physicalSize = Size(width, 800);
      await World.settle(tester);
      final organization = tester.getRect(find.byKey(const Key('organization-choice')));
      final stop = tester.getRect(find.byKey(const Key('stop-everywhere-bar')));
      if (width == 390) {
        // On the phone the ⋮ comes before the organization's button.
        expect(tester.getRect(find.byKey(const Key('bar-overflow'))).right, lessThanOrEqualTo(organization.left));
      } else {
        // Beside a wider window the organization's button stands left of the actions.
        final more = find.byKey(width == 1280 ? const Key('options-menu') : const Key('bar-overflow'));
        expect(organization.right, lessThanOrEqualTo(stop.left));
        expect(organization.right, lessThanOrEqualTo(tester.getRect(more).left));
      }
      expect(tester.takeException(), isNull);
    });
  }

  // Harm: unread data is reported as an empty system.
  testWidgets('a count not read shows a question mark never zero', (tester) async {
    await _start(tester);
    World.backend.absent = const VarlinkDisconnected('gone');
    World.backend.lose();
    await World.settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('rail-work-count'))).data, '?');
  });

  // Harm: a control promises an operation which cannot happen.
  testWidgets('an action waiting for a command cannot be pressed', (tester) async {
    await _start(tester);
    await _tap(tester, 'rail organizations');
    final waiting = find.byKey(const Key('waiting Join an organization…'));
    expect(tester.widget<OutlinedButton>(waiting).onPressed, isNull);
    expect(find.textContaining('waits for a command'), findsWidgets);
  });

  // Harm: a second organization disappears because the tree assumes exactly one.
  testWidgets('Organizations lists the organization read and a second beside it', (tester) async {
    const organizations = [
      OrganizationView(name: 'acme', keptIn: '', vouchedBy: '', revision: 'r1', me: 'lee'),
      OrganizationView(name: 'riverside', keptIn: '', vouchedBy: '', revision: 'r1', me: 'lee'),
    ];
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizations.first));
    await _tap(tester, 'rail organizations');
    expect(find.byKey(const Key('rail organization acme')), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellRail(
            section: Section.organizations,
            running: 0,
            work: 0,
            needing: 0,
            machines: 0,
            projects: 0,
            organizations: organizations,
            foldedOpen: {'organizations'},
            width: 280,
            onGo: (_) {},
            onRefresh: () {},
            onStopEverywhere: null,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('rail organization acme')), findsOneWidget);
    expect(find.byKey(const Key('rail organization riverside')), findsOneWidget);
  });

  // Harm: keyboard users cannot navigate or accidentally change place while unfolding a branch.
  testWidgets('the tree chooses with Enter and its chevron preserves the page', (tester) async {
    await _start(tester);
    await _tap(tester, 'fold machines');
    expect(tester.widget<Text>(find.byKey(const Key('app-title'))).data, 'Work');
    await _tap(tester, 'fold machines');
    await _tap(tester, 'rail machines');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await World.settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('app-title'))).data, World.machines.current.name);
  });

  // Harm: keyboard-only navigation or a restart loses the machine and its tool.
  testWidgets('navigation restores after saved machines load as on application startup', (tester) async {
    await _start(tester);
    const second = Machine(name: 'elsewhere', socketPath: '/unused');
    await World.machines.add(second);
    await World.settings.rememberShellNavigation({
      'section': 'machine',
      'machine': 'elsewhere',
      'machineSection': 'projects',
      'folded': ['machines', 'machine elsewhere'],
    });
    final settings = Settings(World.store);
    await settings.load();
    final shell = ShellModel();
    final machines = Machines(settings, reach: (_) => FakeBackend([]), tunnels: FakeTunnels());
    final restoration = WhereYouWere(settings, machines, shell);
    addTearDown(restoration.dispose);
    addTearDown(machines.dispose);
    addTearDown(settings.dispose);
    addTearDown(shell.dispose);
    await machines.load();
    await restoration.restore();
    expect(shell.place.machine?.name, 'elsewhere');
    expect(shell.place.machineSection, MachineSection.projects);
    expect(machines.current.name, 'elsewhere');
  });

  // Harm: a healthy verdict from the first machine hides the second machine's unknown health.
  testWidgets('a machine facts page never reuses another machine health', (tester) async {
    await _start(tester);
    await _tap(tester, _leafKey('health'));
    await World.settle(tester);
    await World.machines.add(const Machine(name: 'elsewhere', socketPath: '/unused'));
    await World.settle(tester);
    await _tap(tester, _machineKey('elsewhere'));
    expect(find.text('Health: not read — run Check whether this machine can run anything'), findsOneWidget);
  });

  // Harm: a restart loses the selected tool and the folds that make it reachable.
  testWidgets('the chosen place and folds survive a restart', (tester) async {
    await _start(tester);
    await _tap(tester, _leafKey('projects'));
    await World.restartApp(tester);
    expect(find.byKey(ValueKey(_leafKey('projects'))), findsOneWidget);
    expect(World.shell.place.machineSection, MachineSection.projects);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  });
}

class _WaitingCredentials extends FakeBackend {
  _WaitingCredentials() : super([]);
  final reply = Completer<VaultState>();
  @override
  Future<VaultState> credentials() => reply.future;
}
