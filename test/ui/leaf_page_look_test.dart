import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';
import 'package:porelo_frontend/src/ui/filtered_list_section.dart';

import '../features/support/tiles.dart';
import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

void main() {
  // Harm: a list is mistaken for another organization's and a person acts there.
  testWidgets('every leaf names its path above its title', (tester) async {
    await World.startBackend(World.work);
    final view = organizationFor('olive');
    await World.startApp(tester, organizationSource: FixtureOrganization(view));
    for (final section in OrganizationSection.values) {
      await toTheOrganization(tester, section: section);
      expect(World.shell.place.organizationSection, section, reason: 'the tree must reach the fixture organization');
      final head = find.byType(PageHead);
      expect(head, findsOneWidget, reason: section.label);
      final list = tester.widget<FilteredListSection>(find.byType(FilteredListSection));
      expect(list.title, section.label, reason: 'only the chosen section belongs on this page');
      expect(list.rows.length, switch (section) {
        OrganizationSection.people => view.persons.length,
        OrganizationSection.projects => view.projects.length,
        OrganizationSection.machines => view.hosts.length,
        OrganizationSection.owners => view.owners.length,
        OrganizationSection.admins => view.organizationAdmins?.length ?? 0,
      });
      final path = find.descendant(of: head, matching: find.byKey(const Key('leaf-path')));
      expect(path, findsOneWidget, reason: section.label);
      expect(find.descendant(of: path, matching: find.text(view.name)), findsOneWidget);
      final title = find.descendant(of: head, matching: find.byKey(const Key('leaf-title')));
      expect(tester.getTopLeft(path).dy, lessThan(tester.getTopLeft(title).dy));
      expect(find.text(section.label).last, findsOneWidget);
      expect(tester.takeException(), isNull, reason: section.label);
    }
    Future<void> expectPath(String ancestor) async {
      final head = find.byType(PageHead).first;
      final path = find.descendant(of: head, matching: find.byKey(const Key('leaf-path')));
      expect(find.descendant(of: path, matching: find.text(ancestor)), findsOneWidget);
      final title = find.descendant(of: head, matching: find.byKey(const Key('leaf-title')));
      expect(tester.getTopLeft(path).dy, lessThan(tester.getTopLeft(title).dy));
    }

    await toThePlace(tester, 'projects');
    expect(find.byKey(const Key('leaf-path')), findsNothing, reason: 'a top entry has no repeated path');
    await tester.tap(find.byKey(const Key('projects-of-machines')));
    await World.settle(tester);
    await expectPath('My projects');
    await tapOnScreen(tester, cardFor('checkout'));
    await World.settle(tester);
    await expectPath('My projects');
    await toThePlace(tester, 'forges');
    expect(find.byKey(const Key('leaf-path')), findsNothing, reason: 'a top entry has no repeated path');
    World.forges.current = const ForgeEntry(
      id: 'central',
      kind: 'github',
      name: 'Central',
      address: 'forge.example.org',
    );
    World.shell.goTo(Section.forge);
    await World.settle(tester);
    final forgeHead = find.byType(PageHead).first;
    final forgePath = find.descendant(of: forgeHead, matching: find.byKey(const Key('leaf-path')));
    expect(find.descendant(of: forgePath, matching: find.text('My forges')), findsOneWidget);
    expect(tester.getTopLeft(forgePath).dy, lessThan(tester.getTopLeft(find.byKey(const Key('forge-title'))).dy));
  });

  // Harm: a filtered count is mistaken for the total, hiding work from a decision.
  testWidgets('a filter narrows the rows and the subtitle keeps the whole count', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('olive')));
    await toTheOrganization(tester);
    expect(World.shell.place.organizationSection, OrganizationSection.people);
    final subtitle = find.byKey(const Key('organization-people-subtitle'));
    final before = tester.widget<Text>(subtitle).data;
    final filter = find.byKey(const Key('organization-people-filter'));
    expect(filter, findsOneWidget);
    await tester.enterText(filter, 'olive');
    await World.settle(tester);
    expect(find.text('olive (you)'), findsOneWidget);
    expect(find.text('pat'), findsNothing);
    expect(tester.widget<Text>(subtitle).data, before);
    await tester.enterText(filter, 'no such person');
    await World.settle(tester);
    expect(find.text('Nothing matches.'), findsOneWidget);
    await tester.tap(find.text('Clear the filter'));
    await World.settle(tester);
    expect(find.text('pat'), findsOneWidget);
  });

  // Harm: a state cut off on a phone conceals that a machine has refused a project.
  testWidgets('a row state stays in sight as a chip at 390 wide', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExpandableListRow(
              leading: const Icon(Icons.folder_outlined),
              title: 'A long project name belonging to the second machine',
              state: 'refused by the machine',
              onOpen: () {},
              details: const Text('The machine refused the project.'),
            ),
          ),
        ),
      ),
    );
    final chip = find.widgetWithText(Chip, 'refused by the machine');
    expect(chip, findsOneWidget);
    final bounds = tester.getRect(chip);
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(390));
    expect(chip.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Harm: tapping a row cannot reach its project, or pressing its command also navigates.
  testWidgets('a leaf row keeps navigation separate from its commands', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var opened = 0;
    var commands = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LeafListRow(
              key: const Key('leaf-row'),
              title: 'Project',
              subtitle: const Text('On a machine'),
              leading: const Icon(Icons.folder_outlined),
              state: 'on the machine',
              onTap: () => opened++,
              trailing: IconButton(
                key: const Key('leaf-command'),
                onPressed: () => commands++,
                icon: const Icon(Icons.more_vert),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('leaf-row')));
    expect(opened, 1);
    expect(commands, 0);
    await tester.tap(find.byKey(const Key('leaf-command')));
    expect(commands, 1);
    expect(opened, 1, reason: 'a command does not open the project too');
  });

  // Harm: a historical project is presented as present on a machine that cannot act on it.
  testWidgets('a connected machine does not make a historical project present', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas.add(Project.from({'name': 'retired', 'file': ''}));
    await World.startApp(tester);
    await toTheProjects(tester);
    final row = find.byKey(ValueKey('projects-row ${World.machines.current.name}/retired'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.widgetWithText(Chip, 'on the machine')), findsNothing);
    expect(find.descendant(of: row, matching: find.widgetWithText(Chip, 'Not on this machine')), findsOneWidget);
  });

  // Harm: a read failure folds away, leaving stale rows without a way to retry.
  testWidgets('a folded leaf keeps its read failure and retry in sight', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? problem;
    late StateSetter change;
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return SingleChildScrollView(
                child: FilteredListSection(
                  title: 'Repositories',
                  storageId: 'failed-read',
                  leaf: true,
                  problem: problem,
                  onRetry: () => retries++,
                  rows: const [(words: 'api', child: Text('api'))],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('failed-read-fold')));
    await tester.pump();
    change(() => problem = 'The forge cannot be reached.');
    await tester.pump();
    expect(find.text('api'), findsNothing, reason: 'the chosen fold is retained');
    expect(find.text('The forge cannot be reached.'), findsOneWidget);
    expect(find.text('Try again').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  // Harm: the action a person came for cannot be reached on a phone.
  testWidgets('a leaf main action is in sight at 390 wide', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await World.settle(tester);
    await toThePlace(tester, 'forges');
    final action = find.byKey(const Key('forge-add'));
    expect(action.hitTestable(), findsOneWidget);
    final bounds = tester.getRect(action);
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(390));
    expect(tester.getSize(action).width, greaterThan(300));
    expect(tester.takeException(), isNull);
  });
}
