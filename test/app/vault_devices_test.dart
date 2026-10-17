import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/device_key.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/vault_devices.dart';

/// A node with Porelo's keyslots, as proposed: a share it has seen opens its slot, nothing else.
class _Node implements FleetBackend {
  _Node({this.nodeId = 'node-a'});

  final String nodeId;
  final List<({Keyslot slot, String share})> held = <({Keyslot slot, String share})>[];
  final List<String> sent = <String>[];

  /// What the store held at the moment each enrollment arrived, to prove the key was kept first.
  final List<DeviceKey?> keptWhenSent = <DeviceKey?>[];
  DeviceKeyStore? watching;

  /// Set to answer the next enrollment with this outcome.
  KeyslotOutcome? refuseWith;

  /// Set to lose the connection on the next enrollment, after the node took the key.
  bool loseTheAnswer = false;

  bool b60 = true;

  @override
  Future<String> node() async => nodeId;

  Keyslot _slot(String id, String name, KeyslotStorage storage) =>
      Keyslot(id: id, name: name, storage: storage, enrolled: 'e', lastUsed: '', self: false, recovery: false);

  @override
  Future<Enrolled> enrollDevice({required String name, required String share, required KeyslotStorage storage}) async {
    if (!b60) throw const FeatureNotSupported('EnrollDevice');
    sent.add(share);
    keptWhenSent.add(await watching?.read(nodeId));
    final refusal = refuseWith;
    if (refusal != null) return Enrolled(outcome: refusal, slot: null, detail: '');
    final known = held.where((each) => each.share == share).firstOrNull;
    if (known != null) return Enrolled(outcome: KeyslotOutcome.alreadyEnrolled, slot: known.slot, detail: '');
    final slot = _slot('slot-${held.length + 1}', name, storage);
    held.add((slot: slot, share: share));
    if (loseTheAnswer) {
      loseTheAnswer = false;
      throw const VarlinkDisconnected('the connection went');
    }
    return Enrolled(outcome: KeyslotOutcome.enrolled, slot: slot, detail: '');
  }

  @override
  Future<List<Keyslot>> keyslots() async {
    if (!b60) throw const FeatureNotSupported('Keyslots');
    return <Keyslot>[for (final each in held) each.slot];
  }

  @override
  Future<Revoked> revokeKeyslot(String id) async {
    held.removeWhere((each) => each.slot.id == id);
    return Revoked(
      outcome: KeyslotOutcome.revoked,
      remaining: <Keyslot>[for (final each in held) each.slot],
      detail: '',
    );
  }

  ({String share, int? minutes})? lastUnlock;

