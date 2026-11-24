import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/central_release.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/ui/machine_tree.dart';
import 'package:porelo_frontend/src/ui/tokens.dart';

/// Each repository's state against central, as the machine says it, by the row's name.
const _states = <String, CentralStanding>{
  'ahead': CentralStanding('ahead', '2 commits ahead of central'),
  'moved': CentralStanding('moved-on', 'central moved on'),
  'unsure': CentralStanding('cannot-say', 'cannot say: the central forge cannot be reached'),
  'level': CentralStanding('up-to-date', 'at central'),
  'later': CentralStanding('diverged', 'central: diverged'),
};

Future<void> _show(WidgetTester tester, {required Command bring, Size size = const Size(1280, 800)}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProjectHeader(
            project: ProjectOnScreen(
              project: Project.from(<String, dynamic>{
                'name': 'checkout',
                'carried': true,
                'repositories': <Map<String, dynamic>>[
                  for (final name in _states.keys) <String, dynamic>{'name': name, 'own': false, 'carriedHere': true},
                ],
              }),
              tasks: const <Task>[],
            ),
            muted: false,
            menu: const [],
            bringToCentral: bring,
            onTheMachine: <String, OnTheMachine>{
              for (final MapEntry(:key, :value) in _states.entries)
                key: (words: 'carried · no task running', carried: true, startRefused: null, central: value),
            },
          ),
        ),
      ),
    ),
  );
}

Future<void> _openMenu(WidgetTester tester, String repository) async {
  await tester.tap(find.byKey(Key('repository-menu $repository')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  // Harm: a repository ahead of central or behind it is overlooked in the row's grey line, and its work not brought.
  testWidgets("each central state stands in a chip of its own, toned by what it asks, and not in the row's line", (
    tester,
  ) async {
    await _show(
      tester,
      bring: bringToCentralCommand(ahead: const [], run: () {}),
    );
    final scheme = Theme.of(tester.element(find.byType(ProjectHeader))).colorScheme;
    final quiet = StateColours.of(scheme).stopped;
    final tones = <String, Color>{
      'ahead': scheme.primary,
      'moved': scheme.primary,
      'unsure': scheme.error,
      'level': quiet,
      'later': quiet,
    };
    for (final MapEntry(key: name, value: central) in _states.entries) {
      final chip = find.byKey(Key('repository-central $name'));
      final label = find.descendant(of: chip, matching: find.text(central.words));
      expect(label, findsOneWidget, reason: name);
      expect(tester.widget<Text>(label).style?.color, tones[name], reason: name);
      expect(
        find.descendant(of: find.byKey(Key('repository-$name')), matching: find.textContaining(central.words)),
        findsOneWidget,
        reason: '$name: said once, in the chip, never again in the line',
      );
      expect(find.byTooltip(central.words), findsOneWidget, reason: '$name: the whole state, its reason too');
    }
  });

  // Harm: work ahead of central is seen on its row, but bringing it there is only reached from the page's head.
  testWidgets("an ahead row's menu brings the project to central, and a row at central offers none", (tester) async {
    var brought = 0;
    await _show(
      tester,
      bring: bringToCentralCommand(ahead: const [(repository: 'ahead', commits: 2)], run: () => brought++),
    );

    // The page's head offers it once already; a row's menu only adds to that.
    final head = find.byKey(const Key('project-bring-to-central'));
    expect(head, findsOneWidget);
    await _openMenu(tester, 'level');
    expect(find.text('Bring it to central…'), findsOneWidget, reason: 'the head alone');
    await tester.tapAt(Offset.zero);
    await tester.pump(const Duration(seconds: 1));

    await _openMenu(tester, 'ahead');
    expect(find.text('Bring it to central…'), findsNWidgets(2), reason: 'the head and the row');
    await tester.tap(find.text('Bring it to central…').last);
    await tester.pump(const Duration(seconds: 1));
    expect(brought, 1);
  });

  // Harm: a row that is at central, moved on, cannot say or says a later word offers to bring work that is not there.
  testWidgets('a row that is not ahead offers no Bring it to central…, whatever else it says', (tester) async {
    await _show(
      tester,
      bring: bringToCentralCommand(ahead: const [(repository: 'ahead', commits: 2)], run: () {}),
    );
    for (final name in ['moved', 'unsure', 'later', 'level']) {
      await _openMenu(tester, name);
      expect(find.text('Bring it to central…'), findsOneWidget, reason: '$name: the head alone');
      await tester.tapAt(Offset.zero);
      await tester.pump(const Duration(seconds: 1));
    }
  });

  // Harm: an ahead row whose bringing cannot run now hides it, so the person never learns why.
  testWidgets("an ahead row's bringing that cannot run now is greyed with its reason", (tester) async {
    var brought = 0;
    await _show(
      tester,
      bring: bringToCentralCommand(
        ahead: const [(repository: 'ahead', commits: 2)],
        running: true,
        run: () => brought++,
      ),
    );
    expect(find.byKey(const Key('project-bring-to-central')), findsNothing, reason: 'the head shows it only to run');

    await _openMenu(tester, 'ahead');
    final entry = find.byKey(const ValueKey<String>('project.bringToCentral'));
    expect(entry, findsOneWidget);
    expect(tester.widget<MenuItemButton>(entry).enabled, isFalse);
    expect(find.text('Unavailable: It is being brought to central now; wait for the answer.'), findsOneWidget);
    await tester.tap(find.text('Bring it to central…'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    expect(brought, 0);
  });

  // Harm: on a phone's width the chip crowds the name out or overflows the row.
  testWidgets("at a phone's width the chip stands under the row's line", (tester) async {
    await _show(
      tester,
      bring: bringToCentralCommand(ahead: const [], run: () {}),
      size: const Size(390, 800),
    );
    expect(tester.takeException(), isNull);
    final row = find.byKey(const Key('repository-ahead'));
    final line = find.descendant(of: row, matching: find.text('carried · no task running'));
    final chip = find.byKey(const Key('repository-central ahead'));
    expect(chip, findsOneWidget);
    expect(tester.getTopLeft(chip).dy, greaterThanOrEqualTo(tester.getBottomLeft(line).dy), reason: 'under the line');
  });
}
