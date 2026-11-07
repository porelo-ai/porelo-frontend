import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/gate_view.dart';

/// Forwarding offers the repository's branches, the default first and chosen, and a new branch is
/// checked before anything is sent.
void main() {
  void desktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  /// Opens the dialog; the answer is read once it closed.
  Future<String? Function()> ask(
    WidgetTester tester, {
    List<String> branches = const <String>[],
    String? defaultBranch,
    String initialBranch = '',
    String branchSource = '',
    String upstream = '',
    bool toOrigin = false,
  }) async {
    desktop(tester);
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
              initialBranch: initialBranch,
              branchSource: branchSource,
              upstream: upstream,
              toOrigin: toOrigin,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    return () => answer;
  }

  testWidgets('the default branch is offered first and chosen', (tester) async {
    desktop(tester);
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
    await settle(tester);
    expect(find.text('main (its default branch)'), findsOneWidget);
    expect(find.byKey(const Key('forward-new-branch')), findsNothing);
    await tester.tap(find.text('Forward it'));
    await settle(tester);
    expect(answer, 'main');
  });

  testWidgets('where no forge said the branches, one is typed, and a name git refuses is not sent', (tester) async {
    await ask(tester);
    await tester.enterText(find.byKey(const Key('forward-new-branch')), 'Round to the nearest penny');
    await settle(tester);
    expect(find.text('A branch name has no spaces.'), findsOneWidget);
    await tester.tap(find.text('Forward it'));
    await settle(tester);
    expect(find.byKey(const Key('forward-new-branch')), findsOneWidget, reason: 'still open, nothing sent');
  });

  // Harm: a prefilled branch absent from the forge is replaced by its default at submission, or a branch the person
  // typed over it is not the one sent.
  testWidgets('a prefilled unlisted branch is sent as shown, or as typed over it', (tester) async {
    final answer = await ask(
      tester,
      branches: ['dev', 'main'],
      defaultBranch: 'main',
      initialBranch: 'porelo/sluice',
      branchSource: "this task's branch",
    );
    final field = find.byKey(const Key('forward-new-branch'));
    expect(tester.widget<TextField>(field).controller!.text, 'porelo/sluice');
    await tester.enterText(field, 'replacement');
    await settle(tester);
    await tester.tap(find.text('Forward it'));
    await settle(tester);
    expect(answer(), 'replacement');
  });

  // Harm: the forge's default is sent despite a different existing task branch being shown.
  testWidgets('a prefilled existing branch is sent, not the default', (tester) async {
    final answer = await ask(
      tester,
      branches: ['dev', 'main'],
      defaultBranch: 'main',
      initialBranch: 'dev',
      branchSource: 'last used for this task',
    );
    await tester.tap(find.text('Forward it'));
    await settle(tester);
    expect(answer(), 'dev');
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
