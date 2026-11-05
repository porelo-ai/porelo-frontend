import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

void main() {
  // Harm: an explanation that comes back every morning, or that opens nowhere after its first time.
  test('an explanation seen stays seen across a restart, and the others do not', () async {
    final store = MemorySettingsStore();
    final before = Settings(store);
    await before.load();
    expect(before.explanationsSeen, isEmpty);
    await before.markExplanationSeen('work');

    final after = Settings(store);
    await after.load();
    expect(after.explanationsSeen, <String>{'work'});
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
    testWidgets('$question stands open the first time, and after that behind its i', (tester) async {
      await World.startBackend(World.work);
      await World.startApp(tester, organizationSource: FixtureOrganization(organizationFor('pat')));
      World.shell.goTo(section);
      await World.settle(tester);
      final info = find.byKey(ValueKey<String>('explanation-open $id'));
      expect(find.text(question), findsOneWidget, reason: 'the first time');
      expect(find.textContaining(words), findsOneWidget);
      expect(info, findsOneWidget);

      // Gone from the page, and back.
      World.shell.goTo(section == Section.forges ? Section.machines : Section.forges);
      await World.settle(tester);
      World.shell.goTo(section);
      await World.settle(tester);
      expect(find.textContaining(words), findsNothing, reason: 'once');
      expect(info, findsOneWidget);

      await tester.tap(info);
      await World.settle(tester);
      expect(find.textContaining(words), findsOneWidget);
      await tester.tap(find.byKey(ValueKey<String>('explanation-fold $id')));
      await World.settle(tester);
      expect(find.textContaining(words), findsNothing);
      expect(info, findsOneWidget);
    });
  }
}
