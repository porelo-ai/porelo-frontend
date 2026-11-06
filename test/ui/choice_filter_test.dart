import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/choice_field.dart';

/// A choice from a long list narrows as one types.
///
/// The harm: a person who cannot find the repository to start work on in a list taller than the
/// window, and starts it on a neighbour instead.
void main() {
  testWidgets('a choice of twenty repositories filters, and Enter takes the only one left', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final names = <String>[for (var i = 0; i < 19; i++) 'library-$i', 'sluice'];
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ChoiceField<String>(
              id: 'start-repository',
              label: 'Which repository',
              value: chosen,
              choices: <Choice<String>>[for (final name in names) Choice(name, name, id: 'start-repository-$name')],
              onChanged: (value) => setState(() => chosen = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('start-repository')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('start-repository-filter')), 'slu');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-repository-library-3')), findsNothing);
    expect(find.byKey(const Key('start-repository-sluice')), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(chosen, 'sluice');
    expect(find.byKey(const Key('start-repository-filter')), findsNothing, reason: 'the dialog closed');
  });
}
