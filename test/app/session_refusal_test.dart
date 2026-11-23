import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/pty.dart';
import 'package:porelo_frontend/src/app/session.dart';

void main() {
  // Harm: a program on this computer that cannot start sends the person looking for a container that does not exist,
  // while the missing program goes unsaid.
  const here = Machine(name: 'laptop', socketPath: '');
  Never refused(String executable, List<String> arguments, {int columns = 80, int rows = 24}) =>
      throw PtyRefused('$executable cannot be run');

  test('a program on this computer that cannot start names the program and no container', () {
    final session = Session(task: 'vault', machine: here, open: refused, run: const ['/no/such/porelo-host', 'key']);
    addTearDown(session.dispose);

    expect(session.problem, contains('/no/such/porelo-host'));
    expect(session.problem, isNot(contains('container')));
  });

  test("a task's session that cannot be opened says it lives in the container", () {
    final session = Session(task: 'demo', machine: here, open: refused);
    addTearDown(session.dispose);

    expect(session.problem, contains('container'));
  });
}
