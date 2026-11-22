import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

void main() {
  // Harm: a navigation entry point bypasses the unsaved-work question and changes the current page.
  test('all navigation entry points can be refused and explicitly resumed', () {
    final machine = Machine(name: 'demo', socketPath: '');
    final actions = <(void Function(ShellModel), Section)>[
      ((shell) => shell.goTo(Section.work), Section.work),
      ((shell) => shell.choosePlace(const ShellPlace(Section.work)), Section.work),
      ((shell) => shell.openMachine(machine), Section.machine),
      ((shell) => shell.openProject(machine, 'demo'), Section.project),
      ((shell) => shell.show('test', section: Section.work), Section.work),
    ];
    for (final action in actions) {
      final shell = ShellModel()..goTo(Section.planning);
      void Function()? resume;
      shell.beforeNavigation = (destination, next) {
        expect(destination, action.$2);
        resume = next;
        return false;
      };
      action.$1(shell);
      expect(shell.section, Section.planning);
      expect(shell.place.section, Section.planning);
      expect(shell.itemMachine, isNull);
      expect(resume, isNotNull);
      shell.beforeNavigation = null;
      resume!();
      expect(shell.section, action.$2);
      shell.dispose();
    }
  });

  // Harm: a story's row under the folded Planning branch is hidden, and is hidden again after a restart.
  test('planning is an ancestor and a saved fold, as the branch that holds its views', () {
    final shell = ShellModel();
    shell.choosePlace(const ShellPlace(Section.planning, project: 'demo', planningSource: 'local', story: 'sample'));
    shell.revealPlace();
    expect(shell.place.ancestors, contains('planning'));
    expect(shell.navigation['folded'], contains('planning'));
    shell.dispose();
  });
}
