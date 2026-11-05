import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/logs.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/session.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/running_view.dart';
import 'package:porelo_frontend/src/ui/work_page.dart';

import '../features/support/world.dart';

void main() {
  final began = DateTime.utc(2000);

  Future<FakeBackend> prepare(
    WidgetTester tester, {
    required DateTime Function() clock,
    required String? deadline,
    VoidCallback? onAnswer,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend([
      Task.from({'name': 'work', 'project': 'demo', 'running': true, 'mode': 'UNATTENDED', 'activity': 'WORKING'}),
    ]);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => backend, tunnels: FakeTunnels());
    await machines.of(machines.current).untilAsked();
    final attention = Attention(machines, settings, null, clock);
    final view = WorkView();
    final sessions = Sessions();
    final logs = Logs();
    final focus = FocusNode();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      focus.dispose();
      logs.dispose();
      sessions.dispose();
      view.dispose();
      attention.dispose();
      machines.dispose();
      settings.dispose();
      await backend.stop();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunningView(
            machines: machines,
            attention: attention,
            view: view,
            sessions: sessions,
            logs: logs,
            focusNode: focus,
            onAnswer: onAnswer ?? () {},
            onReadLog: (_) {},
          ),
        ),
      ),
    );
    backend.asking.add(World.blocked('api.example.test:443', task: 'work', deadline: deadline));
    await World.settle(tester);
    return backend;
  }

  Finder noteSaying(String words) =>
      find.descendant(of: find.byKey(const Key('running-note')), matching: find.textContaining(words));

  // Harm: a stale countdown overstates the time available to answer a blocked connection.
  testWidgets('the running note counts down and expires without a daemon update', (tester) async {
    var now = began;
    var answersOpened = 0;
    final backend = await prepare(
      tester,
      clock: () => now,
      deadline: began.add(const Duration(minutes: 2)).toIso8601String(),
      onAnswer: () => answersOpened++,
    );
    expect(noteSaying('2 minutes left'), findsOneWidget);
    now = now.add(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 15));
    expect(noteSaying('1 minute left'), findsOneWidget);
    now = began.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 15));
    expect(noteSaying('out of time'), findsOneWidget);
    expect(noteSaying('left'), findsNothing);
    expect(backend.decisions, isEmpty, reason: 'time passing must never decide a question here');
    await tester.tap(find.byKey(const Key('running-answer')));
    expect(answersOpened, 1, reason: 'the note must still lead to the question and its outcome');
  });

  // Harm: an unknown deadline can be mistaken for unlimited time, delaying an answer until it is lost.
  for (final deadline in <String?>[null, 'not-an-instant']) {
    testWidgets('the running note admits an unknown deadline: $deadline', (tester) async {
      await prepare(tester, clock: () => began, deadline: deadline);
      expect(noteSaying('does not say when'), findsOneWidget);
      expect(noteSaying('left'), findsNothing);
      expect(noteSaying('does not run out'), findsNothing);
    });
  }

  // Harm: inventing a timeout for an unlimited question misstates the urgency of a decision.
  testWidgets('the running note preserves an explicitly unlimited question', (tester) async {
    await prepare(tester, clock: () => began, deadline: '');
    expect(noteSaying('does not run out'), findsOneWidget);
    expect(noteSaying('left'), findsNothing);
    expect(noteSaying('out of time'), findsNothing);
  });

  // Harm: a repeated prompt must not restart its countdown or make an expired decision seem timely.
  testWidgets('a repeated question keeps the deadline and a settled one removes the note', (tester) async {
    var now = began;
    final deadline = began.add(const Duration(seconds: 30)).toIso8601String();
    final backend = await prepare(tester, clock: () => now, deadline: deadline);
    expect(noteSaying('less than a minute left'), findsOneWidget);
    now = began.add(const Duration(minutes: 1));
    final question = World.blocked('api.example.test:443', task: 'work', deadline: deadline);
    backend.asking.add(question);
    await World.settle(tester);
    expect(noteSaying('out of time'), findsOneWidget);
    backend.asking.add(World.settled(question, 'deny'));
    await World.settle(tester);
    expect(find.byKey(const Key('running-note')), findsNothing);
    expect(backend.decisions, isEmpty, reason: 'only a person decides here');
    // What the settled question's expiry had set going.
    now = now.add(const Duration(hours: 2));
    await tester.pump(const Duration(hours: 1, minutes: 1));
  });
}
