import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/attention.dart' show AttentionKind;
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart' show NeedsYouTitle;
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';
import 'package:porelo_frontend/src/ui/tokens.dart';

import '../features/support/world.dart';

String get _here => World.machines.current.name;

Finder _row(String id) => find.byKey(ValueKey<String>('attention-row $id'));

/// Every word [row] shows while folded, as one line.
String _wordsOf(WidgetTester tester, Finder row) => tester
    .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
    .join(' | ');

Future<void> _toNeedsYou(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size;
  World.shell.goTo(Section.attention);
  await World.settle(tester);
}

int _times(String words, String name) => name.allMatches(words).length;

/// [title] in [row] is whole, or, where it is cut, nothing on its line leaves room it could have taken: no gap
/// wider than the row's own spacing from the title to what stands beside it, between those, or after the last.
///
/// The test font draws every letter as wide as it is tall, about twice the window's own, so a title whole in the
/// window is cut here; what holds at every width is that a cut title had no free pixel to grow into.
void _expectWholeOrUsingTheRoom(WidgetTester tester, Finder row, String title) {
  final words = find.descendant(of: row, matching: find.text(title));
  expect(words, findsOneWidget, reason: 'the row shows its title as one text');
  if (!tester.renderObject<RenderParagraph>(words).didExceedMaxLines) return;
  final box = tester.getRect(words);
  final card = tester.getRect(find.descendant(of: row, matching: find.byType(Card)).first);
  // What stands to the title's right: the state, the action and the disclosure, wherever the width puts them.
  final beside = <Rect>[
    for (final element
        in find
            .descendant(
              of: row,
              matching: find.byWidgetPredicate(
                (widget) => widget is StateChip || widget is ButtonStyleButton || widget is IconButton,
              ),
            )
            .evaluate())
      tester.getRect(find.byWidget(element.widget).first),
  ].where((rect) => rect.left >= box.right).toList()..sort((a, b) => a.left.compareTo(b.left));
  expect(beside, isNotEmpty, reason: 'the disclosure at least stands beside the title');
  for (final rect in beside) {
    expect(
      rect.width,
      lessThanOrEqualTo(card.width * Sizes.rowSideShare),
      reason: 'what stands beside "$title" takes ${rect.width} of the row\'s ${card.width} pixels',
    );
  }
  final edges = <double>[
    box.right,
    for (final rect in beside) ...[rect.left, rect.right],
    card.right,
  ];
  for (var at = 0; at + 1 < edges.length; at += 2) {
    expect(
      edges[at + 1] - edges[at],
      lessThanOrEqualTo(Space.small * 2),
      reason: '"$title" is cut while ${edges[at + 1] - edges[at]} pixels stand free at ${edges[at]} on its line',
    );
  }
}

/// Pumps one row of [title] with a short state and a short action, in a card [card] wide or the whole window.
Future<Finder> _pumpRow(
  WidgetTester tester, {
  required Size size,
  required String title,
  double? card,
  List<Widget> steps = const <Widget>[],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final row = ExpandableListRow(
    key: const Key('row'),
    leading: const Icon(Icons.error_outline),
    title: title,
    state: 'Failed',
    onOpen: () {},
    // A row with next steps of its own offers no single action, as under *Needs you*.
    primary: steps.isEmpty ? Command(id: 'row.open', label: 'Open', group: 'Details', run: () {}) : null,
    steps: steps,
    details: const SizedBox.shrink(),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: card == null
            ? row
            : Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: card, child: row),
              ),
      ),
    ),
  );
  return find.byKey(const Key('row'));
}

void main() {
  for (final size in const <Size>[Size(1280, 720), Size(390, 800)]) {
    final width = size.width.toInt();

    // Harm: a machine that does not answer reads "this machine · this machine", and its name is read as two.
    testWidgets('a machine that does not answer names itself once, at $width wide', (tester) async {
      await World.startBackend(World.work);
      await World.startApp(tester);
      World.backend.lose();
      await World.settle(tester);
      await _toNeedsYou(tester, size: size);

      final row = _row('silent $_here');
      expect(row, findsOneWidget);
      final words = _wordsOf(tester, row);
      expect(_times(words, _here), 1, reason: 'the row reads: $words');
    });

    // Harm: work at the gate named by half its name, so the push is taken for another's.
    testWidgets('a gate row says its title whole where the row has room, at $width wide', (tester) async {
      await World.startBackend(World.work);
      await World.startApp(tester);
      World.theWorkIs('porelo-checkout-migrate', activity: 'WORKING', waiting: 1);
      await _toNeedsYou(tester, size: size);

      final row = _row('gate $_here/porelo-checkout-migrate');
      expect(row, findsOneWidget);
      const title = 'porelo-checkout-migrate: 1 commit waits at the gate';
      expect(_times(_wordsOf(tester, row), _here), 1, reason: 'its machine is named once, under the title');
      _expectWholeOrUsingTheRoom(tester, row, title);
    });

    // Harm: a row's name cut short while the room beside a short state and action stands empty.
    testWidgets('a long title takes what a short state and action leave, at $width wide', (tester) async {
      const title = 'porelo-foo-project-gate-1: 1 commit waits at the gate, under a name too long for any row';
      final row = await _pumpRow(tester, size: size, title: title);
      expect(tester.renderObject<RenderParagraph>(find.text(title)).didExceedMaxLines, isTrue, reason: 'too long');
      _expectWholeOrUsingTheRoom(tester, row, title);
    });

    // Harm: a gate's title cut at half the row, though the whole row would hold it.
    testWidgets('a title the row can hold is shown whole, at $width wide', (tester) async {
      const title = 'porelo-foo-project-gate-1: 1 commit waits at the gate';
      final row = await _pumpRow(tester, size: size, title: title);
      expect(
        tester.renderObject<RenderParagraph>(find.text(title)).didExceedMaxLines,
        width < 1280,
        reason: 'whole where the row holds it, cut where it cannot',
      );
      _expectWholeOrUsingTheRoom(tester, row, title);
    });

    // Harm: the row breaks its layout, and hides its name, where its next steps leave little room.
    testWidgets('a row whose steps leave little room lays out without overflow, at $width wide', (tester) async {
      await _pumpRow(
        tester,
        size: size,
        title: 'porelo-foo-project-gate-1',
        card: Sizes.rowChipBeside + 120,
        // About 70 pixels left to the words, between the steps and the disclosure.
        steps: const <Widget>[SizedBox(width: Sizes.rowChipBeside + 2, height: 1)],
      );
      expect(tester.takeException(), isNull, reason: 'the row fits the room its steps leave');
    });
  }

  // Harm: a server being prepared reads "demo server · demo server", and is taken for two.
  test("a row's title names its machine once, whatever kind of row it is", () {
    for (final (kind, title, machine) in <(AttentionKind, String, String)>[
      (AttentionKind.host, 'demo server', 'demo server'),
      (AttentionKind.host, 'orchard server', 'orchard'),
      (AttentionKind.silent, 'this machine', 'this machine'),
      (AttentionKind.waiting, 'Messages wait', 'this machine'),
      (AttentionKind.setAside, 'Saved machines not watched', 'This computer'),
    ]) {
      final said = NeedsYouTitle.of(kind, title, machine);
      expect(_times(said, machine), 1, reason: '$kind reads "$said"');
      expect(said, contains(title), reason: '$kind keeps its title');
    }
  });
}
