import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

void main() {
  // Harm: a page left on another machine can show one target while commands act on the current one.
  test('legacy and finder navigation release explicit item selection', () {
    final shell = ShellModel();
    addTearDown(shell.dispose);
    const machine = Machine(name: 'first', socketPath: '/first');
    shell.openProject(machine, 'checkout');
    shell.goTo(Section.project);
    expect(shell.itemMachine, isNull);
    expect(shell.itemProject, isNull);
    shell.openProject(machine, 'checkout');
    shell.show('project.messages', section: Section.project);
    expect(shell.itemMachine, isNull);
    expect(shell.itemProject, isNull);
  });
}
