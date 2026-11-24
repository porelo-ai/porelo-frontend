import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/task_names.dart';

void main() {
  // Harm: the window refusing a name porelod takes, so no work can start under it; or sending one too long for porelod's
  // container name, refused only after the start was made.
  group('a new task\'s name is measured as the container porelod gives it', () {
    String named(int length) => 'a' * length;

    test('in project porelo, porelo_<name>', () {
      final fits = longestContainerName - 'porelo_'.length;
      expect(taskNameProblem(named(fits), project: 'porelo'), isNull);
      expect(taskNameProblem(named(fits + 1), project: 'porelo'), isNotNull);
    });

    test('in any other project, porelo-<project>_<name>', () {
      final fits = longestContainerName - 'porelo-checkout_'.length;
      expect(taskNameProblem(named(fits), project: 'checkout'), isNull);
      expect(taskNameProblem(named(fits + 1), project: 'checkout'), isNotNull);
    });
  });

  // Harm: a name whose container is 65 characters long sent to porelod, whose container names end at 64 so the
  // ssh-agent socket path fits, refused only after the start was made.
  test('a container name of 64 characters is taken and one of 65 refused', () {
    expect(taskNameProblem('a' * (64 - 'porelo_'.length), project: 'porelo'), isNull);
    expect(taskNameProblem('a' * (65 - 'porelo_'.length), project: 'porelo'), isNotNull);
    expect(taskNameProblem('a' * (65 - 'porelo-checkout_'.length), project: 'checkout'), isNotNull);
  });

  // Harm: a start under a name Porelo keeps for itself sent to porelod, refused only after the start was made; or a
  // repository named like one suggested as the task's name.
  test('the names Porelo keeps for itself are refused, and a repository named so suggests work', () {
    for (final reserved in ['people', 'person', 'review']) {
      expect(taskNameProblem(reserved, project: 'checkout'), contains('Porelo keeps'), reason: reserved);
      expect(suggestedTaskName(reserved, const <String>{}), 'work', reason: reserved);
    }
    expect(taskNameProblem('reviews', project: 'checkout'), isNull);
    expect(suggestedTaskName('Review', const <String>{'work'}), 'work-2');
  });
}
