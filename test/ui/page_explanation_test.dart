import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/organization_project_pages.dart';
import 'package:porelo_frontend/src/ui/page_explanation.dart';

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

  // Harm: an explanation someone closed comes open again after the upgrade.
  test('one folded in the version before counts as seen', () async {
    final store = MemorySettingsStore();
    await store.write(<String, Object?>{
      'explanationsFolded': <String>['work'],
    });
    final settings = Settings(store);
    await settings.load();
    expect(settings.explanationsSeen, <String>{'work'});
  });

  // Harm: a small window that overflows under the explanation, open or folded.
  testWidgets('the explanation fits a small window', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    // After the start, which sets a window of its own.
    tester.view.physicalSize = const Size(480, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await World.settle(tester);
    expect(tester.getSize(find.byType(Scaffold).first).width, 480);
    for (final (section, id) in <(Section, String)>[
      (Section.work, 'work'),
      (Section.attention, 'needs-you'),
      (Section.machines, 'machines'),
    ]) {
      World.shell.goTo(section);
      await World.settle(tester);
      expect(tester.takeException(), isNull, reason: '$id open');
      await tester.ensureVisible(find.byKey(ValueKey<String>('explanation-fold $id')));
      await tester.tap(find.byKey(ValueKey<String>('explanation-fold $id')));
      await World.settle(tester);
      expect(tester.takeException(), isNull, reason: '$id folded');
    }
  });

  // Harm: a page that says nothing of what it is for, or an explanation closed once and gone for good.
  for (final (section, id, question, words) in <(Section, String, String, String)>[
    (Section.work, 'work', 'What is Work?', 'All work on your machines'),
    (Section.attention, 'needs-you', 'What is Needs you?', 'What waits for a person'),
    (Section.machines, 'machines', 'What is in My machines?', 'Where work runs'),
    (Section.forges, 'forges', 'What is in My forges?', 'Where your repositories are'),
    (Section.projects, 'projects', 'What is in My projects?', 'How work runs'),
    (Section.organizations, 'organizations', 'What is the Porelo organization?', 'Who manages it'),
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

  // Harm: a person cannot find the explanation or has to close it after each restart.
  testWidgets('the i belongs to the large title and a folded explanation survives restart', (tester) async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    await settings.load();
    Widget page(Settings kept) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            PageHead(title: 'My forges', id: 'forges', settings: kept),
            PageExplanation(
              id: 'forges',
              settings: kept,
              parts: const [(title: 'Where repositories live', words: 'Repositories on your forges.')],
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(page(settings));
    await tester.pump();
    final head = find.byType(PageHead);
    expect(find.descendant(of: head, matching: find.byIcon(Icons.info_outline)), findsOneWidget);
    final title = tester.widget<Text>(find.text('My forges'));
    expect(title.style, Theme.of(tester.element(head)).textTheme.headlineSmall);
    await tester.tap(find.byKey(const Key('explanation-fold forges')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    final restarted = Settings(store);
    await restarted.load();
    await tester.pumpWidget(page(restarted));
    await tester.pump();
    expect(find.text('Repositories on your forges.'), findsNothing);
    await tester.tap(find.byKey(const Key('explanation-open forges')));
    await tester.pump();
    expect(find.text('Repositories on your forges.'), findsOneWidget);
  });

  // Harm: an explanation closed before anything was read, and no way to open it again.
  testWidgets('My projects keeps its i with nothing read yet', (tester) async {
    final organization = Organization(
      FixtureOrganization(organizationFor('pat'))..refuseReads = const OrganizationRefused('not reached'),
    );
    addTearDown(organization.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageExplanationScope(
            title: 'My projects',
            id: 'projects',
            settings: Settings(MemorySettingsStore()),
            child: OrganizationProjectsPage(organization: organization, onProject: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('explanation-open projects')), findsOneWidget);
  });
}
