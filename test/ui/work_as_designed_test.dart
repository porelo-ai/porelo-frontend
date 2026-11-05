import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';
import 'package:porelo_frontend/src/ui/console_lines.dart';
import 'package:porelo_frontend/src/ui/filtered_list_section.dart';
import 'package:porelo_frontend/src/ui/small_switch.dart';
import 'package:porelo_frontend/src/ui/terminal_look.dart';
import 'package:porelo_frontend/src/ui/theme.dart';
import 'package:porelo_frontend/src/ui/tokens.dart';

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

  // Harm: the boxes of Needs you grey on grey beside lists on white.
  testWidgets('a box of Needs you has its rows on white, under the pale head', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.shell.goTo(Section.attention);
    await World.settle(tester);
    final box = find.byKey(const ValueKey<String>('needs-group reviews'));
    final colors = Theme.of(tester.element(box)).colorScheme;
    expect(
      tester.widget<Material>(find.descendant(of: box, matching: find.byType(Material)).first).color,
      listCardColour(colors),
    );
    expect(
      tester.widget<ColoredBox>(find.descendant(of: box, matching: find.byType(ColoredBox)).first).color,
      listHeadColour(colors),
    );
  });

  // Harm: the list repeats, in a block on each opened row, what the terminal under Running shows.
  testWidgets('an opened row shows its status and the way on, and no console', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.shell.goTo(Section.work);
    await World.settle(tester);
    await tester.tap(find.byKey(ValueKey<String>('tile ${World.machines.current.name} porelo-checkout-shell')));
    await World.settle(tester);
    expect(find.byKey(const Key('tile-fact started')), findsWidgets);
    expect(find.textContaining('Its agent works in its terminal'), findsNothing);
    expect(find.textContaining(RegExp(r'^started ')), findsNothing, reason: 'Started says it');
    expect(find.textContaining(RegExp(r'^in ')), findsNothing, reason: 'Repository says it');
  });

  // Harm: a terminal pale on white in the light theme, where an agent's and tmux's own colours do not read.
  testWidgets('the terminal stays dark in the light theme, and the bar around it follows', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: PoreloTheme.light,
        home: Builder(
          builder: (each) {
            context = each;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(TerminalLook.themeOf(context).background, TerminalLook.darkConsole.background);
    expect(TerminalLook.screen.background, ConsoleColours.dark.background);
    expect(TerminalLook.consoleOf(context).background, ConsoleColours.light.background, reason: 'the bar follows');
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
    final colors = Theme.of(tester.element(find.byKey(const Key('small')))).colorScheme;
    expect(
      tester
          .widget<Material>(find.descendant(of: find.byKey(const Key('small')), matching: find.byType(Material)))
          .color,
      colors.outline,
      reason: 'off, it must be told from the page',
    );
  });

  // Harm: the time an agent worked reads as a result, when only its finishing is one.
  test('only a finish is a result among the star lines', () {
    expect(markOf('✻ Finished at 09:02'), LineMark.result);
    expect(markOf('✻ Worked for 3m 40s'), isNot(LineMark.result));
    expect(markOf('✻ Worked for 3m 40s'), isNot(LineMark.plain));
    expect(markOf('✻ Error: provider refused the request'), LineMark.error);
  });
}
