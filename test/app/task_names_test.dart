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
}
