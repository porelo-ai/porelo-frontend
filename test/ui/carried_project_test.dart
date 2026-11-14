import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/start_agents.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/app/start_work.dart';
import 'package:porelo_frontend/src/app/templates.dart';
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

    // Harm: a template's button starts in a project this person has not taken, with no repository.
    testWidgets('a saved job takes it first', (tester) async {
      await _onTheMachine(tester, _carried());
      await World.templates.keep(
        const Template(name: 'nightly', project: 'foo', agent: 'an-agent', mode: Mode.agent, prompt: 'run'),
      );
      World.shell.openProject(World.machines.current, 'foo');
      await World.settle(tester);
      World.shell.show('template.start/foo/nightly', section: Section.project);
      await World.settle(tester);
      await tester.tap(find.byKey(const Key('highlighted')));
      await World.settle(tester);
      expect(World.backend.taken, <String>['foo']);
    });

    // Harm: *Delete* and the like are offered for a project with no file here to act on.
    testWidgets('what needs its file is not offered', (tester) async {
      await _onTheMachine(tester, _carried());
      await World.tapInView(tester, 'project-menu');
      for (final id in <String>['project.sync', 'project.backups', 'project.clear', 'project.delete']) {
        final found = find.byKey(Key(id));
        expect(found, findsOneWidget, reason: id);
        expect(tester.widget<PopupMenuItem<String>>(found).enabled, isFalse, reason: id);
      }
    });

    // Harm: the project's page says it is not here, on the machine that carries it.
    testWidgets('its page does not say it is not on this machine', (tester) async {
      await _onTheMachine(tester, _carried());
      World.shell.openProject(World.machines.current, 'foo');
      await World.settle(tester);
      expect(find.textContaining('not on this machine'), findsNothing);
      expect(find.textContaining('environment not prepared'), findsNothing);
    });
  });
  group("a carried project's room before its first task", () {
    Project carriedWithRoom() => Project.from(<String, dynamic>{
      'name': 'foo',
      'carried': true,
      'messages': <String, dynamic>{
        'transport': 'matrix',
        'conversation': '!foo:host',
        'reaches': <String>[],
        'ready': false,
        'detail': 'set up when you set it up or the first task starts',
      },
    });

    // Harm: the room button is offered as if the room were there, and pressing it opens nothing a person can use,
    // or it takes the project without saying so.
    testWidgets('its button says it sets the room up and takes the project, and then opens the room', (tester) async {
      await _onTheMachine(tester, carriedWithRoom());
      final button = find.byKey(const Key('project-room'));
      expect(
        find.descendant(of: button, matching: find.text('Set up the room, taking the project here')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Tooltip && widget.message == 'set up when you set it up or the first task starts',
        ),
        findsOneWidget,
      );
      await World.tapInView(tester, 'project-room');
      expect(World.backend.roomsSetUp, <String>['foo']);
      expect(World.backend.taken, <String>['foo']);
      expect(find.byKey(const Key('messages-dialog')), findsOneWidget);
    });

    // Harm: a refused set-up leaves the person guessing, or opens a room that is not there.
    testWidgets("a refused set-up says the machine's words and opens no room", (tester) async {
      await _onTheMachine(tester, carriedWithRoom());
      World.backend.roomRefused = 'the forge refused the take';
      await World.tapInView(tester, 'project-room');
      expect(find.textContaining('the forge refused the take'), findsWidgets);
      expect(find.byKey(const Key('messages-dialog')), findsNothing);
    });

    // Harm: a room still not ready after the take opens empty, or nobody is told why.
    testWidgets('a room not ready after the take says why and opens nothing', (tester) async {
      await _onTheMachine(tester, carriedWithRoom());
      World.backend.roomNotReady = 'the homeserver did not answer';
      await World.tapInView(tester, 'project-room');
      expect(find.textContaining("foo's room is not ready yet: the homeserver did not answer"), findsWidgets);
      expect(find.byKey(const Key('messages-dialog')), findsNothing);
    });
  });
}
