import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';

import '../features/support/world.dart';
import '../support/expand_list_rows.dart';

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
      await expandListRows(tester);
      for (final machine in state.machines.all) {
        final row = find.byKey(ValueKey('messages-wait ${machine.name}'));
        expect(
          tester.widget<Text>(find.descendant(of: row, matching: find.byKey(const Key('needs-machine')))).data,
          'on ${machine.name}',
          reason: 'the recovery action must name the machine whose vault is blocked',
        );
        final button = find.descendant(
          of: row,
          matching: find.widgetWithText(TextButton, 'Unlock the vault on ${machine.name}'),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        expect(unlocked, [machine.name], reason: 'unlock must reach only the machine on this row');
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
      expect(
        find.textContaining('Unlock the vault on'),
        findsNothing,
        reason: 'only an explicit vault wait reason permits unlocking',
      );
      for (final machine in state.machines.all) {
        state.backends[machine.name]!.theProjectsItHas = [waiting('future-reason')];
        await state.machines.of(machine).refresh();
      }
      await World.settle(tester);
      expect(
        find.textContaining('Unlock the vault on'),
        findsNothing,
        reason: 'only an explicit vault wait reason permits unlocking',
      );
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
      expect(
        find.text('Recently resolved'),
        findsOneWidget,
        reason: 'resolved conditions must retain a readable trace',
      );
      await expandListRows(tester, within: find.byKey(const Key('recently-resolved')));
      final resolved = find.byKey(const Key('recently-resolved'));
      expect(
        find.descendant(of: resolved, matching: find.text('on ${machine.name}')),
        findsOneWidget,
        reason: 'the retained condition must still identify its machine',
      );
      final buttons = tester
          .widgetList<TextButton>(find.descendant(of: resolved, matching: find.byType(TextButton)))
          .toList();
      expect(buttons, hasLength(2), reason: 'the resolved details must retain unlock and its held project action');
      for (final button in buttons) {
        expect(button.onPressed, isNull, reason: 'resolved rows must disable every recovery action');
      }
      now = now.add(const Duration(minutes: 1, seconds: 59));
      await tester.pump(const Duration(minutes: 1, seconds: 59));
      expect(
        find.byKey(const Key('recently-resolved')),
        findsOneWidget,
        reason: 'retention must last until its deadline',
      );
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byKey(const Key('recently-resolved')),
        findsNothing,
        reason: 'expired conditions must leave no retained content',
      );
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
      expect(
        find.byKey(ValueKey('messages-wait ${machine.name}')),
        findsNothing,
        reason: 'zero retention must discard the resolved condition immediately',
      );
      expect(find.text('Recently resolved'), findsNothing, reason: 'zero retention must leave no resolved content');
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
      expect(
        find.text('Recently resolved'),
        findsOneWidget,
        reason: 'resolved conditions must retain a readable trace',
      );
      backend.theProjectsItHas = [waiting('vault')];
      await state.machines.of(machine).refresh();
      await World.settle(tester);
      await expandListRows(tester);
      expect(
        find.text('Recently resolved'),
        findsNothing,
        reason: 'the returning condition must leave the resolved list',
      );
      expect(
        find.byKey(ValueKey('messages-wait ${machine.name}')),
        findsOneWidget,
        reason: 'the returning condition must offer a fresh decision',
      );
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
      await expandListRows(tester);
      await World.settle(tester);
      final read = find.byKey(const ValueKey('read-message alpha/held.json'));
      await tester.ensureVisible(read);
      await tester.tap(read);
      await World.settle(tester);
      expect(
        find.byKey(const Key('held-message-dialog')),
        findsOneWidget,
        reason: 'an explicit read must open the full message before any decision',
      );
      await tester.tap(find.byKey(const Key('held-message-close')));
      await World.settle(tester);
      await expandListRows(tester, within: find.byKey(const Key('recently-resolved')));
      final resolved = find.byKey(const Key('recently-resolved'));
      expect(resolved, findsOneWidget, reason: 'an explicitly read message must remain available in the resolved list');
      expect(
        find.descendant(of: find.byKey(const Key('open-attention')), matching: read),
        findsNothing,
        reason: 'a read message must not remain an open decision',
      );
      expect(
        tester.widget<OutlinedButton>(find.descendant(of: resolved, matching: read)).onPressed,
        isNull,
        reason: 'retained message actions must not decide the message again',
      );
      final row = find.descendant(
        of: resolved,
        matching: find.byKey(ValueKey('held-message ${machine.name}/alpha/held.json')),
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await World.settle(tester);
      expect(
        find.text('Please review this work.'),
        findsWidgets,
        reason: 'the explicitly read text must remain readable',
      );
      expect(
        find.byKey(const Key('release-message')),
        findsNothing,
        reason: 'a retained read must not offer another release',
      );
      expect(
        find.byKey(const Key('refuse-message')),
        findsNothing,
        reason: 'a retained read must not offer another refusal',
      );
      expect(backend.released, isEmpty, reason: 'reading retained text must never deliver the message');
    } finally {
      await state.dispose();
    }
  });
}
