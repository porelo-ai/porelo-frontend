import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/planning_embedding.dart';
import 'package:porelo_planning/porelo_planning.dart';

void main() {
  // Harm: With you opens a blank or stopped task from a malformed start answer.
  test('terminal selection rejects missing names and stopped tasks', () {
    for (final task in <Map<String, dynamic>>[
      {},
      {'task': 'stopped', 'role': 'MAIN', 'atWork': false},
      {'task': '', 'role': 'MAIN', 'atWork': true},
    ]) {
      expect(
        startedTerminal(
          StoryWorkStarted.from({
            'work': {
              'atWork': true,
              'tasks': [task],
            },
            'revision': 'r1',
          }),
          'demo',
        ),
        isNull,
      );
    }
    final started = startedTerminal(
      StoryWorkStarted.from({
        'work': {
          'atWork': true,
          'tasks': [
            {'task': 'valid', 'role': 'MAIN', 'atWork': true},
          ],
        },
        'revision': 'r1',
      }),
      'demo',
    );
    expect(started!.name, 'valid');
    expect(started.project, 'demo');
    expect(started.running, isTrue);
    expect(startedTerminal(null, 'demo'), isNull);
  });
}
