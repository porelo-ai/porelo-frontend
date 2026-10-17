import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:porelo_frontend/client.dart';

import 'device_key.dart';

/// This device's keys in the platform's keystore: on Linux the Secret Service's default collection,
/// through libsecret, which unlocks at login.
///
/// One entry per node, holding the keyslot id and the share. **Nothing else keeps the share**: not
/// the settings, not a file, not an operation record.
class PlatformDeviceKeyStore implements DeviceKeyStore {
  /// Constructor, optionally with the storage to use instead of the platform's.
  PlatformDeviceKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  KeyslotStorage get storage => storageHere;

  static String _entry(String node) => 'porelo-device-key:$node';

  @override
  Future<DeviceKey?> read(String node) async {
    final stored = await _guarded(() => _storage.read(key: _entry(node)));
    if (stored == null) return null;
    try {
      final map = jsonDecode(stored) as Map<String, Object?>;
      final slot = map['slot'];
      final share = map['share'];
      if (slot is! String || share is! String || share.isEmpty) return null;
      return DeviceKey(slot: slot, share: share);
    } on Object {
      // Not something this wrote. Treated as no key, so enrolling again replaces it.
      return null;
    }
  }

  @override
  Future<void> write(String node, DeviceKey key) => _guarded(() => _storage.write(
        key: _entry(node),
        value: jsonEncode(<String, String>{'slot': key.slot, 'share': key.share}),
      ));

  @override
  Future<void> delete(String node) => _guarded(() => _storage.delete(key: _entry(node)));

  /// The keystore's own failure, **without** anything that was being written: a platform message
  /// can quote its arguments, and one of them is the share.
  static Future<T> _guarded<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (ex) {
      throw DeviceKeyStoreFailed(ex.code);
    }
  }
}
