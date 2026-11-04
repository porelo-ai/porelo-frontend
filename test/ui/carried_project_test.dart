import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/start_agents.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/start_work.dart';
import 'package:porelo_frontend/src/ui/start_agents_view.dart';

import '../features/support/world.dart';

Project _carried([String name = 'foo']) => Project.from(<String, dynamic>{'name': name, 'carried': true});

Future<void> _onTheMachine(WidgetTester tester, Project project) async {
  await World.startBackend(World.work);
  World.backend.theProjectsItHas = <Project>[project];
  await World.startApp(tester);
  await World.fleet.refresh(quietly: true);
  World.fleet.selectProject(project.name);
  World.shell.goTo(Section.project);
  await World.settle(tester);
}

void main() {
  group('a project a machine carries and this person has not taken yet', () {
    test('a daemon that does not say reads as not carried', () {
      expect(Project.from(<String, dynamic>{'name': 'foo'}).carried, isFalse);
      expect(_carried().carried, isTrue);
      expect(_carried().canBeActedOn, isFalse);
    });

    // Harm: the row says the project is not on the machine that carries it, and offers nothing.
    test('work and the agents can be asked for', () {
      expect(StartWork.whyNot(_carried()), isNull);
      expect(StartAgents.whyNot(_carried()), isNull);
      expect(StartWork.whyNot(Project.from(<String, dynamic>{'name': 'gone'})), isNotNull);
    });

    // Harm: the list waits for a first start, and the first start waits for the list.
    testWidgets('Start work takes it, and the form opens on it', (tester) async {
      await _onTheMachine(tester, _carried());
      await World.tapInView(tester, 'project-menu');
      await World.tapInView(tester, 'work.start');
      expect(World.backend.taken, <String>['foo']);
      expect(World.starting.project?.name, 'foo');
    });

    // Harm: a person is told nothing when the machine refuses, and the press seems lost.
    testWidgets('a refused take says the machine\'s words, and opens no form', (tester) async {
      await _onTheMachine(tester, _carried());
      World.backend.takeAnswers = const TakenProject(reason: 'cannot-say', words: 'The forge did not answer.');
      await World.tapInView(tester, 'project-menu');
      await World.tapInView(tester, 'work.start');
      expect(find.textContaining('The forge did not answer.'), findsWidgets);
      expect(World.starting.project, isNull);
    });

    // Harm: an older Porelo fails with a programmer's word.
    testWidgets('a Porelo with no take says it needs a newer one', (tester) async {
      await _onTheMachine(tester, _carried());
      World.backend.takesNoProject = true;
      await World.tapInView(tester, 'project-menu');
      await World.tapInView(tester, 'work.start');
      expect(find.textContaining('newer Porelo'), findsWidgets);
    });

    // Harm: the wizard opens empty for a project whose rows name no agent.
    testWidgets('the wizard takes it, then says what its rows lack', (tester) async {
      await _onTheMachine(tester, _carried());
      await World.tapInView(tester, 'project-menu');
      await World.tapInView(tester, 'project.startAgents');
      expect(World.backend.taken, <String>['foo']);
      expect(find.byType(StartAgentsWizard), findsNothing);
      expect(find.textContaining('which agent'), findsWidgets);
    });
  });
}
