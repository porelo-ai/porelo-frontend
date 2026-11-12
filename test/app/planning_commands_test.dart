import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_planning/porelo_planning.dart' show PlanningAction, PlanningWayOn;

void main() {
  // Harm: the finder runs the held action itself from its way on, or offers the way on as if it were the action.
  test('an unavailable action with a way on lists both, and the way on runs its own step alone', () {
    final ran = <String>[];
    final commands = planningActionCommands([
      PlanningAction(
        id: 'planning.start/ST1',
        label: 'Start ST1',
        unavailable: 'A run needs attention.',
        run: () => ran.add('action'),
        wayOn: PlanningWayOn(label: 'Open the run that needs attention', run: () => ran.add('way on')),
      ),
    ]);

    expect(
      [for (final command in commands) (command.id, command.label, command.group, command.unavailable)],
      [
        ('planning.start/ST1', 'Start ST1', 'Planning', 'A run needs attention.'),
        ('planning.start/ST1 way-on', 'Open the run that needs attention', 'Planning', null),
      ],
      reason: 'the action stays listed with why, and its way on is an entry of its own that runs',
    );
    commands.last.run();
    expect(ran, ['way on'], reason: 'the way on never runs the action it leads around');
  });

  // Harm: a runnable action is shadowed by a second entry that leads elsewhere.
  test('an available action with a way on lists the action alone', () {
    final commands = planningActionCommands([
      PlanningAction(
        id: 'planning.start/ST1',
        label: 'Start ST1',
        run: () {},
        wayOn: PlanningWayOn(label: 'Open the run that needs attention', run: () {}),
      ),
    ]);

    expect([for (final command in commands) command.id], ['planning.start/ST1']);
  });

  // Harm: an action without a way on loses its entry or its reason, gains a way on of another, or a way on leaves the
  // action it leads around and stands beside another.
  test('an action without a way on lists as before, and a way on stays beside its own action', () {
    final commands = planningActionCommands([
      PlanningAction(id: 'planning.open/ST1', label: 'Open story ST1', unavailable: 'Not watched.', run: () {}),
      PlanningAction(
        id: 'planning.start/ST2',
        label: 'Start ST2',
        unavailable: 'A run needs attention.',
        run: () {},
        wayOn: PlanningWayOn(label: 'Open the run that needs attention', run: () {}),
      ),
      PlanningAction(id: 'planning.open/ST3', label: 'Open story ST3', unavailable: 'Not watched.', run: () {}),
      PlanningAction(id: 'planning.open/ST4', label: 'Open story ST4', run: () {}),
    ]);

    expect(
      [for (final command in commands) (command.id, command.label, command.unavailable)],
      [
        ('planning.open/ST1', 'Open story ST1', 'Not watched.'),
        ('planning.start/ST2', 'Start ST2', 'A run needs attention.'),
        ('planning.start/ST2 way-on', 'Open the run that needs attention', null),
        ('planning.open/ST3', 'Open story ST3', 'Not watched.'),
        ('planning.open/ST4', 'Open story ST4', null),
      ],
    );
  });
}
