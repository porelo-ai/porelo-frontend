import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';

Widget _row(Command command, {String? subtitle}) => MaterialApp(
  home: Scaffold(
    body: ExpandableListRow(
      leading: const SizedBox.shrink(),
      title: 'a row',
      state: 'its state',
      subtitle: subtitle,
      onOpen: () {},
      details: const Text('its details'),
      primary: command,
    ),
  ),
);

Command _go({String? unavailable}) =>
    Command(id: 'go', label: 'Go', group: 'Work', run: () {}, unavailable: unavailable);

void main() {
  // Harm: a grey button whose reason only a hover can find, which a keyboard or a touch never finds.
  testWidgets('a row says why its grey button is grey, folded', (tester) async {
    await tester.pumpWidget(_row(_go(unavailable: 'the machine is not answering')));
    expect(find.text('Go: the machine is not answering'), findsOneWidget);
  });

  // Harm: a list that jumps under the pointer as a command comes and goes.
  testWidgets('its height does not change with the state of its command', (tester) async {
    await tester.pumpWidget(_row(_go(), subtitle: 'what it is'));
    final available = tester.getSize(find.byType(ExpandableListRow)).height;
    expect(find.text('what it is'), findsOneWidget);
    await tester.pumpWidget(_row(_go(unavailable: 'the machine is not answering'), subtitle: 'what it is'));
    expect(tester.getSize(find.byType(ExpandableListRow)).height, available);
    expect(find.text('Go: the machine is not answering'), findsOneWidget);
  });

  // Harm: the line the reason took is gone for good.
  testWidgets('what the reason covers is there, opened, and the reason once', (tester) async {
    await tester.pumpWidget(_row(_go(unavailable: 'the machine is not answering'), subtitle: 'what it is'));
    await tester.tap(find.byType(IconButton).last);
    await tester.pump();
    expect(find.text('what it is'), findsOneWidget);
    expect(find.text('Go: the machine is not answering'), findsOneWidget);
  });
}
