import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/attention.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart' show KeepsHostIdentities;
import 'package:porelo_frontend/src/app/host_runs.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/attention_view.dart';

import '../features/support/world.dart';

final _identity = HostIdentity.read(<String, dynamic>{
  'host': 'orchard',
  'ssh_host_keys': <Object>[],
  'repositories': <Object>[],
});

/// This computer's vault: it keeps what it is handed, or answers [failure].
class _Vault implements KeepsHostIdentities {
  HostIdentityFailure? failure;
  final keeps = <(String, bool)>[];

  @override
  Future<void> hostIdentityKeep(String host, HostIdentity identity, {bool replace = false}) async {
    keeps.add((host, replace));
    if (failure case final failed?) throw failed;
  }

  @override
  Future<HostIdentity> hostIdentityRead(String host) async => throw HostIdentityUnknown(host);

  @override
  Future<HostIdentityPublic> hostIdentityPublic(String host) async => throw HostIdentityUnknown(host);

  @override
  Future<List<String>> hostIdentities() async => const [];
}

void main() {
  late _Vault vault;
  late HostRuns runs;

  Future<void> pump(WidgetTester tester, HostIdentityFailure failure) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = Settings(MemorySettingsStore());
    final machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: FakeTunnels());
    vault = _Vault()..failure = failure;
    runs = HostRuns(machines, identities: () async => vault, exportIdentity: (_) async => _identity);
    final attention = Attention(machines, settings)..hostRuns = runs;
    addTearDown(() {
      attention.dispose();
      runs.dispose();
      machines.dispose();
      settings.dispose();
    });
    await tester.runAsync(() => runs.keepIdentity('orchard'));
    vault.failure = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttentionView(
            attention: attention,
            onDecide: (_, _, {required allow}) {},
            onReview: (_) {},
            actionsFor: (_) => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Harm: a server's keys that are not in the vault go unsaid, and are lost with the server.
  testWidgets('an identity not kept is a row, and keeping it again keeps it without replacing', (tester) async {
    await pump(tester, const HostIdentityVaultShut());
    expect(find.textContaining('The identity of orchard is not kept in your Porelo-Vault'), findsOneWidget);
    expect(find.text('Replace the stored identity…'), findsNothing, reason: 'nothing else is kept to replace');
    await tester.tap(find.text('Keep it again'));
    await tester.runAsync(() => runs.keepingSettled);
    await tester.pumpAndSettle();
    expect(vault.keeps, [('orchard', false), ('orchard', false)]);
    expect(find.textContaining('The identity of orchard is not kept'), findsNothing);
  });

  // Harm: the identity the vault keeps, maybe the only copy of keys the forge knows, is overwritten by one click.
  testWidgets('replacing another identity asks first, with the focus on Cancel', (tester) async {
    await pump(tester, const HostIdentityExists('orchard'));
    await tester.tap(find.text('Replace the stored identity…'));
    await tester.pumpAndSettle();
    final cancel = find.widgetWithText(TextButton, 'Cancel');
    expect(Focus.of(tester.element(find.text('Cancel'))).hasFocus, isTrue);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(vault.keeps, [('orchard', false)], reason: 'cancelled, nothing is replaced');
    await tester.tap(find.text('Replace the stored identity…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace it'));
    await tester.runAsync(() => runs.keepingSettled);
    await tester.pumpAndSettle();
    expect(vault.keeps, [('orchard', false), ('orchard', true)]);
  });
}
