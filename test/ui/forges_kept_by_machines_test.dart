import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/app/forge_records.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/forges_page.dart';
import 'package:porelo_frontend/src/ui/shell_rail.dart';

import '../features/support/world.dart';

const _github = ForgeEntry(id: 'github.com', kind: 'github', name: 'GitHub', address: 'github.com');

class _Keeps implements KnowsForges {
  _Keeps(this.kept, {this.older = false, this.refusal, this.neverAnswers = false});
  final List<ForgeInstance> kept;
  final bool older, neverAnswers;
  final VarlinkException? refusal;

  @override
  Future<MachineForges> forges() async {
    if (neverAnswers) throw const VarlinkDisconnected('the tunnel is down');
    if (older) throw const FeatureNotSupported('Forges');
    if (refusal case final refused?) throw refused;
    return MachineForges(forges: kept, adapters: const ['github']);
  }

  @override
  Future<void> forgeSet(String host, String adapter, {String? comments}) async {}
}

void main() {
  late ForgeConnection forges;
  late Map<String, KnowsForges> machines;
  late ForgeRecords records;

  final stored = MemoryForgeEntries();

  setUp(() async {
    await stored.write(const []);
    forges = ForgeConnection(MemoryForgeTokens(), entries: stored)..loaded = true;
    machines = {};
    records = ForgeRecords(
      forges: forges,
      machines: () => [for (final MapEntry(:key, :value) in machines.entries) (name: key, backend: value)],
    );
    addTearDown(forges.dispose);
    addTearDown(records.dispose);
  });

  Future<void> show(
    WidgetTester tester, {
    required double width,
    List<Connection> held = const <Connection>[],
    List<String> watched = const ['a-machine-with-a-long-name', 'older', 'refused', 'silent', 'unasked'],
  }) async {
    tester.view
      ..physicalSize = Size(width, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    records.look();
    await tester.runAsync(pumpEventQueue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgesPage(
            forges: forges,
            usedBy: (_) => [],
            onOpen: (_) {},
            kept: records,
            held: held,
            watched: watched,
          ),
        ),
      ),
    );
    await World.settle(tester);
  }

  // Harm: a person sets up a forge again that a machine already keeps, or takes "0 forges" for none where a machine
  // was not read, refused, or is older.
  testWidgets('a machine\'s forge is listed as kept by it, and a machine not read is never listed as none', (
    tester,
  ) async {
    machines = {
      'a-machine-with-a-long-name': _Keeps(const [
        ForgeInstance(host: 'forge.example.org', adapter: 'github', comments: 'TRUSTED'),
      ]),
      'older': _Keeps(const [], older: true),
      'refused': _Keeps(const [], refusal: VarlinkException('x.ForgeFileUnreadable', {'reason': 'permission denied'})),
      'silent': _Keeps(const [], neverAnswers: true),
    };
    await show(tester, width: 1280);

    final row = find.byKey(const ValueKey('forges-row kept forge.example.org'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('kept by a-machine-with-a-long-name')), findsWidgets);
    expect(find.descendant(of: row, matching: find.textContaining('comments trusted')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('github')), findsWidgets);
    expect(find.descendant(of: row, matching: find.byType(PopupMenuButton)), findsNothing);
    expect(find.textContaining('cannot list its forges'), findsWidgets);
    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(find.textContaining('was not reached'), findsOneWidget);
    expect(find.byKey(const ValueKey('forges-row machine unasked')), findsOneWidget);
    expect(find.text('not read yet'), findsNWidgets(2), reason: 'the machine never asked and the silent one say so');
    expect(find.text('0 forges'), findsNothing, reason: 'the head names its 0 as the window\'s own');
    expect(find.text('0 forges set up here · 1 more kept by machines · 4 machines not read'), findsOneWidget);
  });

  // Harm: a host both here and on a machine is listed twice, or one of the two marks is lost.
  testWidgets('a host this window also sets up shows once, with both marks', (tester) async {
    await stored.write([_github.toJson()]);
    await forges.readList();
    machines = {
      'a-machine-with-a-long-name': _Keeps(const [ForgeInstance(host: 'github.com', adapter: 'github')]),
    };
    await show(tester, width: 1280);

    expect(find.byKey(const ValueKey('forges-row github.com')), findsOneWidget);
    expect(find.byKey(const ValueKey('forges-row kept github.com')), findsNothing);
    // Only a forge's own row is keyed as a forge: a machine's row taken for one would be opened as it.
    final forgeRows = find.byWidgetPredicate((widget) => '${widget.key}'.startsWith("[<'forge ") && widget is ListTile);
    expect(forgeRows, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('forges-row github.com')),
        matching: find.textContaining('set up here and kept by a-machine-with-a-long-name: github, comments extended'),
      ),
      findsOneWidget,
    );
  });

  // Harm: a long machine name and a host are cut off on a phone, so the person cannot tell which machine keeps what.
  testWidgets('at 390 wide the machine and the host stay whole', (tester) async {
    machines = {
      'a-machine-with-a-long-name': _Keeps(const [
        ForgeInstance(host: 'forge.example.org', adapter: 'github', comments: 'TRUSTED'),
      ]),
    };
    await show(tester, width: 390);

    expect(tester.takeException(), isNull);
    final row = find.byKey(const ValueKey('forges-row kept forge.example.org'));
    expect(find.descendant(of: row, matching: find.text('forge.example.org')), findsOneWidget);
    final words = find.descendant(
      of: row,
      matching: find.textContaining('kept by a-machine-with-a-long-name: github, comments trusted'),
    );
    expect(words, findsOneWidget);
    final text = tester.widget<Text>(words);
    expect(text.maxLines, isNull);
  });

  // Harm: a forge a machine declares a credential for and also keeps is listed twice and counted twice, or is called
  // set up here though only the machine holds it.
  testWidgets('a forge listed only through a machine\'s declared connection and also kept shows once', (tester) async {
    machines = {
      'a-machine-with-a-long-name': _Keeps(const [ForgeInstance(host: 'github.com', adapter: 'github')]),
    };
    await show(
      tester,
      width: 1280,
      watched: const ['a-machine-with-a-long-name'],
      held: const [
        Connection(
          id: 'git.token.github.com',
          kind: 'TOKEN',
          match: 'https://github.com/porelo-ai/',
          purpose: 'git',
          source: 'VAULT',
          present: true,
        ),
      ],
    );

    expect(find.byKey(const ValueKey('forges-row held github.com')), findsOneWidget);
    expect(find.byKey(const ValueKey('forges-row kept github.com')), findsNothing);
    final row = find.byKey(const ValueKey('forges-row held github.com'));
    expect(
      find.descendant(of: row, matching: find.textContaining('kept by a-machine-with-a-long-name')),
      findsOneWidget,
    );
    expect(find.descendant(of: row, matching: find.textContaining('set up here')), findsNothing);
    expect(find.text('1 forge'), findsOneWidget, reason: 'one host is one forge in the count');
  });

  // Harm: at 390 wide a long host or machine name is cut to one line in a title and appears nowhere else.
  testWidgets('at 390 wide a long host and a long machine name stand whole in the subtitle', (tester) async {
    const host = 'git.eu-central.production.example.org';
    const name = 'a-machine-with-a-long-name';
    machines = {
      name: _Keeps(const [ForgeInstance(host: host, adapter: 'github')]),
      'older': _Keeps(const [], older: true),
    };
    await show(tester, width: 390, watched: const [name, 'older']);

    final kept = find.byKey(const ValueKey('forges-row kept $host'));
    final words = find.descendant(of: kept, matching: find.textContaining('$host · kept by $name'));
    expect(words, findsOneWidget);
    expect(tester.widget<Text>(words).maxLines, isNull);
    final older = find.descendant(
      of: find.byKey(const ValueKey('forges-row machine older')),
      matching: find.textContaining('older cannot list its forges'),
    );
    expect(older, findsOneWidget);
    expect(tester.widget<Text>(older).maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  // Harm: the side bar claims 0 forges while machines keep some, or adds them into the window's own count.
  testWidgets('the side bar counts the window\'s own forges and the machines\' apart', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> rail({required int? machineForges}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellRail(
            section: Section.forges,
            running: 0,
            work: 0,
            needing: 0,
            machines: 0,
            projects: 0,
            forges: 0,
            machineForges: machineForges,
            width: 280,
            onGo: (_) {},
            onRefresh: () {},
            onStopEverywhere: null,
          ),
        ),
      ),
    );

    await rail(machineForges: 2);
    expect(tester.widget<Text>(find.byKey(const Key('rail-forges-count'))).data, '0');
    expect(tester.widget<Text>(find.byKey(const Key('rail-forges-count-machines'))).data, contains('+2'));

    await rail(machineForges: 0);
    expect(find.byKey(const Key('rail-forges-count-machines')), findsNothing);
  });
}
