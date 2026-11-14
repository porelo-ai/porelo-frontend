import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/following_output.dart';

/// An output that grows, such as a machine's Prepare protocol, followed as a terminal follows it.
///
/// The harms: a person watching a long run reads old lines and takes it for stuck; or, having scrolled up to read,
/// is pulled away from what they read by every new line; or cannot tell whether the view follows, nor get back.
void main() {
  String lines(int count) => [for (var line = 0; line < count; line++) 'Step number $line'].join('\n');

  Future<void> show(WidgetTester tester, String text, {bool waiting = false}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: FollowingOutput(text: text, waitingForFirstLine: waiting),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(of: find.byKey(const Key('following-output')), matching: find.byType(Scrollable)).first,
      )
      .position;

  bool following(WidgetTester tester) =>
      tester.widget<FilterChip>(find.byKey(const Key('following-output.following'))).selected;

  // Harm: a run that has said nothing yet shows a black, empty pane, and reads as stuck or broken for minutes; or the
  // waiting line hides what an earlier attempt said, or stays once the run is told to have said a line.
  testWidgets('it says it waits for the first line exactly while told so, below what stands already', (tester) async {
    await show(tester, '', waiting: true);
    expect(find.text('Waiting for the first line'), findsOneWidget);
    await show(tester, 'Current attempt', waiting: true);
    expect(find.text('Waiting for the first line'), findsOneWidget, reason: 'a heading alone is no line of the run');
    expect(find.textContaining('Current attempt'), findsOneWidget, reason: 'what stands is not hidden');
    await show(tester, 'Current attempt\n12:00:01 Take the server as given', waiting: false);
    expect(find.text('Waiting for the first line'), findsNothing, reason: 'once a line came, the line stands alone');
    expect(find.textContaining('Take the server as given'), findsOneWidget);
  });

  testWidgets('the last line stays at the bottom while the person has not scrolled up', (tester) async {
    await show(tester, lines(5));
    await show(tester, lines(80));
    expect(position(tester).maxScrollExtent, greaterThan(0), reason: 'the output is longer than its pane');
    expect(position(tester).pixels, position(tester).maxScrollExtent);
    await show(tester, lines(120));
    expect(position(tester).pixels, position(tester).maxScrollExtent, reason: 'it follows each new line');
    expect(following(tester), isTrue);
  });

  testWidgets('scrolling up stops following and says so; scrolling to the end follows again', (tester) async {
    await show(tester, lines(80));
    await tester.drag(find.byKey(const Key('following-output')), const Offset(0, 300));
    await tester.pump();
    final read = position(tester).pixels;
    expect(read, lessThan(position(tester).maxScrollExtent));
    expect(following(tester), isFalse, reason: 'Following shows off once the person scrolled up');
    await show(tester, lines(120));
    expect(position(tester).pixels, read, reason: 'new lines do not pull the person away from what they read');

    position(tester).jumpTo(position(tester).maxScrollExtent);
    await tester.pump();
    expect(following(tester), isTrue, reason: 'at the end it follows again');
    await show(tester, lines(160));
    expect(position(tester).pixels, position(tester).maxScrollExtent);
  });

  testWidgets('Following, turned on, goes to the last line and follows', (tester) async {
    await show(tester, lines(80));
    await tester.drag(find.byKey(const Key('following-output')), const Offset(0, 300));
    await tester.pump();
    expect(following(tester), isFalse);
    await tester.tap(find.byKey(const Key('following-output.following')));
    await tester.pump();
    await tester.pump();
    expect(following(tester), isTrue);
    expect(position(tester).pixels, position(tester).maxScrollExtent);
    await show(tester, lines(120));
    expect(position(tester).pixels, position(tester).maxScrollExtent);
  });

  // Harm: a person selecting lines to copy has them moved away, or the selection dropped, by every new line.
  testWidgets('a selection is not moved by new lines, which come once it is let go', (tester) async {
    await show(tester, lines(80));
    final end = position(tester).pixels;
    final text = tester.state<EditableTextState>(find.byType(EditableText));
    // In view, as a drag chooses it.
    final length = lines(80).length;
    final chosen = TextSelection(baseOffset: length - 10, extentOffset: length);
    text.userUpdateTextEditingValue(text.textEditingValue.copyWith(selection: chosen), SelectionChangedCause.drag);
    await tester.pump();
    await show(tester, lines(120));
    expect(position(tester).pixels, end, reason: 'the view stays where the selection is');
    expect(tester.state<EditableTextState>(find.byType(EditableText)).textEditingValue.selection, chosen);

    final kept = tester.state<EditableTextState>(find.byType(EditableText));
    kept.userUpdateTextEditingValue(
      kept.textEditingValue.copyWith(selection: TextSelection.collapsed(offset: length)),
      SelectionChangedCause.tap,
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Step number 119'), findsOneWidget, reason: 'the new lines come once it is let go');
    expect(position(tester).pixels, position(tester).maxScrollExtent);
  });
}
