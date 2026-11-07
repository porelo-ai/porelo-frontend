import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/organization_dialogs.dart';

import '../features/support/world.dart' show World;
import '../support/organization_fixtures.dart';

const _repositories = [
  ProjectRepository(
    name: 'sluice',
    central: 'https://forge.example.org/acme/porelo-message-sluice.git',
    address: 'git@forge.example.org:acme/local-sluice.git',
  ),
  ProjectRepository(name: 'core', address: 'git@forge.example.org:acme/porelo-core.git'),
  ProjectRepository(name: 'docs', central: '', address: 'https://forge.example.org/acme/porelo-docs.git'),
  ProjectRepository(name: 'local'),
];

Finder _row(String key) => find.byKey(Key('organization-carry-repository-$key'));
Finder _control(String key) => find.byKey(Key('organization-carry-$key'));
Finder _confirm() => find.byKey(const Key('organization-confirm'));

Future<void> _pump(WidgetTester tester) => World.settle(tester);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _pump(tester);
  await tester.tap(finder);
  await _pump(tester);
}

Future<FixtureOrganization> _open(WidgetTester tester, {bool carriedElsewhere = false}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final source = FixtureOrganization(
    organizationFor(
      'hana',
      host: OrganizationHost(
        name: 'build',
        admins: const ['hana'],
        projects: carriedElsewhere ? const ['other'] : const [],
        repositories: carriedElsewhere
            ? const {
                'other': ['sluice'],
              }
            : const {},
      ),
    ),
  )..projects['other'] = const ProjectView(name: 'other', revision: 'p2', repositories: _repositories);
  final organization = Organization(source);
  addTearDown(organization.dispose);
  await organization.refresh();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(putProjectOnAMachine(context, organization: organization, project: 'other')),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await _tap(tester, find.text('Open'));
  await _tap(tester, find.byKey(const Key('organization-person')));
  await _tap(tester, find.text('build').hitTestable());
  await _tap(tester, _control('some'));
  return source;
}

/// Guards repository placement against sending a different selection than the person made.
void main() {
  // Harm: choosing by a full name sends the wrong repository or the whole project.
  testWidgets('searching by the full name sends only the checked repository key', (tester) async {
    final source = await _open(tester);
    expect(find.text('porelo-message-sluice'), findsOneWidget);
    expect(find.descendant(of: _row('sluice'), matching: find.text('sluice')), findsOneWidget);
    expect(find.text('porelo-core'), findsOneWidget);
    expect(find.text('porelo-docs'), findsOneWidget);
    expect(find.descendant(of: _row('local'), matching: find.text('local')), findsOneWidget);

    await tester.enterText(_control('search'), 'MESSAGE-SLUICE');
    await _pump(tester);
    expect(_row('sluice'), findsOneWidget);
    expect(_row('core'), findsNothing);
    await tester.enterText(_control('search'), 'sluice');
    await _pump(tester);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await _tap(tester, _row('sluice'));
    await _tap(tester, _confirm());
    expect(source.writes.single.change, OrganizationChange.addProjectToHost);
    expect(source.writes.single.input, {'host': 'build', 'project': 'other', 'repositories': 'sluice'});
  });

  // Harm: bulk selection silently adds or clears repositories hidden by a search.
  testWidgets('All and None change only visible rows and preserve hidden selections', (tester) async {
    final source = await _open(tester);
    await tester.enterText(_control('search'), 'CORE');
    await _pump(tester);
    expect(_row('core'), findsOneWidget);
    expect(_row('sluice'), findsNothing);
    await _tap(tester, _control('whole'));
    await _tap(tester, _control('some'));
    expect(find.text('CORE'), findsOneWidget);
    expect(_row('core'), findsOneWidget);
    expect(_row('sluice'), findsNothing);
    await _tap(tester, _control('all'));
    await tester.enterText(_control('search'), 'sluice');
    await _pump(tester);
    await _tap(tester, _control('all'));
    await _tap(tester, _control('none'));
    await tester.enterText(_control('search'), 'no-match');
    await _pump(tester);
    expect(find.text('No repositories match your search.'), findsOneWidget);
    await _tap(tester, _control('none'));
    await tester.enterText(_control('search'), '');
    await _pump(tester);
    expect(tester.widget<CheckboxListTile>(_row('core')).value, isTrue);
    expect(tester.widget<CheckboxListTile>(_row('sluice')).value, isFalse);
    expect(tester.widget<CheckboxListTile>(_row('docs')).value, isFalse);
    expect(tester.widget<CheckboxListTile>(_row('local')).value, isFalse);
    await _tap(tester, _confirm());
    expect(source.writes.single.input, {'host': 'build', 'project': 'other', 'repositories': 'core'});
  });

  // Harm: an already carried repository is sent to a second machine, or an empty choice is submitted.
  testWidgets('carried rows cannot be selected and an empty selection cannot be submitted', (tester) async {
    final source = await _open(tester, carriedElsewhere: true);
    expect(find.descendant(of: _row('sluice'), matching: find.textContaining('build')), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(_row('sluice')).onChanged, isNull);
    expect(tester.widget<ChoiceChip>(_control('whole')).onSelected, isNull);
    await _tap(tester, _row('sluice'));
    expect(tester.widget<FilledButton>(_confirm()).onPressed, isNull);
    expect(find.text('Choose at least one repository.'), findsOneWidget);
    await _tap(tester, _control('all'));
    expect(tester.widget<CheckboxListTile>(_row('sluice')).value, isFalse);
    expect(tester.widget<FilledButton>(_confirm()).onPressed, isNotNull);
    await _tap(tester, _control('none'));
    expect(tester.widget<FilledButton>(_confirm()).onPressed, isNull);
    expect(find.text('Choose at least one repository.'), findsOneWidget);
    await _tap(tester, _confirm());
    expect(source.writes, isEmpty);
    await _tap(tester, _row('core'));
    await _tap(tester, _confirm());
    expect(source.writes.single.input, {'host': 'build', 'project': 'other', 'repositories': 'core'});
  });
}