  @override
  Future<UnlockedWithShare> unlockWithShare({required String share, int? minutes}) async {
    lastUnlock = (share: share, minutes: minutes);
    final opens = held.where((each) => each.share == share).firstOrNull;
    return opens == null
        ? const UnlockedWithShare(outcome: KeyslotOutcome.shareRejected, until: '', slot: null, detail: '')
        : UnlockedWithShare(outcome: KeyslotOutcome.unlocked, until: '08:30', slot: opens.slot, detail: '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A node that takes an enrollment only when told to, so the machine can change in between.
class _SlowNode extends _Node {
  final Completer<void> hold = Completer<void>();

  @override
  Future<Enrolled> enrollDevice({required String name, required String share, required KeyslotStorage storage}) async {
    await hold.future;
    return super.enrollDevice(name: name, share: share, storage: storage);
  }
}

void main() {
  late MemoryDeviceKeyStore store;
  late VaultDevices devices;
  late _Node node;

  setUp(() {
    store = MemoryDeviceKeyStore();
    devices = VaultDevices(store);
    node = _Node()..watching = store;
  });

  test('enrolling keeps the key before it is sent, and records the slot the machine assigned', () async {
    await devices.enroll(node, 'laptop');

    expect(node.keptWhenSent.single?.share, node.sent.single, reason: 'the key was sent before it was kept');
    final kept = await store.read('node-a');
    expect(kept?.slot, 'slot-1');
    expect(kept?.share, node.sent.single);
    expect(devices.enrolledHere, isTrue);
    expect(devices.said, contains('"laptop"'));
  });

  test('a refused enrollment leaves no key behind', () async {
    node.refuseWith = KeyslotOutcome.vaultLocked;

    await devices.enroll(node, 'laptop');

    expect(await store.read('node-a'), isNull);
    expect(devices.said, contains('unlock it at the machine first'));
  });

  test('an answer lost after the machine took the key keeps it, and trying again makes no second device', () async {
    node.loseTheAnswer = true;
    await devices.enroll(node, 'laptop');
    expect(devices.problem, contains('Lost contact'));
    expect(await store.read('node-a'), isNotNull, reason: 'the machine may hold it, so this must too');

    await devices.enroll(node, 'laptop');

    expect(node.held, hasLength(1), reason: 'a second try made a second keyslot');
    expect(node.sent[0], node.sent[1], reason: 'a second try sent a new share');
    expect((await store.read('node-a'))?.slot, 'slot-1');
    expect(devices.said, contains('enrolled already'));
  });

  test("the device's own storage is what it declares", () async {
    final strong = VaultDevices(MemoryDeviceKeyStore(storage: KeyslotStorage.applicationScoped));

    await strong.enroll(node, 'phone');

    expect(node.held.single.slot.storage, KeyslotStorage.applicationScoped);
  });

  test('unlocking sends the kept share for the time asked, and says until when', () async {
    await devices.enroll(node, 'laptop');

    await devices.unlock(node, minutes: 30);

    expect(node.lastUnlock?.share, node.sent.single);
    expect(node.lastUnlock?.minutes, 30);
    expect(devices.said, 'The vault is open until 08:30.');
  });

  test('a device with no key here sends nothing to unlock with', () async {
    await devices.unlock(node, minutes: 30);

    expect(node.lastUnlock, isNull);
    expect(devices.problem, contains('not enrolled on this machine'));
  });

  test('revoking this device forgets its key, and revoking another keeps it', () async {
    await devices.enroll(node, 'laptop');
    final other = Keyslot(
      id: 'slot-9',
      name: 'old phone',
      storage: KeyslotStorage.userScoped,
      enrolled: 'e',
      lastUsed: '',
      self: false,
      recovery: false,
    );
    node.held.add((slot: other, share: 'x'));

    await devices.revoke(node, other);
    expect(await store.read('node-a'), isNotNull);
    expect(devices.said, '"old phone" can no longer open the vault. Still able to open it: "laptop".');

    await devices.revoke(node, devices.slots.single);
    expect(await store.read('node-a'), isNull);
    expect(devices.enrolledHere, isFalse);
  });

  test('a machine without keyslots says so, and keeps nothing', () async {
    node.b60 = false;

    await devices.enroll(node, 'laptop');

    expect(devices.problem, contains('a later Porelo'));
    expect(await store.read('node-a'), isNull);
  });

  test('a machine that does not say which node it is enrolls nothing', () async {
    final nameless = _Node(nodeId: '');

    await devices.enroll(nameless, 'laptop');

    expect(nameless.sent, isEmpty);
    expect(devices.problem, contains('does not say which node'));
  });

  test('a user-scoped key is described as readable by this user, never as protected', () {
    expect(storageWords(KeyslotStorage.userScoped), contains('anything running as this user can read it'));
    expect(storageWords(const KeyslotStorage('SOMETHING_NEW')), contains('nothing is claimed'));
  });

  test('a keystore that refuses sends nothing, and says it was the keystore', () async {
    final refusing = VaultDevices(_Refusing());

    await refusing.enroll(node, 'laptop');

    expect(node.sent, isEmpty, reason: 'a share nobody could keep was sent');
    expect(refusing.problem, contains("keystore refused (locked)"));
  });

  test("an enrollment answered after switching machines leaves the other machine's devices off screen", () async {
    final slow = _SlowNode()..watching = store;
    final enrolling = devices.enroll(slow, 'laptop');
    await pumpEventQueue();

    devices.forget();
    slow.hold.complete();
    await enrolling;

    expect(devices.slots, isEmpty);
    expect(devices.said, isNull);
    expect((await store.read('node-a'))?.slot, 'slot-1', reason: 'the key is per node and still kept');
  });
}

class _Refusing extends MemoryDeviceKeyStore {
  @override
  Future<void> write(String node, DeviceKey key) async => throw const DeviceKeyStoreFailed('locked');
}
