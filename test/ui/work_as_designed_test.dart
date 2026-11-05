import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';
import 'package:porelo_frontend/src/ui/console_lines.dart';
import 'package:porelo_frontend/src/ui/filtered_list_section.dart';
import 'package:porelo_frontend/src/ui/small_switch.dart';
import 'package:porelo_frontend/src/ui/theme.dart';

import '../features/support/world.dart';

void main() {
  // Harm: a column of sentences to read where a glance at a word would do.
  testWidgets('a row of work says its state in a few words', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    final machine = World.machines.current;
    String said(Demand demand, {bool terminalEnded = false}) => WorkRow.stateOf(
      Tile(machine: machine, fleet: World.machines.of(machine), demand: demand),
      terminalEnded: terminalEnded,
    );
    expect(said(Demand.working), 'working');
    expect(said(Demand.gate), 'waits for review');
    expect(said(Demand.question), 'waits for an answer');
    expect(said(Demand.ended), 'its agent ended');
    expect(said(Demand.stopped), 'not running');
    expect(said(Demand.unseen), 'running');
    expect(said(Demand.quiet), 'quiet');
    expect(said(Demand.quiet, terminalEnded: true), 'no terminal open');
  });

  // Harm: a search field always open takes the place of what the other lists keep it behind.
  testWidgets('a kept search opens on a click, and stays while it holds something', (tester) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FilteredListSection(
              title: 'All work',
              storageId: 'kept-search',
              search: search,
              sorts: [SectionSort('Sorted by name', (row) => '')],
              rows: const [],
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('kept-search-filter')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('kept-search-search')));
    await tester.pump();
    expect(find.byKey(const ValueKey('kept-search-filter')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('kept-search-filter-close')));
    await tester.pump();
    expect(find.byKey(const ValueKey('kept-search-filter')), findsNothing);
    search.text = 'held from elsewhere';
    await tester.pump();
    expect(find.byKey(const ValueKey('kept-search-filter')), findsOneWidget);
  });

  // Harm: a light list grey on grey, where the design has its rows on white under a pale head.
  testWidgets('a light list has its rows on white, under the pale head', (tester) async {
    Future<(Color?, Set<Color>)> colours(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FilteredListSection(title: 'A list', storageId: 'colours', rows: const []),
            ),
          ),
        ),
      );
      final section = find.byType(FilteredListSection);
      return (
        tester.widget<Material>(find.descendant(of: section, matching: find.byType(Material)).first).color,
        tester
            .widgetList<ColoredBox>(find.descendant(of: section, matching: find.byType(ColoredBox)))
            .map((box) => box.color)
            .toSet(),
      );
    }

    final (card, head) = await colours(PoreloTheme.light);
    expect(card, Colors.white);
    expect(head, contains(const Color(0xFFEAEDF7)));
  });

  // Harm: a bar's switch standing out over the words beside it.
  testWidgets('the small switch has the size of the design, and says what it is', (tester) async {
    var on = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SmallSwitch(key: const Key('small'), label: 'Follow', value: on, onChanged: (value) => on = value),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('small'))), const Size(38, 22));
    await tester.tap(find.byKey(const Key('small')));
    expect(on, isTrue);
  });

  // Harm: the time an agent worked reads as a result, when only its finishing is one.
  test('only a finish is a result among the star lines', () {
    expect(markOf('✻ Finished at 09:02'), LineMark.result);
    expect(markOf('✻ Worked for 3m 40s'), isNot(LineMark.result));
    expect(markOf('✻ Worked for 3m 40s'), isNot(LineMark.plain));
  });
}
