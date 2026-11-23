import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/shell.dart';

import '../features/support/planning.dart';
import '../features/support/world.dart';

void main() {
  // Harm: the folder a person picks on the desktop for a local project's planning is not the one the planner keeps it
  // in, or the dialog opens somewhere other than where the planning is kept now.
  testWidgets('a planning directory picked on the desktop is the one the planner keeps', (tester) async {
    final asked = <String?>[];
    final picked = pickAPlanningDirectory;
    pickAPlanningDirectory = ({String? initialDirectory, String? title}) async {
      asked.add(initialDirectory);
      return '/home/person/plans-elsewhere';
    };
    addTearDown(() => pickAPlanningDirectory = picked);
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      Project.from({'name': 'checkout'}),
    ];
    World.planning.boards['checkout'] = planningFixture()
      ..['tracker'] = {
        'kind': 'local',
        'items': '/home/person/plans',
        // The project's own default, which the planner names beside the directory in use.
        'default': '/home/person/default-plans',
      };
    await World.startApp(tester);
    World.shell.goTo(Section.planning);
    await World.settle(tester);
    expect(find.byKey(const Key('items-directory')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('items-directory-choose')));
    await tester.tap(find.byKey(const Key('items-directory-choose')));
    await World.settle(tester);

    expect(asked, ['/home/person/plans']);
    expect(World.planning.directoryCalls.map((call) => (call.$1, call.$2)), [
      ('checkout', '/home/person/plans-elsewhere'),
    ]);
    expect(
      tester.widget<Text>(find.byKey(const Key('items-directory'))).data,
      contains('/home/person/plans-elsewhere'),
    );
  });
}
