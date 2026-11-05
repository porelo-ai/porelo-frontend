import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

void main() {
  // Harm: a fold undone by each restart, and the explanation read again every morning.
  test('a folded explanation stays folded across a restart, and the others do not', () async {
    final store = MemorySettingsStore();
    final before = Settings(store);
    await before.load();
    expect(before.explanationsFolded, isEmpty);
    await before.setExplanationFolded('work', folded: true);

    final after = Settings(store);
    await after.load();
    expect(after.explanationsFolded, <String>{'work'});
  });

  // Harm: a small window that overflows under the explanation, open or folded.
  testWidgets('the explanation fits a small window', (tester) async {
    tester.view.physicalSize = const Size(480, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await World.startBackend(World.work);
    await World.startApp(tester);
    for (final section in <Section>[Section.work, Section.attention, Section.machines]) {
      World.shell.goTo(section);
      await World.settle(tester);
      expect(tester.takeException(), isNull);
    }
  });

  // Harm: a page that says nothing of what it is for, or an explanation closed once and gone for good.
  for (final (section, id, question, words) in <(Section, String, String, String)>[
    (Section.work, 'work', 'What is Work?', 'All work on your machines'),
    (Section.attention, 'needs-you', 'What is Needs you?', 'What waits for a person'),
    (Section.machines, 'machines', 'What is in My machines?', 'Where work runs'),
    (Section.forges, 'forges', 'What is in My forges?', 'Where your repositories are'),
    (Section.projects, 'projects', 'What is in My projects?', 'How work runs'),
    (Section.organization, 'organization', 'What is the Porelo organization?', 'Who manages it'),
  ]) {
    testWidgets('$question folds, and opens again', (tester) async {
      await World.startBackend(World.work);
      await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('pat')));
      World.shell.goTo(section);
      await World.settle(tester);
      expect(find.text(question), findsOneWidget);
      expect(find.textContaining(words), findsOneWidget);
      final fold = find.byKey(ValueKey<String>('explanation-fold $id'));
      expect(fold, findsOneWidget);

      await tester.tap(fold);
      await World.settle(tester);
      expect(fold, findsNothing);
      expect(find.text(question), findsOneWidget, reason: 'it folds, and is never removed');
      expect(find.textContaining(words), findsNothing);
      expect(World.settings.explanationsFolded, contains(id));

      await tester.tap(find.byKey(ValueKey<String>('explanation-open $id')));
      await World.settle(tester);
      expect(fold, findsOneWidget);
      expect(find.textContaining(words), findsOneWidget);
      expect(World.settings.explanationsFolded, isNot(contains(id)));
    });
  }
}
