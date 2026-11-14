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

  // Harm: a repository its row and its page call carried by this machine refuses its work in its menu, or calls itself
  // not on this machine there, so the start the row offers cannot be reached from its menu (seen live).
  testWidgets("a carried repository's menu offers its work, as its row and the page say", (tester) async {
    final started = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProjectHeader(
              project: ProjectOnScreen(
                project: Project.from(<String, dynamic>{
                  'name': 'tools',
                  'carried': true,
                  'repositories': <Map<String, dynamic>>[
                    <String, dynamic>{'name': 'claude', 'own': false, 'carriedHere': true, 'central': 'up-to-date'},
                  ],
                }),
                tasks: const <Task>[],
              ),
              muted: false,
              menu: const [],
              onTheMachine: const {'claude': (words: 'carried here alone', carried: true, startRefused: null)},
              onStart: started.add,
              onSync: (_) {},
              onBackups: (_) {},
              onOpens: (_) {},
              onReach: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('carried by this machine'), findsOneWidget);
    await tester.tap(find.byKey(const Key('repository-menu claude')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('not on this machine'), findsNothing);
    expect(find.textContaining('work cannot start'), findsNothing);
    expect(find.textContaining('not taken here yet'), findsNWidgets(4), reason: 'what needs it taken says so');
    await tester.tap(find.text('Start work in claude'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(started, ['claude']);
  });
}
