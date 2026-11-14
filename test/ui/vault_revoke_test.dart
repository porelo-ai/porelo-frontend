import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/device_key.dart';
import 'package:porelo_frontend/src/app/vault.dart';
import 'package:porelo_frontend/src/ui/vault_view.dart';

Keyslot _slot(String id, String name, {bool recovery = false}) => Keyslot(
  id: id,
  name: name,
  storage: KeyslotStorage.userScoped,
  enrolled: '2026-11-01',
  lastUsed: '',
  self: false,
  recovery: recovery,
);

/// A vault whose ways in are [slots], on its page, with the window [atTheMachine] or not; what was revoked, in order.
Future<List<String>> _show(WidgetTester tester, List<Keyslot> slots, {required bool atTheMachine}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final vault = Vault(keys: MemoryDeviceKeyStore())..devices.slots = slots;
  final filter = TextEditingController();
  addTearDown(filter.dispose);
  final revoked = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: VaultView(
          vault: vault,
          onRevoke: (slot) => revoked.add(slot.id),
          atTheMachine: atTheMachine,
          head: (
            id: 'vault',
            path: const [],
            pathKey: const Key('vault-path'),
            notices: const [],
            stale: false,
            filter: filter,
          ),
        ),
      ),
    ),
  );
  return revoked;
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  final passphrase = _slot('slot-0', 'recovery passphrase', recovery: true);

  // Harm: a window away from the machine revokes its vault's last device, and the vault is shut for good where nobody
  // at the machine can type the passphrase.
  testWidgets("a machine elsewhere's last device is not revoked from here, and the dialog says how at the machine", (
    tester,
  ) async {
    final revoked = await _show(tester, [passphrase, _slot('slot-1', 'ssh-agent')], atTheMachine: false);
    await _tap(tester, 'revoke-slot-1');
    expect(find.byKey(const Key('revoke-confirm')), findsNothing);
    expect(find.textContaining('porelo vault revoke slot-1'), findsOneWidget);
    await _tap(tester, 'revoke-keep');
    expect(revoked, isEmpty);
  });

  // Harm: a device that is not the last cannot be revoked from a window away from its machine.
  testWidgets("a machine elsewhere's device that is not the last is revoked from here", (tester) async {
    final revoked = await _show(tester, [
      passphrase,
      _slot('slot-1', 'ssh-agent'),
      _slot('slot-2', 'old phone'),
    ], atTheMachine: false);
    await _tap(tester, 'revoke-slot-2');
    await _tap(tester, 'revoke-confirm');
    expect(revoked, ['slot-2']);
  });

  // Harm: at the machine, the last device cannot be revoked at all, or is revoked without the cost said first.
  testWidgets('the last device at the machine is revoked after the dialog says what it costs', (tester) async {
    final revoked = await _show(tester, [passphrase, _slot('slot-1', 'ssh-agent')], atTheMachine: true);
    await _tap(tester, 'revoke-slot-1');
    expect(find.textContaining('lost for good'), findsOneWidget);
    expect(find.textContaining('this window cannot tell'), findsOneWidget);
    await _tap(tester, 'revoke-confirm');
    expect(revoked, ['slot-1']);
  });

  // Harm: the only way into a vault with no passphrase is revoked from the window, and its entries are lost for good.
  testWidgets('the only way into a vault with no passphrase is not revoked, even at the machine', (tester) async {
    final revoked = await _show(tester, [_slot('slot-1', 'ssh-agent')], atTheMachine: true);
    await _tap(tester, 'revoke-slot-1');
    expect(find.byKey(const Key('revoke-confirm')), findsNothing);
    expect(find.textContaining('it has no passphrase'), findsOneWidget);
    await _tap(tester, 'revoke-keep');
    expect(revoked, isEmpty);
  });
}
