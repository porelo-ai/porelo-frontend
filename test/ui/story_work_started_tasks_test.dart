import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/ui/work_page.dart';

void main() {
  // Harm: a malformed or stopped task returned by Start becomes an empty or dead terminal tab.
  test('only named running returned tasks are retained before the watch catches up', () {
    final view = WorkView();
    final running = Task.from({'name': 'running', 'running': true});
    view.rememberStarted('machine', [
      running,
      Task.from({'name': '', 'running': true}),
      Task.from({'name': 'stopped', 'running': false}),
    ]);
    expect(view.startedTasks.keys.toSet(), {('machine', 'running')});
    expect(view.startedTasks.values.single.name, 'running');
    expect(view.startedTasks.values.single.running, isTrue);
    view.rememberStarted('machine', [
      Task.from({'name': 'running', 'running': false}),
    ]);
    expect(view.startedTasks, isEmpty);
    view.dispose();
  });
}
