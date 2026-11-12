import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/templates.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/ui/expandable_list_row.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';
import 'package:porelo_frontend/src/ui/filtered_list_section.dart';

import 'package:porelo_frontend/src/ui/organization_page.dart';
import 'package:porelo_frontend/src/ui/organization_project_pages.dart';
import 'package:porelo_frontend/src/ui/organization_host_pages.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';
import 'package:porelo_frontend/src/ui/tokens.dart';

import '../features/support/tiles.dart';
import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

void main() {
  // Harm: an empty band above the path pushes the page's rows out of sight and reads as a page still loading.
  for (final size in const [Size(1280, 800), Size(700, 900), Size(390, 844)]) {
    testWidgets('a leaf path starts right under the title bar: ${size.width}', (tester) async {
      await World.startBackend(World.work);
      await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('olive')));
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await World.settle(tester);
      Future<void> expectRightUnder(String what) async {
        final bar = tester.getRect(find.byType(AppBar).first);
        final path = find.byWidgetPredicate(
          (widget) =>
              widget.key == const Key('leaf-path') ||
              widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith('machine-section-path '),
        );
        expect(path, findsOneWidget, reason: what);
        expect(tester.getRect(path).top - bar.bottom, lessThanOrEqualTo(Space.normal + Space.small), reason: what);
      }

      await toTheOrganization(tester);
      await closeNavigationTree(tester);
      await expectRightUnder('People');
      for (final section in [MachineSection.vault, MachineSection.tasks]) {
        World.shell.choosePlace(ShellPlace(Section.machine, machine: World.machines.current, machineSection: section));
        await World.settle(tester);
        await expectRightUnder(section.label);
      }
      expect(tester.takeException(), isNull);
    });
  }

  // Harm: a path read as "acme ›People" runs two steps together and sends a person to the wrong page.
  testWidgets('a path line gives every separator the same space on both sides', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageHead(title: 'People', path: [(label: 'Organizations', go: () {}), (label: 'acme', go: () {})]),
        ),
      ),
    );
    final path = find.byKey(const Key('leaf-path'));
    Rect rect(Finder finder) => tester.getRect(find.descendant(of: path, matching: finder));
    final steps = [rect(find.text('Organizations')), rect(find.text('acme')), rect(find.text('People'))];
    final separators = find.descendant(of: path, matching: find.text('›'));
    expect(separators, findsNWidgets(2));
    final gaps = <double>[];
    for (var index = 0; index < 2; index++) {
      final separator = tester.getRect(separators.at(index));
      gaps
        ..add(separator.left - steps[index].right)
        ..add(steps[index + 1].left - separator.right);
    }
    for (final gap in gaps) {
      expect(gap, moreOrLessEquals(gaps.first, epsilon: 0.5), reason: '$gaps');
    }
    expect(gaps.first, greaterThan(0));
  });

  // Harm: a state cut mid-letter reads as another state, and a person acts on what the row does not say.
  testWidgets('a long state chip ends in an ellipsis, never cut mid-letter', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const words = 'GitHub not reached, asked again on the next read';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 160, child: StateChip(words)),
          ),
        ),
      ),
    );
    final label = tester.widget<Text>(find.text(words));
    expect(label.overflow, TextOverflow.ellipsis);
    expect(label.maxLines, 1);
    expect(tester.getRect(find.byType(Chip)).right, lessThanOrEqualTo(160));
    expect(find.byTooltip(words), findsOneWidget, reason: 'the whole state stays readable');
    expect(tester.takeException(), isNull);
  });

  // Harm: a cut hint hides what the filter searches, so a person misses the row they look for.
  testWidgets("a desktop leaf gives its filter the width of its hint", (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('olive')));
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await World.settle(tester);
    await toTheOrganization(tester);
    final people = find.descendant(
      of: find.byKey(const ValueKey('organization-people-filter')),
      matching: find.text('Filter people'),
    );
    expect(tester.renderObject<RenderParagraph>(people).didExceedMaxLines, isFalse);
    await toThePlace(tester, 'work');
    final work = find.descendant(
      of: find.byKey(const Key('work-list-filter')),
      matching: find.text('Name, project or machine'),
    );
    expect(tester.renderObject<RenderParagraph>(work).didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  // Harm: "1 cards wait" reads as a fault in the count, and a person doubts the number they act on.
  testWidgets('a leaf subtitle counts one in the singular', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('olive')));
    await toTheOrganization(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('organization-people-subtitle'))).data,
      startsWith('6 people · 1 card waits'),
    );
    await toTheOrganization(tester, section: OrganizationSection.owners);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('organization-owners-subtitle'))).data,
      startsWith('1 owner · '),
    );
  });
  // Harm: phone actions for a machine project lose which inner list they affect.
  testWidgets('a phone keeps the machine project inner section titles', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    await World.templates.keep(
      const Template(name: 'Check API', project: 'checkout', agent: 'claude', mode: Mode.agent, prompt: ''),
    );
    World.shell.openProject(World.machines.current, 'checkout');
    await World.settle(tester);
    tester.view.physicalSize = const Size(390, 1600);
    addTearDown(tester.view.reset);
    await World.settle(tester);
    final scrollable = find
        .descendant(
          of: find.byKey(ValueKey('project-details ${World.machines.current.name}/checkout')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final title in ['Machines', 'Saved jobs']) {
      final text = find.byWidgetPredicate(
        (widget) => widget is Text && widget.key == const Key('leaf-title') && widget.data == title,
      );
      await tester.scrollUntilVisible(text, 200, scrollable: scrollable);
      expect(text.hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  // Harm: a state leaves its named row at the card-width boundary, inviting a decision on the wrong item.
  for (final width in [479.0, 480.0]) {
    testWidgets('a card places its state beside the name from 480 wide: $width', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: const SingleChildScrollView(
                  child: FilteredListSection(
                    title: 'Projects',
                    storageId: 'boundary',
                    leaf: true,
                    rows: [
                      (
                        words: 'demo',
                        child: ItemListRow(
                          title: 'demo',
                          subtitle: 'from the organization',
                          leading: Icon(Icons.folder_outlined),
                          state: 'held',
                          onOpen: null,
                          menu: SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final name = tester.getRect(find.text('demo'));
      final chip = tester.getRect(find.widgetWithText(Chip, 'held'));
      if (width >= 480) {
        expect(chip.left, greaterThanOrEqualTo(name.right));
        expect(chip.top, lessThan(name.bottom));
      } else {
        expect(chip.top, greaterThanOrEqualTo(name.bottom));
      }
      expect(tester.takeException(), isNull);
    });
  }

  // Harm: a review returns to a different list, losing the organization and work being reviewed.
  testWidgets('an organization project returns to the Projects leaf it came from', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('olive')));
    await toTheOrganization(tester, section: OrganizationSection.projects);
    final origin = World.shell.place.key;
    tester.widget<OrganizationPage>(find.byType(OrganizationPage)).onProject!('demo');
    await World.settle(tester);
    final path = find.byKey(const Key('leaf-path')).first;
    for (final ancestor in ['Organizations', 'acme', 'Projects']) {
      expect(find.descendant(of: path, matching: find.text(ancestor)), findsOneWidget);
    }
    final back = find.byKey(const Key('organization-project-back'));
    expect(back, findsOneWidget);
    expect(find.descendant(of: back, matching: find.text('Projects')), findsOneWidget);
    await tester.tap(back);
    await World.settle(tester);
    expect(World.shell.place.key, origin);
    expect(tester.widget<OrganizationPage>(find.byType(OrganizationPage)).section, OrganizationSection.projects);
    await toThePlace(tester, 'projects');
    tester.widget<OrganizationProjectsPage>(find.byType(OrganizationProjectsPage)).onProject('demo');
    await World.settle(tester);
    expect(find.widgetWithText(TextButton, 'My projects'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Projects'), findsNothing, reason: 'the old origin is cleared');
    expect(find.byKey(const Key('organization-project-back')), findsOneWidget);
    await tester.tap(find.byKey(const Key('organization-project-back')));
    await World.settle(tester);
    expect(find.byType(OrganizationProjectsPage), findsOneWidget);
  });

  // Harm: stale navigation sends a person back to an unrelated machine list after giving a token.
  testWidgets('a host returns to its current origin and forgets a previous organization leaf', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('olive')));
    await toTheOrganization(tester, section: OrganizationSection.machines);
    final origin = World.shell.place.key;
    tester.widget<OrganizationPage>(find.byType(OrganizationPage)).onHost!('build');
    await World.settle(tester);
    expect(find.widgetWithText(TextButton, 'Machines'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Machines'));
    await World.settle(tester);
    expect(World.shell.place.key, origin);
    // Open it once more, then leave by the tree rather than its back link.
    tester.widget<OrganizationPage>(find.byType(OrganizationPage)).onHost!('build');
    await World.settle(tester);
    await toThePlace(tester, 'projects');
    tester.widget<OrganizationProjectsPage>(find.byType(OrganizationProjectsPage)).onHost!('demo', 'build');
    await World.settle(tester);
    expect(find.byType(OrganizationHostPage), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'My projects'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Machines'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'My projects'));
    await World.settle(tester);
    expect(find.byType(OrganizationProjectsPage), findsOneWidget);
    await toThePlace(tester, 'attention');
    tester.widget<AttentionView>(find.byType(AttentionView)).onGiveToken!('build');
    await World.settle(tester);
    expect(find.widgetWithText(TextButton, 'Needs you'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Needs you'));
    await World.settle(tester);
    expect(find.byType(AttentionView), findsOneWidget);
  });

  // Harm: an unread or busy list falsely promises that there is nothing to act on.
  testWidgets('a busy open leaf never claims an empty list', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FilteredListSection(
              title: 'Forges',
              storageId: 'unread',
              leaf: true,
              subtitle: '0 entries',
              busy: true,
              rows: [],
            ),
          ),
        ),
      ),
    );
    expect(find.text('No forges yet.'), findsNothing);
    expect(find.text('not read'), findsOneWidget, reason: 'the head explains the missing rows');
    expect(find.text('Reading…'), findsOneWidget, reason: 'the open card says they are being read');
    expect(find.byKey(const Key('reading')), findsOneWidget, reason: 'the bar every reading view shows');
    expect(find.text('0 entries'), findsNothing);
  });

  // Harm: a list nobody is asking for reads as one being read, and the person waits for nothing.
  testWidgets('an unread leaf nobody is reading says not read, without a bar', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FilteredListSection(title: 'Forges', storageId: 'unread', leaf: true, read: false, rows: []),
          ),
        ),
      ),
    );
    expect(find.text('not read'), findsNWidgets(2), reason: 'both the head and the open card explain missing rows');
    expect(find.text('Reading…'), findsNothing);
    expect(find.byKey(const Key('reading')), findsNothing);
  });

  // Harm: the project machine has answered, but its chip tells the person that nothing was read.
  testWidgets('a project machine chip keeps its observed connection state', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.shell.openProject(World.machines.current, 'checkout');
    await World.settle(tester);
    final list = find.byWidgetPredicate((widget) => widget is FilteredListSection && widget.title == 'Machines');
    await tester.scrollUntilVisible(
      list,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(ValueKey('project-details ${World.machines.current.name}/checkout')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.descendant(of: list, matching: find.widgetWithText(Chip, 'Connected')), findsOneWidget);
    expect(find.descendant(of: list, matching: find.widgetWithText(Chip, 'not read')), findsNothing);
  });

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
