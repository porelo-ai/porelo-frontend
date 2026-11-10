import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_host/porelo_host.dart' as host;
import 'package:porelo_frontend/src/app/host_session.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';

import '../features/support/world.dart';
import '../features/support/tiles.dart';
import '../support/host_organization.dart';
import '../support/host_process.dart';
import '../support/host_rental.dart';

void main() {
  // Harm: a machine being prepared vanishes from My machines, and the person takes it for lost or prepares it twice.
  testWidgets('My machines counts a machine being prepared on every frame until it stands', (tester) async {
    await World.startBackend(World.work);
    final fixture = HostFixture();
    await World.startApp(tester, hostAccess: fixture.access);
    await toThePlace(tester, 'attention');
    final runs = tester.widget<AttentionView>(find.byType(AttentionView)).attention.hostRuns!;
    await toTheMachines(tester);
    String count() => tester.widget<Text>(find.byKey(const Key('rail-machines-count'))).data!;
    final before = int.parse(count());
    final seen = <String>[];
    Future<void> frames(String step) async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        seen.add('$step: ${count()} ${find.textContaining('orchard').evaluate().isNotEmpty}');
      }
    }

    final process = HostProcess();
    final run = runs.start(
      project: 'orchard',
      record: signedSetup,
      session: HostSession(executable: 'fake', arguments: const [], start: (_, _) async => process),
    );
    await frames('started');
    process.line(const host.Step('up', host.StepState.done, address: '203.0.113.7'));
    await frames('up');
    process.line(host.Step('host', host.StepState.host, host: host.PreparedHost.read(sshCompletion())));
    await frames('host line');
    process.end(0);
    await frames('ended');
    await tester.runAsync(() => run.finished);
    await frames('finished');
    expect(run.ready, isTrue);
    expect(seen.where((each) => !each.endsWith('${before + 1} true')), isEmpty, reason: seen.join('\n'));
  });
}
