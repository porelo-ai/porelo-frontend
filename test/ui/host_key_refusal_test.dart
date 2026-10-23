import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_keys.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/ui/host_key_dialog.dart';

import '../features/support/world.dart';

void main() {
  // Prevents offering a trust button that bypasses the host setup pin.
  // Red: show the normal trust dialog for a pinnedByHost refusal.
  testWidgets('a managed host key refusal has no trust action', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final keys = SshHostKeys(run: (_, {input}) async => fail('No host key may be scanned or written.'));
    final check = await keys.checkMachine(
      const Machine(
        name: 'demo server',
        kind: 'host',
        host: 'user@host',
        socketPath: '/tmp/host.sock',
        remoteSocket: '/run/user/1/porelo/porelod.sock',
        identity: '/keys/host',
      ),
    );
    bool? accepted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => accepted = await confirmHostKey(context, check),
            child: const Text('Check'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Check'));
    await World.settle(tester);
    expect(find.textContaining('Only porelo-host'), findsOneWidget);
    expect(find.byKey(const Key('host-key-accept')), findsNothing);
    await tester.tap(find.text('Close'));
    await World.settle(tester);
    expect(accepted, isFalse);
  });
}
