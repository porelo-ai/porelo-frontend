import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/gate_view.dart';

/// Forwarding offers the repository's branches, the default first and chosen, and a new branch is
/// checked before anything is sent.
void main() {
  Future<String?> ask(WidgetTester tester, {List<String> branches = const <String>[], String? defaultBranch}) async {
    String? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await askWhichBranch(
              context,
              subject: 'Round to the nearest penny',
              branches: branches,
              defaultBranch: defaultBranch,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('the default branch is offered first and chosen', (tester) async {
    String? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await askWhichBranch(
              context,
              subject: 'Round',
              branches: const <String>['dev', 'main'],
              defaultBranch: 'main',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('main (its default branch)'), findsOneWidget);
    expect(find.byKey(const Key('forward-new-branch')), findsNothing);
    await tester.tap(find.text('Forward it'));
    await tester.pumpAndSettle();
    expect(answer, 'main');
  });

  testWidgets('where no forge said the branches, one is typed, and a name git refuses is not sent', (tester) async {
    await ask(tester);
    await tester.enterText(find.byKey(const Key('forward-new-branch')), 'Round to the nearest penny');
    await tester.pumpAndSettle();
    expect(find.text('A branch name has no spaces.'), findsOneWidget);
    await tester.tap(find.text('Forward it'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forward-new-branch')), findsOneWidget, reason: 'still open, nothing sent');
  });

  test('what git takes and refuses as a branch name', () {
    for (final good in <String>['main', 'fix-rounding', 'feature/x.y', 'release-1.2']) {
      expect(whyNotABranch(good), isNull, reason: good);
    }
    for (final bad in <String>['a b', 'a..b', '-x', 'x/', 'x.lock', 'a:b', 'x.', 'a/.b', 'a@{b', 'a//b']) {
      expect(whyNotABranch(bad), isNotNull, reason: bad);
    }
  });
}
