import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/start_work.dart';
import 'package:porelo_frontend/src/app/work_held.dart';
import 'package:porelo_frontend/src/ui/panes.dart';
import 'package:porelo_frontend/src/ui/start_work_view.dart';

import '../features/support/world.dart';

const _missing = MissingCredential(
  purpose: 'builds',
  credential: 'forge.person',
  storeCommand: <String>['porelo', 'host', 'forge-token'],
  afterStore: 'ask-again',
);

const _ready = Readiness(
  ready: true,
  outcome: StartOutcome.ready,
  agent: 'an-agent',
  provider: 'a-provider',
  credential: 'a-provider',
  detail: '',
  missing: <MissingCredential>[_missing],
);

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<StartWork> _start(
  WidgetTester tester,
  Readiness answer, {
  Future<void> Function(MissingCredential missing)? onStoreTheMissing,
}) async {
  _size(tester);
  final machine = FakeBackend(const <Task>[])..nextReadiness = answer;
  final starting = StartWork();
  addTearDown(starting.dispose);
  await starting.open(machine, machine.theProjectsItHas.first);
  starting.chooseAgent('an-agent');
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StartWorkDialog(
          starting: starting,
          onStart: () {},
          onKeep: () {},
          machine: 'build',
          onStoreTheMissing: onStoreTheMissing,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return starting;
}

Task _task({MissingCredential? waitingFor}) => Task.from(<String, dynamic>{
  'name': 'porelo-checkout-fix',
  'project': 'checkout',
  'buildReader': 'host-forge',
  'buildProblem': 'your vault does not hold forge.person; run porelo host forge-token on this host',
  if (waitingFor != null)
    'buildsCredential': <String, dynamic>{
      'for': waitingFor.purpose,
      'credential': waitingFor.credential,
      'storeCommand': waitingFor.storeCommand,
      'afterStore': waitingFor.afterStore,
    },
});

Future<void> _detail(
  WidgetTester tester,
  Task task, {
  Future<bool> Function(MissingCredential missing)? onStore,
}) async {
  _size(tester);
  final held = WorkHeld();
  addTearDown(held.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorkDetail(task: task, held: held, onClose: () {}, machine: 'build', onStoreTheBuildsCredential: onStore),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Harm: work held back over a token only its builds need, or the host's ask never seen.
  testWidgets('a start names what the host lacks beside it, and is not held back', (tester) async {
    await _start(tester, _ready, onStoreTheMissing: (_) async {});
    final box = find.byKey(const ValueKey<String>('missing-credential forge.person'));
    expect(box, findsOneWidget);
    expect(find.descendant(of: box, matching: find.textContaining("build's vault holds no forge.person")), findsOne);
    expect(tester.widget<FilledButton>(find.byKey(const Key('start-go'))).onPressed, isNotNull);
  });

  // Harm: the host's command run for another entry than the one the machine named.
  testWidgets('its press hands the entry the machine named to be stored on the host', (tester) async {
    final stored = <MissingCredential>[];
    await _start(tester, _ready, onStoreTheMissing: (missing) async => stored.add(missing));
    final press = find.byKey(const ValueKey<String>('store-missing forge.person'));
    await tester.ensureVisible(press);
    await tester.pumpAndSettle();
    await tester.tap(press);
    await tester.pumpAndSettle();
    expect(stored, <MissingCredential>[_missing]);
  });

  // Harm: a press that would run the host's command where this window does not reach the host itself.
  testWidgets('where the window does not reach the host itself, nothing is offered to run', (tester) async {
    await _start(tester, _ready);
    expect(find.byKey(const ValueKey<String>('missing-credential forge.person')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('store-missing forge.person')), findsNothing);
    expect(find.text('porelo host forge-token'), findsOneWidget, reason: 'shown to run there by hand');
  });

  // Harm: a person believes the running task follows its builds once the token is stored.
  testWidgets("a task's builds offer the host's command, and say only its next start follows them", (tester) async {
    final stored = <MissingCredential>[];
    const waiting = MissingCredential(
      purpose: 'builds',
      credential: 'forge.person',
      storeCommand: <String>['porelo', 'host', 'forge-token'],
      afterStore: 'restart',
    );
    await _detail(
      tester,
      _task(waitingFor: waiting),
      onStore: (missing) async {
        stored.add(missing);
        return true;
      },
    );
    expect(find.textContaining('your vault does not hold forge.person'), findsOneWidget);
    expect(find.byKey(const Key('builds-credential-stored')), findsNothing);
    await tester.tap(find.byKey(const Key('store-builds-credential')));
    await tester.pumpAndSettle();
    expect(stored.single.credential, 'forge.person');
    expect(
      tester.widget<Text>(find.byKey(const Key('builds-credential-stored'))).data,
      contains('only from its next start'),
    );
  });

  // Harm: a command that failed on the host read as a stored token.
  testWidgets('a command that did not end well claims nothing stored', (tester) async {
    await _detail(
      tester,
      _task(
        waitingFor: const MissingCredential(
          purpose: 'builds',
          credential: 'forge.person',
          storeCommand: ['porelo'],
          afterStore: 'restart',
        ),
      ),
      onStore: (_) async => false,
    );
    await tester.tap(find.byKey(const Key('store-builds-credential')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('builds-credential-stored'))).data, isNot(contains('next start')));
  });

  // Harm: a button that runs a command a task from an older daemon never named, read out of its sentence.
  testWidgets('a task with only the sentence offers no command', (tester) async {
    await _detail(tester, _task(), onStore: (_) async => true);
    expect(find.textContaining('your vault does not hold forge.person'), findsOneWidget);
    expect(find.byKey(const Key('builds-credential')), findsNothing);
  });
}
