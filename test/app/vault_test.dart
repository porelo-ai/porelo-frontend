import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/device_key.dart';
import 'package:porelo_frontend/src/app/vault.dart';

import '../features/support/world.dart';

/// A machine whose store answers only when told to, so a switch can happen in between.
class _Slow extends FakeBackend {
  _Slow() : super(const <Task>[]);

  final Completer<void> answer = Completer<void>();

  @override
  Future<VaultState> credentials() async {
    await answer.future;
    return super.credentials();
  }
}

/// A machine that refuses to shut its store, by name.
class _Refusing extends FakeBackend {
  _Refusing() : super(const <Task>[]);

  @override
  Future<Locked> lock() async => throw const VarlinkException('org.fuin.porelo.Tasks1.VaultBusy');
}

void main() {
  test('a store the machine refuses to shut says so, rather than leaving the answer to nobody', () async {
    // Asked from a dialog nobody awaits: a refusal let through reaches no one, and the dialog stayed busy.
    final vault = Vault(keys: MemoryDeviceKeyStore());

    await vault.lock(_Refusing());

    expect(vault.problem, contains('VaultBusy'));
    expect(vault.busy, isFalse);
  });

  test("switching machines never leaves the other machine's store on the lock", () async {
    final vault = Vault(keys: MemoryDeviceKeyStore());
    await vault.lookAt(FakeBackend(const <Task>[]), 'first');
    expect(vault.lockDoes, VaultAct.shut);
    expect(vault.lockWorks, isTrue);

    final second = _Slow();
    final looking = vault.lookAt(second, 'second');

    expect(vault.about, 'second');
    expect(vault.state, isNull, reason: "the first machine's store is still on the lock");
    expect(vault.lockWorks, isFalse);
    expect(vault.offersEnrolling, isFalse);
    second.answer.complete();
    await looking;
    expect(vault.lockWorks, isTrue);
  });

  test('asking the same machine again keeps what it said while the answer comes', () async {
    final vault = Vault(keys: MemoryDeviceKeyStore());
    final backend = _Slow()..answer.complete();
    await vault.lookAt(backend, 'first');

    final again = _Slow();
    final looking = vault.lookAt(again, 'first');

    expect(vault.state, isNotNull, reason: 'a refresh blanked the lock');
    again.answer.complete();
    await looking;
  });

  test('enrolling is offered only into an open store, and never twice', () {
    final vault = Vault(keys: MemoryDeviceKeyStore())
      ..state = VaultState.from(const <String, dynamic>{
        'vault': '/v',
        'exists': true,
        'credentials': <Map<String, dynamic>>[],
        'readable': false,
      });
    vault.devices.canEnroll = true;

    expect(vault.offersEnrolling, isTrue);
    expect(vault.whyNot(VaultAct.enroll), contains('shut'));
    expect(vault.lockWorks, isFalse, reason: 'a device that is not enrolled opened a shut store');

    // Enrolled means the machine lists the slot this key opens, not only that a key is kept here.
    vault.devices
      ..mine = const DeviceKey(slot: 'slot-1', share: 's')
      ..slots = const <Keyslot>[
        Keyslot(
          id: 'slot-1',
          name: 'laptop',
          storage: KeyslotStorage('USER_SCOPED'),
          enrolled: '',
          lastUsed: '',
          self: false,
          recovery: false,
        ),
      ];
    expect(vault.offersEnrolling, isFalse);
    expect(vault.lockDoes, VaultAct.open);
    expect(vault.lockWorks, isTrue);
  });
}
