import 'dart:async';

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

Task _task({MissingCredential? waitingFor, String name = 'porelo-checkout-fix'}) => Task.from(<String, dynamic>{
  'name': name,
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
  String machine = 'build',
  WorkHeld? held,
}) async {
  _size(tester);
  final shown = held ?? WorkHeld();
  if (held == null) addTearDown(shown.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorkDetail(
          task: task,
          held: shown,
          onClose: () {},
          machine: machine,
          onStoreTheBuildsCredential: onStore,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _restart = MissingCredential(
  purpose: 'builds',
  credential: 'forge.person',
  storeCommand: <String>['porelo', 'host', 'forge-token'],
  afterStore: 'restart',
);

void main() {
  // Harm: work held back over a token only its builds need, or the host's ask never seen.
  testWidgets('a start names what the host lacks beside it, and is not held back', (tester) async {
    await _start(tester, _ready, onStoreTheMissing: (_) async {});
    final box = find.byKey(const ValueKey<String>('missing-credential builds forge.person'));
    expect(box, findsOneWidget);
    expect(find.descendant(of: box, matching: find.textContaining("build's vault holds no forge.person")), findsOne);
    expect(tester.widget<FilledButton>(find.byKey(const Key('start-go'))).onPressed, isNotNull);
  });

  // Harm: the host's command run for another entry than the one the machine named.
  testWidgets('its press hands the entry the machine named to be stored on the host', (tester) async {
    final stored = <MissingCredential>[];
    await _start(tester, _ready, onStoreTheMissing: (missing) async => stored.add(missing));
    final press = find.byKey(const ValueKey<String>('store-missing builds forge.person'));
    await tester.ensureVisible(press);
    await tester.pumpAndSettle();
    await tester.tap(press);
    await tester.pumpAndSettle();
    expect(stored, <MissingCredential>[_missing]);
  });

  // Harm: a press that would run the host's command where this window does not reach the host itself.
  testWidgets('where the window does not reach the host itself, nothing is offered to run', (tester) async {
    await _start(tester, _ready);
    expect(find.byKey(const ValueKey<String>('missing-credential builds forge.person')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('store-missing builds forge.person')), findsNothing);
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
    final said = tester.widget<Text>(find.byKey(const Key('builds-credential-stored'))).data;
    expect(said, isNot(contains('next start')));
    expect(said, contains('did not end without an error'));
  });

  // Harm: a task or machine opened next reads as stored, or waits on, a command that ran for another one.
  testWidgets("what the command did for one task is never said of the next one opened", (tester) async {
    final held = WorkHeld();
    addTearDown(held.dispose);
    await _detail(
      tester,
      _task(waitingFor: _restart),
      held: held,
      onStore: (_) async => true,
    );
    await tester.tap(find.byKey(const Key('store-builds-credential')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('builds-credential-stored')), findsOneWidget);
    await _detail(
      tester,
      _task(waitingFor: _restart, name: 'porelo-checkout-other'),
      held: held,
      onStore: (_) async => true,
    );
    expect(find.byKey(const Key('builds-credential-stored')), findsNothing, reason: 'another task');
    await _detail(
      tester,
      _task(waitingFor: _restart, name: 'porelo-checkout-other'),
      held: held,
      machine: 'other',
    );
    expect(find.byKey(const Key('builds-credential-stored')), findsNothing, reason: 'another machine');
  });

  testWidgets('a command still running for one task neither holds nor answers the next one', (tester) async {
    final held = WorkHeld();
    addTearDown(held.dispose);
    final first = Completer<bool>();
    await _detail(
      tester,
      _task(waitingFor: _restart),
      held: held,
      onStore: (_) => first.future,
    );
    await tester.tap(find.byKey(const Key('store-builds-credential')));
    await tester.pump();
    await _detail(
      tester,
      _task(waitingFor: _restart, name: 'porelo-checkout-other'),
      held: held,
      onStore: (_) async => true,
    );
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('store-builds-credential'))).onPressed, isNotNull);
    first.complete(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('builds-credential-stored')), findsNothing);
  });

  // Harm: a person who runs the command by hand is never told the running task needs a new start.
  testWidgets('where the command is run by hand, the task says only its next start follows its builds', (tester) async {
    await _detail(tester, _task(waitingFor: _restart));
    expect(find.byKey(const Key('store-builds-credential')), findsNothing);
    expect(find.textContaining('next start'), findsOneWidget);
  });

  // Harm: a remedy the machine names dropped where this window does not do it itself.
  testWidgets('a start says what the machine names for after the store, where it is no ask again', (tester) async {
    await _start(
      tester,
      const Readiness(
        ready: true,
        outcome: StartOutcome.ready,
        agent: 'an-agent',
        provider: 'a-provider',
        credential: 'a-provider',
        detail: '',
        missing: <MissingCredential>[_restart],
      ),
      onStoreTheMissing: (_) async {},
    );
    expect(find.textContaining('next start'), findsOneWidget);
  });

  // Harm: two entries under one key throw, and the start's form shows nothing at all.
  testWidgets('entries that share a vault key are each shown, and the same one once', (tester) async {
    await _start(
      tester,
      const Readiness(
        ready: true,
        outcome: StartOutcome.ready,
        agent: 'an-agent',
        provider: 'a-provider',
        credential: 'a-provider',
        detail: '',
        missing: <MissingCredential>[
          _missing,
          _missing,
          MissingCredential(purpose: 'mirrors', credential: 'forge.person', afterStore: 'ask-again'),
        ],
      ),
      onStoreTheMissing: (_) async {},
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('holds no forge.person'), findsNWidgets(2));
  });

  // Harm: a button that runs a command a task from an older daemon never named, read out of its sentence.
  testWidgets('a task with only the sentence offers no command', (tester) async {
    await _detail(tester, _task(), onStore: (_) async => true);
    expect(find.textContaining('your vault does not hold forge.person'), findsOneWidget);
    expect(find.byKey(const Key('builds-credential')), findsNothing);
  });
}
