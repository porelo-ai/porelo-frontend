import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/shell_rail.dart';

void main() {
  Future<void> show(WidgetTester tester, {int? reviewing, VoidCallback? onReviewing}) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellRail(
            section: Section.work,
            running: 0,
            work: 0,
            needing: 2,
            reviewing: reviewing,
            onReviewing: onReviewing,
            machines: 0,
            projects: 0,
            width: 280,
            onGo: (_) {},
            onRefresh: () {},
            onStopEverywhere: null,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final count = find.byKey(const Key('rail-review-count'));
  final needsYou = find.byKey(const ValueKey('rail attention'));

  // Harm: the reviews hide in Needs you's own badge, so "nothing needs you" hides 63 reviews or 63 reviews hide a
  // question; or the person cannot tell which number is which.
  testWidgets('the issues waiting for review stand as a count of their own beside Needs you', (tester) async {
    await show(tester, reviewing: 63);

    expect(find.descendant(of: needsYou, matching: count), findsOneWidget);
    expect(find.descendant(of: count, matching: find.text('63')), findsOneWidget);
    expect(tester.widget<Badge>(find.byKey(const Key('needing-count-badge'))).label, isA<Text>());
    expect((tester.widget<Badge>(find.byKey(const Key('needing-count-badge'))).label! as Text).data, '2');
    expect(find.byTooltip('63 stories wait for your review'), findsOneWidget);
  });

  // Harm: the count reads as Needs you's own, or several hundred reviews read as 99.
  testWidgets('the review count carries the review mark and its whole number', (tester) async {
    await show(tester, reviewing: 343);

    expect(find.descendant(of: count, matching: find.byIcon(Icons.visibility_outlined)), findsOneWidget);
    expect(find.descendant(of: count, matching: find.text('343')), findsOneWidget);
    expect(find.byTooltip('343 stories wait for your review'), findsOneWidget);
  });

  // Harm: a count no board has said yet, or one no planner will ever say, reads as nothing to review.
  testWidgets('no review count is shown while it is not known', (tester) async {
    await show(tester);

    expect(count, findsNothing);
    expect(find.descendant(of: needsYou, matching: find.text('0')), findsNothing);
  });

  // Harm: the count only informs, and the person must look for the issues it counts.
  testWidgets('pressing the review count opens the planning board, not Needs you', (tester) async {
    var opened = 0;
    await show(tester, reviewing: 1, onReviewing: () => opened++);

    await tester.tap(count);
    await tester.pump();
    expect(opened, 1);
    expect(find.byTooltip('1 story waits for your review'), findsOneWidget);
  });
}
