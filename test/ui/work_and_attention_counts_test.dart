import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';

import '../features/step/i_search_the_work_for.dart';
import '../features/support/tiles.dart';
import '../features/support/world.dart';

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void _workCount(WidgetTester tester, int? count) {
  expect(_text(tester, 'rail-work-count'), count == null ? '?' : '$count');
  final subtitle = _text(tester, 'work-list-subtitle');
  if (count == null) {
    expect(subtitle.toLowerCase(), contains('not read'));
  } else {
    final total = RegExp(r'^(\d+) pieces? of work\b').firstMatch(subtitle);
    expect(total, isNotNull, reason: 'the subtitle must say how much work is counted');
    expect(int.parse(total!.group(1)!), count);
  }
}

void _needsCount(WidgetTester tester, int? count, {bool incomplete = false}) {
  final subtitle = _text(tester, 'needs-you-subtitle');
  final badge = find.byKey(const Key('needing-count-badge'));
  if (count == null) {
    expect(badge, findsNothing);
    expect(find.descendant(of: find.byKey(const Key('rail attention')), matching: find.text('?')), findsOneWidget);
    expect(subtitle.toLowerCase(), contains('not read'));
  } else {
    expect(badge, findsOneWidget);
    final shown = tester.widget<Badge>(badge);
    expect(shown.isLabelVisible, count > 0);
    expect((shown.label! as Text).data, count > 99 ? '99+' : '$count');
    expect(subtitle, count == 0 ? 'Nothing waits on you' : startsWith('$count need you'));
    if (incomplete) expect(subtitle.toLowerCase(), contains('not read'));
  }
  expect(
    find.descendant(of: find.byKey(const Key('open-attention')), matching: find.byType(ExpandableListRow)),
    findsNWidgets(count ?? 0),
    reason: 'the badge and subtitle count exactly the waiting rows, including notices',
  );
}

Future<void> _needs(WidgetTester tester) async {
  World.shell.goTo(Section.attention);
  await World.settle(tester);
}

class _WaitingTasks extends FakeBackend {
  _WaitingTasks() : super(const []) {
    nodeId = 'unread-node';
  }

  final reply = Completer<List<Task>>();

  @override
  Future<List<Task>> tasks() => reply.future;
}

Future<_WaitingTasks> _secondNotRead(WidgetTester tester) async {
  final backend = _WaitingTasks();
  World.elsewhere = backend;
  addTearDown(() async {
    if (!backend.reply.isCompleted) backend.reply.complete(const []);
    await World.settle(tester);
    await backend.stop();
  });
  await World.machines.add(const Machine(name: 'elsewhere', socketPath: '/unused'));
  await World.settle(tester);
  return backend;
}

void main() {
  // Harm: a filter's smaller number hides work that still exists on the watched machines.
  testWidgets('Work filters rows without narrowing either total', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    _workCount(tester, 4);
    for (final (query, rows) in [('billing', 2), ('nothing-like-this', 0), ('', 4)]) {
      await iSearchTheWorkFor(tester, query);
      expect(workRows(), findsNWidgets(rows));
      _workCount(tester, 4);
    }
  });

  // Harm: narrowing Needs you hides the count of waiting rows outside the filter.
  testWidgets('Needs you filters rows without narrowing either total', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await _needs(tester);
    _needsCount(tester, 1);
    await tester.enterText(find.byKey(const Key('needs-you-filter')), 'nothing-like-this');
    await World.settle(tester);
    expect(_text(tester, 'needs-you-subtitle'), '1 need you');
    final badge = tester.widget<Badge>(find.byKey(const Key('needing-count-badge')));
    expect(badge.isLabelVisible, isTrue);
    expect((badge.label! as Text).data, '1');
    expect(
      find.descendant(of: find.byKey(const Key('open-attention')), matching: find.byType(ExpandableListRow)),
      findsNothing,
    );
    await tester.enterText(find.byKey(const Key('needs-you-filter')), '');
    await World.settle(tester);
    _needsCount(tester, 1);
  });

  // Harm: an initial connection still being read is reported as an empty system or as a settled refusal.
  testWidgets('an initial connection in progress has unknown totals and no refusal row', (tester) async {
    await World.startBackend([]);
    final opening = Completer<void>();
    World.backend.answersLater = opening;
    try {
      await World.startApp(tester);
      _workCount(tester, null);
      await _needs(tester);
      _needsCount(tester, null);
    } finally {
      if (!opening.isCompleted) opening.complete();
      await World.settle(tester);
    }
  });

  // Harm: a refused connection hides the notice that needs a person behind an unknown badge.
  testWidgets('a refused initial connection counts its waiting notice', (tester) async {
    await World.startBackend([]);
    World.backend.absent = const VarlinkDisconnected('refused');
    await World.startApp(tester);
    World.fleet.pauseAutomaticRetry();
    _workCount(tester, null);
    await _needs(tester);
    _needsCount(tester, 1);
  });

  // Harm: a failed retry hides a notice, or treats a retained list as a current total.
  testWidgets('a failed reconnect keeps its notice counted and Work unknown', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.fleet.pauseAutomaticRetry();
    World.backend.absent = const VarlinkDisconnected('gone');
    World.backend.lose();
    await World.settle(tester);
    await World.fleet.connect();
    await World.settle(tester);
    _workCount(tester, null);
    expect(workRows(), findsNWidgets(4), reason: 'the last list stays visible');
    await _needs(tester);
    _needsCount(tester, 1);
  });

  // Harm: an unread second machine is reported as no work and nothing waiting anywhere.
  testWidgets('one empty machine and one unread machine have unknown totals', (tester) async {
    await World.startBackend([]);
    await World.startApp(tester);
    final pending = await _secondNotRead(tester);
    _workCount(tester, null);
    await _needs(tester);
    _needsCount(tester, null);
    pending.reply.complete(const []);
    await World.settle(tester);
    _needsCount(tester, 0);
    World.shell.goTo(Section.work);
    await World.settle(tester);
    _workCount(tester, 0);
  });

  // Harm: a known review disappears while another machine is read, or the partial count claims completeness.
  testWidgets('waiting rows stay counted while another machine is unread', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await _secondNotRead(tester);
    _workCount(tester, null);
    await _needs(tester);
    _needsCount(tester, 1, incomplete: true);
  });

  // Harm: losing one connection leaves a current-looking total on the page or in the side bar.
  for (final another in [false, true]) {
    testWidgets('lost contact keeps Work unknown with another machine $another', (tester) async {
      await World.startBackend(World.work);
      await World.startApp(tester);
      if (another) {
        await World.machines.add(const Machine(name: 'elsewhere', socketPath: '/unused'));
        await World.settle(tester);
      }
      World.fleet.pauseAutomaticRetry();
      World.backend.absent = const VarlinkDisconnected('gone');
      World.backend.lose();
      await World.settle(tester);
      _workCount(tester, null);
      expect(workRows(), findsNWidgets(another ? 5 : 4));
      await _needs(tester);
      _needsCount(tester, 1);
    });
  }

  // Harm: a completed empty read remains unknown, making an empty system indistinguishable from an unread one.
  testWidgets('empty completed reads have zero work and nothing waiting', (tester) async {
    await World.startBackend([]);
    await World.startApp(tester);
    _workCount(tester, 0);
    await _needs(tester);
    _needsCount(tester, 0);
  });
}
