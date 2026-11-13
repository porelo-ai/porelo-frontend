import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_model.dart';
import 'package:porelo_frontend/src/ui/machine_tree.dart';

Future<void> _show(WidgetTester tester, String project, Map<String, OnTheMachine> onTheMachine) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProjectHeader(
          project: ProjectOnScreen(
            project: Project.from(<String, dynamic>{
              'name': project,
              'repositories': <Map<String, dynamic>>[
                <String, dynamic>{'name': 'utils4j', 'own': false},
              ],
            }),
            tasks: const <Task>[],
          ),
          muted: false,
          menu: const [],
          onTheMachine: onTheMachine,
        ),
      ),
    ),
  ),
);

const OnTheMachine _carried = (words: 'carried', carried: true, startRefused: null);

void main() {
  // Harm: a host that names a repository default for the project default brings back the row an older Porelo answered
  // for the project itself, on the page opened from that machine only.
  testWidgets('a repository named default that a host names for default is no row on its page', (tester) async {
    await _show(tester, defaultProject, {'utils4j': _carried, defaultProject: _carried});
    expect(find.byKey(const Key('repository-utils4j')), findsOneWidget);
    expect(find.byKey(const Key('repository-default')), findsNothing);
  });

  // Harm: the filter for default's phantom row drops a repository named default of any other project.
  testWidgets('a repository named default that a host names for another project is a row', (tester) async {
    await _show(tester, 'checkout', {'utils4j': _carried, defaultProject: _carried});
    expect(find.byKey(const Key('repository-default')), findsOneWidget);
  });
}
