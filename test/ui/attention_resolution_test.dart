import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';

import '../features/support/world.dart';

void main() {
  Project waiting(String waitsOn) => Project.from({
    'name': 'demo',
    'messages': {'waits': 'A sentence that does not mention a vault', 'waitsOn': waitsOn},
  });

  Future<({Machines machines, Attention attention, Map<String, FakeBackend> backends, Future<void> Function() dispose})>
  prepare(
    WidgetTester tester, {
    String waitsOn = 'vault',
    int minutes = 60,
    DateTime Function()? clock,
    List<String>? unlocked,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = Settings(MemorySettingsStore());
    await settings.setKeepResolvedMinutes(minutes);
    final backends = <String, FakeBackend>{};
    final machines = Machines(
      settings,
      reach: (machine) => backends.putIfAbsent(
        machine.name,
        () => FakeBackend([])
          ..nodeId = machine.name
          ..theProjectsItHas = [waiting(waitsOn)],
      ),
      tunnels: FakeTunnels(),
    );
    await machines.of(machines.current).untilAsked();
    await machines.add(const Machine(name: 'other', socketPath: '/tmp/other.sock'));
    await machines.of(machines.all.last).untilAsked();
    final attention = Attention(machines, settings, null, clock);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttentionView(
            attention: attention,
            onDecide: (_, _, {required allow}) {},
            onReview: (_) {},
            actionsFor: (_) => [],
            unlockFor: (machine) =>
                () => unlocked?.add(machine.name),
          ),
        ),
      ),
    );
    await World.settle(tester);
    var disposed = false;
    Future<void> dispose() async {
      if (disposed) return;
      disposed = true;
      try {
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        attention.dispose();
        machines.dispose();
        settings.dispose();
      }
    }

    addTearDown(dispose);
    return (machines: machines, attention: attention, backends: backends, dispose: dispose);
  }

  // Harm: unlocking another machine leaves the blocked conversation unresolved and exposes the wrong vault.
  testWidgets('each waiting row unlocks only its own machine', (tester) async {
    final unlocked = <String>[];
    final state = await prepare(tester, unlocked: unlocked);
    try {
      for (final machine in state.machines.all) {
        final row = find.byKey(ValueKey('messages-wait ${machine.name}'));
        expect(
          tester.widget<Text>(find.descendant(of: row, matching: find.byKey(const Key('needs-machine')))).data,
          'on ${machine.name}',
        );
        final button = find.descendant(
          of: row,
          matching: find.widgetWithText(TextButton, 'Unlock the vault on ${machine.name}'),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        expect(unlocked, [machine.name]);
        unlocked.clear();
      }
    } finally {
      await state.dispose();
    }
  });

  // Harm: guessing from a sentence can send a person to unlock a vault that is not blocking messages.
  testWidgets('missing and unknown wait reasons never offer unlock', (tester) async {
    final state = await prepare(tester, waitsOn: '');
    try {
      expect(find.textContaining('Unlock the vault on'), findsNothing);
      for (final machine in state.machines.all) {
        state.backends[machine.name]!.theProjectsItHas = [waiting('future-reason')];
        await state.machines.of(machine).refresh();
      }
      await World.settle(tester);
      expect(find.textContaining('Unlock the vault on'), findsNothing);
    } finally {
      await state.dispose();
    }
  });

  // Harm: a resolved question can vanish without a trace, or remain actionable after it was resolved.
  testWidgets('resolved rows disable actions and expire on the supplied clock', (tester) async {
    var now = DateTime.utc(2000);
    final state = await prepare(tester, minutes: 2, clock: () => now);
    try {
      final machine = state.machines.current;
      state.backends[machine.name]!.theProjectsItHas = [];
      await state.machines.of(machine).refresh();
      await World.settle(tester);
      expect(find.text('Recently resolved'), findsOneWidget);
      final resolved = find.byKey(const Key('recently-resolved'));
      expect(find.descendant(of: resolved, matching: find.text('on ${machine.name}')), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.descendant(of: resolved, matching: find.byType(TextButton))).onPressed,
        isNull,
      );
      now = now.add(const Duration(minutes: 1, seconds: 59));
      await tester.pump(const Duration(minutes: 1, seconds: 59));
      expect(find.byKey(const Key('recently-resolved')), findsOneWidget);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('recently-resolved')), findsNothing);
    } finally {
      await state.dispose();
    }
  });

  // Harm: retaining resolved rows despite zero ignores the choice to remove their contents immediately.
  testWidgets('zero retention removes a resolved row immediately', (tester) async {
    final state = await prepare(tester, minutes: 0);
    try {
      final machine = state.machines.current;
      state.backends[machine.name]!.theProjectsItHas = [];
      await state.machines.of(machine).refresh();
      await World.settle(tester);
      expect(find.byKey(ValueKey('messages-wait ${machine.name}')), findsNothing);
      expect(find.text('Recently resolved'), findsNothing);
    } finally {
      await state.dispose();
    }
  });

  // Harm: a row that reopens must offer a fresh decision rather than stay disabled as resolved.
  testWidgets('a returning condition leaves the resolved list', (tester) async {
    final state = await prepare(tester);
    try {
      final machine = state.machines.current;
      final backend = state.backends[machine.name]!;
      backend.theProjectsItHas = [];
      await state.machines.of(machine).refresh();
      await World.settle(tester);
      expect(find.text('Recently resolved'), findsOneWidget);
      backend.theProjectsItHas = [waiting('vault')];
      await state.machines.of(machine).refresh();
      await World.settle(tester);
      expect(find.text('Recently resolved'), findsNothing);
      expect(find.byKey(ValueKey('messages-wait ${machine.name}')), findsOneWidget);
    } finally {
      await state.dispose();
    }
  });

  // Harm: a message read by a person must leave a readable trace without offering its decision twice.
  testWidgets('an explicit read moves a message to recently resolved and keeps its text openable', (tester) async {
    final state = await prepare(tester, waitsOn: '');
    try {
      final machine = state.machines.current;
      final backend = state.backends[machine.name]!;
      final message = HeldMessage.from({
        'task': 'alpha',
        'message': 'held.json',
        'standing': 'held',
        'direction': 'out',
      });
      backend.heldForAPerson.add(message);
      backend.readable[message.handle] = HeldMessageRead.from({
        'outcome': 'FOUND',
        'message': message.handle,
        'standing': 'held',
        'text': ['Please review this work.'],
      });
      await state.machines.of(machine).mailboxes.refresh();
      await World.settle(tester);
      expect(find.text('Recently resolved'), findsNothing, reason: 'a preview is not an explicit read');
      final read = find.byKey(const ValueKey('read-message alpha/held.json'));
      await tester.ensureVisible(read);
      await tester.tap(read);
      await World.settle(tester);
      expect(find.byKey(const Key('held-message-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('held-message-close')));
      await World.settle(tester);
      final resolved = find.byKey(const Key('recently-resolved'));
      expect(resolved, findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('open-attention')), matching: read), findsNothing);
      expect(tester.widget<OutlinedButton>(find.descendant(of: resolved, matching: read)).onPressed, isNull);
      final row = find.descendant(
        of: resolved,
        matching: find.byKey(ValueKey('held-message ${machine.name}/alpha/held.json')),
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await World.settle(tester);
      expect(find.text('Please review this work.'), findsWidgets);
      expect(find.byKey(const Key('release-message')), findsNothing);
      expect(find.byKey(const Key('refuse-message')), findsNothing);
      expect(backend.released, isEmpty);
    } finally {
      await state.dispose();
    }
  });
}
