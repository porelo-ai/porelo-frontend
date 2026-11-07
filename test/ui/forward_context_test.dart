import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../features/support/world.dart';
import '../features/step/the_forge_refuses_the_push_for_its_deploy_key.dart';
import '../features/step/i_keep_the_key.dart';

// Harm: a forward goes to a different branch than the task's, or a refused choice replaces the last confirmed one.
void main() {
  late Project project;
  late GateState pending;

  Future<void> openPush(WidgetTester tester) async {
    World.backend.theGate = pending;
    await World.gate.lookAt(World.backend, project);
    await World.gate.look(World.backend, World.gate.waiting.single);
    World.shell.openReview();
    await World.settle(tester);
    await tester.tap(find.text(project.name == defaultProject ? 'Forward it to its origin…' : 'Forward it upstream…'));
    await World.settle(tester);
  }

  Future<void> start(WidgetTester tester, {String forgeBranch = '', String projectName = 'checkout'}) async {
    await World.startBackend([
      Task.from({
        'name': 'container-with-a-different-name',
        'task': 'migrate',
        'project': projectName,
        'repository': '',
        'forgeBranch': forgeBranch,
      }),
      Task.from({
        'name': 'unrelated-container',
        'task': 'migrate',
        'project': 'billing',
        'repository': 'checkout',
        'forgeBranch': 'wrong-project',
      }),
    ]);
    project = Project.from({
      'name': projectName,
      'file': '/srv/checkout/project.yml',
      'repositories': [
        {'name': 'checkout', 'own': true, 'upstream': 'git@forge.example.org:acme/money.git'},
      ],
    });
    World.backend.theProjectsItHas = [project];
    pending = World.backend.theGate;
    await World.startApp(tester);
    await openPush(tester);
  }

  testWidgets('a task branch names its destination and sends only the edited choice', (tester) async {
    await start(tester, forgeBranch: 'porelo/sluice');
    expect(find.text('To forge.example.org acme/money'), findsOneWidget);
    expect(find.text("this task's branch"), findsOneWidget);
    final field = find.byKey(const Key('forward-new-branch'));
    expect(tester.widget<TextField>(field).controller!.text, 'porelo/sluice');
    expect(World.backend.approvals, isEmpty);
    await tester.enterText(field, 'fix-2');
    await tester.tap(find.widgetWithText(FilledButton, 'Forward it'));
    await World.settle(tester);
    expect(World.backend.approvals.single.branch, 'fix-2');
    await openPush(tester);
    expect(tester.widget<TextField>(field).controller!.text, 'porelo/sluice', reason: 'the task branch has priority');
  });

  testWidgets('a Default task without a repository keeps its forge branch', (tester) async {
    await start(tester, forgeBranch: 'porelo/sluice', projectName: defaultProject);
    expect(find.text("To the repository's origin"), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('forward-new-branch'))).controller!.text, 'porelo/sluice');
    expect(World.backend.approvals, isEmpty);
  });

  testWidgets('the next push recalls only the last confirmed branch for this task', (tester) async {
    await start(tester);
    final field = find.byKey(const Key('forward-new-branch'));
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    await tester.enterText(field, 'fix-2');
    await tester.tap(find.widgetWithText(FilledButton, 'Forward it'));
    await World.settle(tester);
    final reopened = Settings(World.store);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.lastForwardedBranch(World.machines.current.name, 'checkout', 'checkout', 'migrate'), 'fix-2');
    await openPush(tester);
    expect(tester.widget<TextField>(field).controller!.text, 'fix-2');
    expect(find.text('last used for this task'), findsOneWidget);
    await tester.enterText(field, 'cancelled');
    await tester.tap(find.text('Cancel'));
    await World.settle(tester);
    await openPush(tester);
    expect(tester.widget<TextField>(field).controller!.text, 'fix-2');
    World.backend.refuseTheGate = const VarlinkException('org.fuin.porelo.Tasks1.BranchExists', {
      'branch': 'refused',
      'at': 'abcdef0',
    });
    await tester.enterText(field, 'refused');
    await tester.tap(find.widgetWithText(FilledButton, 'Forward it'));
    await World.settle(tester);
    World.backend.refuseTheGate = null;
    await openPush(tester);
    expect(tester.widget<TextField>(field).controller!.text, 'fix-2');
    final afterRefusal = Settings(World.store);
    addTearDown(afterRefusal.dispose);
    await afterRefusal.load();
    expect(afterRefusal.lastForwardedBranch(World.machines.current.name, 'checkout', 'checkout', 'migrate'), 'fix-2');
    expect(World.backend.approvals, hasLength(1));
  });

  testWidgets('a refused key saves no branch until keeping a key confirms the retry', (tester) async {
    await start(tester);
    await theForgeRefusesThePushForItsDeployKey(tester);
    await tester.enterText(find.byKey(const Key('forward-new-branch')), 'fix-2');
    await tester.tap(find.widgetWithText(FilledButton, 'Forward it'));
    await World.settle(tester);
    final beforeRetry = Settings(World.store);
    addTearDown(beforeRetry.dispose);
    await beforeRetry.load();
    expect(beforeRetry.lastForwardedBranch(World.machines.current.name, 'checkout', 'checkout', 'migrate'), isNull);
    expect(World.backend.approvals, isEmpty);
    await iKeepTheKey(tester, 'SHA256:personalKeyOfThePerson');
    expect(World.backend.approvals.single.branch, 'fix-2');
    final afterRetry = Settings(World.store);
    addTearDown(afterRetry.dispose);
    await afterRetry.load();
    expect(afterRetry.lastForwardedBranch(World.machines.current.name, 'checkout', 'checkout', 'migrate'), 'fix-2');
    await openPush(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('forward-new-branch'))).controller!.text, 'fix-2');
  });
}
