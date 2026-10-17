import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:porelo_frontend/client.dart';

/// What this device keeps to open one machine's vault: which keyslot it is, and its share.
///
/// **The share is a secret, and this object never says it.** Its [toString] names the keyslot only,
/// so a log line, an error message or a debugger's summary cannot carry it by accident.
class DeviceKey {
  /// Constructor taking the keyslot the node assigned and the share this device generated.
  const DeviceKey({required this.slot, required this.share});

  /// The keyslot id, as the node returned it at enrollment.
  final String slot;

  /// Base64 of the 32 random bytes that open the keyslot. Sent once at enrollment, and at each unlock.
  final String share;

  @override
  String toString() => 'DeviceKey(slot: $slot)';
}

/// The platform's keystore refused, or is not there: no Secret Service running, a locked keyring
/// nobody unlocked, a denied prompt.
class DeviceKeyStoreFailed implements Exception {
  /// Constructor taking what the keystore said, which never includes what was being written.
  const DeviceKeyStoreFailed(this.reason);

  /// What the keystore said.
  final String reason;

  @override
  String toString() => "This device's keystore refused: $reason";
}

/// Where this device keeps its keys: one per machine, in the platform's keystore.
///
/// Behind an interface so that everything above it runs in a test without a keyring, and so the
/// keystore is chosen in one place.
abstract interface class DeviceKeyStore {
  /// How the keys are kept here, declared honestly: the value a node records for this device.
  KeyslotStorage get storage;

  /// The key for [node], or null when this device is not enrolled there.
  Future<DeviceKey?> read(String node);

  /// Keeps the key for [node], replacing any before it.
  Future<void> write(String node, DeviceKey key);

  /// Forgets the key for [node].
  Future<void> delete(String node);
}

/// Keys held in memory only, for tests and for a platform with no keystore at all.
class MemoryDeviceKeyStore implements DeviceKeyStore {
  /// Constructor, declaring what a test wants this store to claim.
  MemoryDeviceKeyStore({this.storage = KeyslotStorage.userScoped});

  @override
  final KeyslotStorage storage;

  final Map<String, DeviceKey> _keys = <String, DeviceKey>{};

  /// What this store says when it refuses, as a keyring nobody unlocked does; null while it works.
  String? refusing;

  @override
  Future<DeviceKey?> read(String node) async {
    if (refusing case final reason?) throw DeviceKeyStoreFailed(reason);
    return _keys[node];
  }

  @override
  Future<void> write(String node, DeviceKey key) async {
    if (refusing case final reason?) throw DeviceKeyStoreFailed(reason);
    _keys[node] = key;
  }

  @override
  Future<void> delete(String node) async => _keys.remove(node);
}

/// A new share: base64 of 32 bytes from the operating system's secure random source.
String newShare([Random? random]) {
  final source = random ?? Random.secure();
  return base64.encode(<int>[for (var i = 0; i < 32; i++) source.nextInt(256)]);
}

/// What a keystore on [operatingSystem] is worth, **never claimed higher than the platform gives**.
///
/// Linux and Windows keep application secrets in a store that unlocks at login — a Secret Service
/// keyring, or DPAPI — so anything running as this user can ask for them. iOS and Android give an
/// application a store of its own. **macOS is counted as user-scoped**: only a signed application
/// gets a keychain entry other programs cannot read, and nothing here can tell whether it was signed.
KeyslotStorage storageOn(String operatingSystem) => switch (operatingSystem) {
      'ios' || 'android' => KeyslotStorage.applicationScoped,
      _ => KeyslotStorage.userScoped,
    };

/// What a keystore on this machine is worth.
KeyslotStorage get storageHere => storageOn(Platform.operatingSystem);
