import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';

import '../features/support/world.dart';

void main() {
  // Harm: work waiting on a person reads as having only no terminal, which a machine also says of
  // a terminal never opened.
  testWidgets('a row waiting on a person says that, with no terminal open', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    final machine = World.machines.current;
    String said(Demand demand) =>
        WorkRow.stateOf(Tile(machine: machine, fleet: World.machines.of(machine), demand: demand), terminalEnded: true);
    expect(said(Demand.quiet), 'No terminal is open in it');
    expect(said(Demand.working), 'No terminal is open in it');
    expect(said(Demand.gate), 'Its work waits for review');
    expect(said(Demand.ended), 'Its agent ended');
    expect(said(Demand.question), startsWith('Waiting on'));
  });
}
