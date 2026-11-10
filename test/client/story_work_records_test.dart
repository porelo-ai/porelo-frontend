import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

void main() {
  // Harm: With you opens a blank or stopped task from a malformed start answer.
  test('terminal selection rejects missing names and stopped tasks', () {
    for (final task in <Map<String, dynamic>>[
      {},
      {'task': 'stopped', 'role': 'MAIN', 'atWork': false},
      {'task': '', 'role': 'MAIN', 'atWork': true},
    ]) {
      expect(
        StoryWorkStarted.from({
          'work': {
            'atWork': true,
            'tasks': [task],
          },
          'revision': 'r1',
        }).terminalTask,
        isNull,
      );
      expect(
        StoryWorkStarted.from({
          'work': {
            'atWork': true,
            'tasks': [task],
          },
          'revision': 'r1',
        }).terminalTask,
        isNull,
      );
    }
    expect(
      StoryWorkStarted.from({
        'work': {
          'atWork': true,
          'tasks': [
            {'task': 'valid', 'role': 'MAIN', 'atWork': true},
          ],
        },
        'revision': 'r1',
      }).terminalTask!.name,
      'valid',
    );
  });
}
