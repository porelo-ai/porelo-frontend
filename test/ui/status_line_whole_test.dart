import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/operations.dart';
import 'package:porelo_frontend/src/ui/status_line.dart';

void main() {
  testWidgets('the status line cut to its width is read whole by pointing at it', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final operations = Operations();
    addTearDown(operations.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: StatusLine(fleet: null, operations: operations, machine: 'm', onShowOperations: () {}),
          ),
        ),
      ),
    );
    final shown = tester.widget<Text>(find.byKey(const Key('status-line'))).data;
    final whole = tester.widget<Tooltip>(find.byKey(const Key('status-line-whole')));
    expect(shown, 'Not answering yet: it is being opened.');
    expect(whole.message, shown);
    expect(
      find.ancestor(of: find.byKey(const Key('status-line')), matching: find.byKey(const Key('status-line-whole'))),
      findsOneWidget,
    );
  });
}
