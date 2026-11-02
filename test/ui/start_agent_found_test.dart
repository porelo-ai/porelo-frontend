import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/start_work.dart';
import 'package:porelo_frontend/src/ui/start_work_view.dart';

import '../features/support/world.dart';

const _path = '/home/person/.agent/auth.json';

Future<StartWork> _open(
  WidgetTester tester,
  Readiness answer, {
  List<Map<String, dynamic>>? agents,
  Future<void> Function()? onImport,
  Future<void> Function()? onStore,
  Future<void> Function(Agent agent)? onLogIn,
}) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final machine = FakeBackend(const <Task>[])..nextReadiness = answer;
  if (agents != null) machine.theAgentsItHas = agents.map(Agent.from).toList();
  final starting = StartWork();
  addTearDown(starting.dispose);
  await starting.open(machine, machine.theProjectsItHas.first);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StartWorkDialog(
          starting: starting,
          onStart: () {},
          onKeep: () {},
          onImportTheSignIn: onImport,
          onStoreTheCredential: onStore,
          onLogIn: onLogIn,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return starting;
}

Readiness _chosen(String source) => Readiness(
  ready: true,
  outcome: StartOutcome.ready,
  agent: 'an-agent',
  provider: 'a-provider',
  credential: 'a-provider',
  detail: '',
  agentSource: source,
  agentFoundIn: _path,
);

const _missing = Readiness(
  ready: false,
  outcome: StartOutcome.credentialMissing,
  agent: 'an-agent',
  provider: 'a-provider',
  credential: 'a-provider',
  detail: '',
  agentSource: 'SIGNED_IN',
  agentFoundIn: _path,
  importCommand: <String>['porelo', 'vault', 'import', 'an-agent'],
  storeCommand: <String>['porelo', 'vault', 'put', 'a-provider'],
);

Text _said(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('start-machine-chose')));

void main() {
  testWidgets('the form says which agent the machine chose, and where it found it', (tester) async {
    // Harm: work runs with an agent nobody saw named, on a sign-in nobody knows the place of.
    await _open(tester, _chosen('SIGNED_IN'));
    expect(_said(tester).data, allOf(contains('An Agent'), contains(_path), contains('a-provider')));
  });

  testWidgets('a source this build does not know is said as it comes', (tester) async {
    // Harm: a newer machine's reason dropped or read as one of the known ones.
    await _open(tester, _chosen('A_NEWER_REASON'));
    expect(_said(tester).data, contains('A_NEWER_REASON'));
  });

  testWidgets('a person who picked an agent is not told the machine chose', (tester) async {
    // Harm: the form names the machine's choice beside another agent that will really run.
    final starting = await _open(tester, _chosen('FLAG'));
    starting.chooseAgent('an-agent');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-machine-chose')), findsNothing);
  });

  testWidgets('the picker marks each agent, signed in first, and cannot say never reads as signed out', (tester) async {
    // Harm: a person signs in again, or gives up on an agent, because it could only not be asked.
    await _open(
      tester,
      const Readiness(
        ready: false,
        outcome: StartOutcome.severalAgents,
        agent: '',
        provider: '',
        credential: '',
        detail: '',
      ),
      agents: <Map<String, dynamic>>[
        <String, dynamic>{'name': 'asks-nobody', 'label': 'Asks Nobody', 'found': 'CANNOT_SAY'},
        <String, dynamic>{'name': 'out', 'label': 'Out', 'found': 'NOT_SIGNED_IN'},
        <String, dynamic>{
          'name': 'in',
          'label': 'In',
          'found': 'SIGNED_IN',
          'foundProvider': 'a-provider',
          'foundPaths': <String>[_path],
        },
      ],
    );
    await tester.tap(find.byKey(const Key('start-agent')));
    await tester.pumpAndSettle();

    String words(String name) => tester
        .widgetList<Text>(
          find.descendant(of: find.byKey(ValueKey<String>('start-agent-choice $name')), matching: find.byType(Text)),
        )
        .map((each) => each.data)
        .join(' ');
    expect(words('in'), allOf(contains('a-provider'), contains(_path)));
    expect(words('out'), contains('not signed in'));
    expect(words('asks-nobody'), isNot(contains('not signed in')));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('start-agent-choice in'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey<String>('start-agent-choice asks-nobody'))).dy),
    );
  });

  testWidgets('with no sign-in to run, the import is offered before storing a key', (tester) async {
    // Harm: a person retypes a key the machine could have copied, or never learns it could.
    var imported = 0;
    await _open(tester, _missing, onImport: () async => imported++, onStore: () async {});
    final import = find.byKey(const Key('start-import'));
    expect(import, findsOneWidget);
    expect(
      tester.getTopLeft(import).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byKey(const Key('store-the-credential'))).dy),
    );
    await tester.tap(import);
    await tester.pumpAndSettle();
    expect(imported, 1);
  });

  testWidgets('an agent that can sign in offers the import as well', (tester) async {
    // Harm: the sign-in box hides the one way that needs no new sign-in.
    var imported = 0;
    await _open(
      tester,
      _missing,
      agents: <Map<String, dynamic>>[
        <String, dynamic>{'name': 'an-agent', 'label': 'An Agent', 'canLogIn': true},
      ],
      onImport: () async => imported++,
      onLogIn: (_) async {},
    );
    await tester.tap(find.byKey(const Key('start-import')));
    await tester.pumpAndSettle();
    expect(imported, 1);
  });

  testWidgets('nothing composes an import the machine did not name', (tester) async {
    // Harm: an offer of a command the machine knows cannot take this route.
    await _open(
      tester,
      const Readiness(
        ready: false,
        outcome: StartOutcome.credentialMissing,
        agent: 'an-agent',
        provider: 'a-provider',
        credential: 'a-provider',
        detail: '',
        agentSource: 'ONLY_ONE',
      ),
      onImport: () async {},
      onStore: () async {},
    );
    expect(find.byKey(const Key('start-import')), findsNothing);
  });
}
