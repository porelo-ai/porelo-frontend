import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';
import 'package:porelo_frontend/src/ui/tokens.dart';

/// A row's state, its operations and whether they must stand beside its words on a card this wide.
typedef _Row = ({String name, String state, Widget trailing, bool besideFrom1280, bool besideFrom480});

Widget _menu() => IconButton(key: const Key('menu'), onPressed: () {}, icon: const Icon(Icons.more_vert));

final _rows = <_Row>[
  (name: 'a menu', state: 'review required', trailing: _menu(), besideFrom480: true, besideFrom1280: true),
  (
    name: 'a connect button and a menu',
    state: 'Project Admin',
    trailing: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.normal,
      children: [
        FilledButton(onPressed: () {}, child: const Text('Connect to build')),
        _menu(),
      ],
    ),
    besideFrom480: false,
    besideFrom1280: true,
  ),
  (
    name: 'two buttons',
    state: 'not in force',
    trailing: Wrap(
      spacing: Space.small,
      children: [
        TextButton(onPressed: () {}, child: const Text('Change')),
        TextButton(onPressed: () {}, child: const Text('Remove')),
      ],
    ),
    besideFrom480: false,
    besideFrom1280: true,
  ),
  (name: 'no operations offered', state: 'in force', trailing: Wrap(), besideFrom480: true, besideFrom1280: true),
];

void main() {
  // Harm: a row's state or its buttons are cut or broken letter by letter, so the state cannot be read and a button's
  // name not found, or they spill past the card; the state stands apart from what it describes.
  for (final width in const [480.0, 620.0, 1280.0]) {
    for (final row in _rows) {
      testWidgets("a row's state and buttons stand whole with ${row.name} on a card $width wide", (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: LayoutBuilder(
                      builder: (context, card) => ListCardWidth(
                        width: card.maxWidth,
                        child: LeafListRow(
                          title: 'porelo-frontend',
                          subtitle: const Text('2 repositories · on build'),
                          leading: const Icon(Icons.book_outlined),
                          state: row.state,
                          trailing: row.trailing,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'nothing overflows');

        final chipWords = tester.renderObject<RenderParagraph>(find.text(row.state));
        expect(chipWords.didExceedMaxLines, isFalse, reason: '${row.state} is not cut');
        expect(
          chipWords.size.width,
          greaterThanOrEqualTo(chipWords.getMaxIntrinsicWidth(double.infinity) - 0.5),
          reason: '${row.state} has the width it needs',
        );

        for (final button in find.byWidgetPredicate((widget) => widget is ButtonStyleButton).evaluate()) {
          final box = button.renderObject! as RenderBox;
          expect(
            box.size.height,
            lessThanOrEqualTo(box.getMinIntrinsicHeight(double.infinity) + 0.5),
            reason: '${(button.widget as ButtonStyleButton).child} stands on one line',
          );
        }

        final beside = width >= 1280 ? row.besideFrom1280 : row.besideFrom480;
        final buttons = find.byWidgetPredicate((widget) => widget is ButtonStyleButton);
        if (beside && buttons.evaluate().isEmpty) {
          expect(
            tester.getRect(find.byType(Chip)).right,
            moreOrLessEquals(width - Space.small, epsilon: 0.5),
            reason: 'operations that offer nothing leave no gap after the state',
          );
        } else if (beside) {
          final chip = tester.getRect(find.byType(Chip));
          final first = tester.getRect(buttons.first);
          expect(chip.right, lessThan(first.left), reason: 'the state stands left of the menu or the buttons');
          expect(chip.center.dy, moreOrLessEquals(first.center.dy, epsilon: 0.5), reason: 'on one line with them');
        }
      });
    }
  }
}
