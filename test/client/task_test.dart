import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

/// What a task says about its own work at the gate, held to the contract rather than to a screen.
///
/// **There is no join to make here, and that is the whole point.** `Task.name` is a *container*
/// name and `PendingPush.name` is a *task* name; several containers over time push to one ref, so
/// anything lined up from the two would be right for at most one of them. Porelo offered a field
/// pointing the other way, went to build it, and withdrew it for exactly that reason.
void main() {
  Task taskWith(Map<String, dynamic> fields) => Task.from(<String, dynamic>{
        'name': 'porelo-checkout-migrate',
        'project': 'checkout',
        'securityClass': 'guarded',
        'state': 'Exited (0) 12 minutes ago',
        'running': false,
        'helpers': 0,
        ...fields,
      });

  test('a task whose own ref is waiting says so', () {
    final task = taskWith(<String, dynamic>{'waiting': 1});

    expect(task.hasWorkWaiting, isTrue);
    expect(task.atTheGate, 'its own work is waiting for review');
  });

  test('a gated task with nothing waiting says nothing of its own is', () {
    final task = taskWith(<String, dynamic>{'waiting': 0});

    expect(task.hasWorkWaiting, isFalse);
    expect(task.atTheGate, 'nothing of its own is waiting');
  });

  test('an online task is told apart from a gated one with nothing waiting', () {
    // The contract's own words: zero here is not a smaller number, it is a question the class
    // does not have. Saying "nothing of its own is waiting" would imply something could be.
    final task = taskWith(<String, dynamic>{
      'securityClass': 'online',
      'waiting': 0,
    });

    expect(task.atTheGate, 'nothing is reviewed in an online project');
  });

  test('a task from a backend that never had the field reads as nothing waiting', () {
    // Absence is a normal state, not an error: every task started before the field existed
    // answers nothing at all, and inventing a one would claim work was waiting.
    final task = taskWith(const <String, dynamic>{});

    expect(task.waiting, 0);
    expect(task.hasWorkWaiting, isFalse);
  });
}
