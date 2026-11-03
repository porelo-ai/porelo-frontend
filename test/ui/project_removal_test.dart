import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/step/i_open_the_command_finder.dart';
import '../features/step/the_command_is_offered.dart';
import '../features/step/the_command_is_unavailable_because.dart';
import '../features/support/tiles.dart';
import '../features/support/world.dart';
import '../support/expand_list_rows.dart';
import '../support/organization_fixtures.dart';

/// Removing a project loses data, so it is offered only for what Porelo lists as registered here alone.
void main() {
  const command = 'Remove this project';

  Future<void> selected(WidgetTester tester, String project, FixtureOrganization organization) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: organization);
    World.fleet.selectProject(project);
    await World.settle(tester);
    await iOpenTheCommandFinder(tester);
  }

  FixtureOrganization listing(String source) =>
      FixtureOrganization(organizationFor('mia'))..listed = [ListedProject(name: 'checkout', source: source)];

  // Harm: nothing could be removed at all, leaving a project with no organization on the machine for good.
  // Linux only: removing is offered on this computer's own Porelo, and Windows runs none.
  testWidgets('a local project is offered, and pressing it first asks what would go', (tester) async {
    await selected(tester, 'checkout', listing('local'));
    await theCommandIsOffered(tester, command);
    await tester.tap(find.widgetWithText(ListTile, command));
    await World.settle(tester);
    await followTheFinder(tester);
    expect(World.backend.deletions, [
      (project: 'checkout', preview: true, force: false),
    ], reason: 'pressing it previews, and removes nothing');
  }, tags: 'linux');

  // Harm: a project everyone in the organization shares is offered as this person's to remove.
  // Linux only: removing is offered on this computer's own Porelo, and Windows runs none.
  testWidgets('a project of the organization is not offered, and nothing is asked of the machine', (tester) async {
    await selected(tester, 'checkout', listing('organization'));
    await theCommandIsUnavailableBecause(tester, command, 'the organization');
    expect(World.backend.deletions, isEmpty);
  }, tags: 'linux');

  // Harm: a project removed while nothing could say whose it is.
  // Linux only: removing is offered on this computer's own Porelo, and Windows runs none.
  testWidgets('while the source cannot be read it is listed as unavailable, with Porelo’s reason', (tester) async {
    await selected(
      tester,
      'checkout',
      listing('local')..refuseReads = const OrganizationRefused('The store could not be reached.'),
    );
    await theCommandIsUnavailableBecause(tester, command, 'The store could not be reached.');
    expect(World.backend.deletions, isEmpty);
  }, tags: 'linux');

  // Harm: a project of the same name on another machine goes because this computer lists its own as local.
  testWidgets('a project on another machine is not offered, whatever this computer lists', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: listing('local'));
    World.elsewhere.theProjectsItHas = World.backend.theProjectsItHas;
    const second = Machine(name: 'elsewhere', socketPath: '/unused');
    await World.machines.add(second);
    World.machines.select(second);
    await World.settle(tester);
    World.fleet.selectProject('checkout');
    await World.settle(tester);
    await iOpenTheCommandFinder(tester);
    await theCommandIsUnavailableBecause(tester, command, 'on this computer');
    expect(World.elsewhere.deletions, isEmpty);
  });

  // Harm: with no way to ask whose a project is, every project is offered.
  // Linux only: removing is offered on this computer's own Porelo, and Windows runs none.
  testWidgets('with no source to ask, it is not offered', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.fleet.selectProject('checkout');
    await World.settle(tester);
    await iOpenTheCommandFinder(tester);
    await theCommandIsUnavailableBecause(tester, command, 'cannot be asked');
  }, tags: 'linux');

  // Harm: the row under *Needs you* is a second way to the same loss, past the same question.
  testWidgets('a waiting project of the organization is not removable from its row', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      Project.from({
        'name': 'held',
        'file': '/srv/held/project.yml',
        'messages': {'waits': 'Messages cannot move.', 'waitsOn': 'vault'},
      }),
    ];
    final organization = FixtureOrganization(organizationFor('mia'))
      ..listed = const [ListedProject(name: 'held', source: 'organization')];
    await World.startApp(tester, organizationSource: organization);
    World.shell.goTo(Section.attention);
    await World.settle(tester);
    await expandListRows(tester);
    final row = find.descendant(
      of: find.byKey(ValueKey('messages-wait ${World.machines.all.first.name}')),
      matching: find.widgetWithText(TextButton, 'Remove held…'),
    );
    expect(row, findsOneWidget);
    expect(tester.widget<TextButton>(row).onPressed, isNull);
    expect(World.backend.deletions, isEmpty);
  });
}
