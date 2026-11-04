import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/filtered_list_section.dart';

/// A page shows what holds something: an empty list starts folded, and a fold a person chose is theirs.
void main() {
  const row = (words: 'one', child: Text('one'));

  Widget section(
    List<FilteredRow> rows, {
    bool openWhenCompact = true,
    PageStorageBucket? bucket,
    List<Widget> actions = const [],
    Key? key,
  }) => MaterialApp(
    home: Scaffold(
      body: PageStorage(
        bucket: bucket ?? PageStorageBucket(),
        child: SingleChildScrollView(
          child: FilteredListSection(
            key: key,
            title: 'Things',
            storageId: 'things',
            rows: rows,
            collapsible: true,
            openWhenCompact: openWhenCompact,
            actions: actions,
          ),
        ),
      ),
    ),
  );

  void wide(WidgetTester tester, {double width = 1280}) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  bool folded(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(const ValueKey('things-fold'))).tooltip == 'Open things';

  // Harm: a page opens every list, and the empty ones push down what holds something.
  testWidgets('an empty list starts folded, showing its count and its head\'s action', (tester) async {
    wide(tester);
    var pressed = 0;
    await tester.pumpWidget(
      section(
        const [],
        actions: [TextButton(onPressed: () => pressed++, child: const Text('Add one'))],
      ),
    );
    await tester.pumpAndSettle();
    expect(folded(tester), isTrue);
    expect(find.text('0'), findsOneWidget);
    await tester.tap(find.text('Add one'));
    expect(pressed, 1);
  });

  testWidgets('a list with rows starts open', (tester) async {
    wide(tester);
    await tester.pumpWidget(section(const [row]));
    await tester.pumpAndSettle();
    expect(folded(tester), isFalse);
    expect(find.text('one'), findsOneWidget);
  });

  // Harm: a list that loads its rows reads as empty for a moment, and stays folded for good.
  testWidgets('it opens with its first row and folds with its last', (tester) async {
    wide(tester);
    final bucket = PageStorageBucket();
    await tester.pumpWidget(section(const [], bucket: bucket));
    await tester.pumpAndSettle();
    expect(folded(tester), isTrue);
    await tester.pumpWidget(section(const [row], bucket: bucket));
    await tester.pumpAndSettle();
    expect(folded(tester), isFalse);
    await tester.pumpWidget(section(const [], bucket: bucket));
    await tester.pumpAndSettle();
    expect(folded(tester), isTrue);
  });

  // Harm: the window undoes what a person chose.
  testWidgets('a fold the person chose stays through both', (tester) async {
    wide(tester);
    final bucket = PageStorageBucket();
    await tester.pumpWidget(section(const [row], bucket: bucket));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('things-fold')));
    await tester.pumpAndSettle();
    expect(folded(tester), isTrue);
    await tester.pumpWidget(section(const [], bucket: bucket));
    await tester.pumpAndSettle();
    await tester.pumpWidget(section(const [row], bucket: bucket));
    await tester.pumpAndSettle();
    expect(folded(tester), isTrue, reason: 'folded by hand, a first row does not open it');
  });

  testWidgets('a list opened by hand stays open when it is emptied', (tester) async {
    wide(tester);
    final bucket = PageStorageBucket();
    await tester.pumpWidget(section(const [], bucket: bucket));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('things-fold')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(section(const [row], bucket: bucket));
    await tester.pumpAndSettle();
    await tester.pumpWidget(section(const [], bucket: bucket));
    await tester.pumpAndSettle();
    expect(folded(tester), isFalse);
  });

  // Harm: coming back to the page shows a list as it was when left, whatever it holds now.
  testWidgets('a list that got its first row while its page was away opens on return', (tester) async {
    wide(tester);
    final bucket = PageStorageBucket();
    await tester.pumpWidget(section(const [row], bucket: bucket));
    await tester.pumpAndSettle();
    await tester.pumpWidget(section(const [], bucket: bucket));
    await tester.pumpAndSettle();
    expect(folded(tester), isTrue, reason: 'emptied, and kept so as the page leaves');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(section(const [row], bucket: bucket));
    await tester.pumpAndSettle();
    expect(folded(tester), isFalse);
  });

  // Harm: a row just added stands in a folded list, with the refusal and the retry on it out of sight.
  for (final together in [true, false]) {
    testWidgets('a row the window reveals stays in sight on a narrow window, its row '
        '${together ? 'coming with the reveal' : 'coming after it'}', (tester) async {
      wide(tester, width: 390);
      final bucket = PageStorageBucket();
      Widget revealing(List<FilteredRow> rows, String? reveal) => MaterialApp(
        home: Scaffold(
          body: PageStorage(
            bucket: bucket,
            child: SingleChildScrollView(
              child: FilteredListSection(
                title: 'Things',
                storageId: 'things',
                rows: rows,
                collapsible: true,
                openWhenCompact: false,
                reveal: reveal,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(revealing(const [], null));
      await tester.pumpAndSettle();
      expect(folded(tester), isTrue);
      if (!together) {
        await tester.pumpWidget(revealing(const [], 'one'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(revealing(const [row], 'one'));
      await tester.pumpAndSettle();
      expect(folded(tester), isFalse);
      expect(find.text('one'), findsOneWidget);
    });
  }

  // Harm: a narrow window's lists that start folded open by themselves as rows arrive.
  testWidgets('on a narrow window a list that starts folded stays so, with rows or without', (tester) async {
    wide(tester, width: 390);
    final bucket = PageStorageBucket();
    await tester.pumpWidget(section(const [row], openWhenCompact: false, bucket: bucket));
    await tester.pumpAndSettle();
    expect(folded(tester), isTrue);
    await tester.pumpWidget(section(const [], openWhenCompact: false, bucket: bucket));
    await tester.pumpAndSettle();
    await tester.pumpWidget(section(const [row], openWhenCompact: false, bucket: bucket));
    await tester.pumpAndSettle();
    expect(folded(tester), isTrue);
  });
}
