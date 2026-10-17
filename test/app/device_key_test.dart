import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/device_key.dart';

/// What this device keeps to open a vault, proposed for Porelo's keyslots.
void main() {
  test('a share is 32 random bytes, in base64, and never the same twice', () {
    final one = newShare();
    final two = newShare();

    expect(base64.decode(one), hasLength(32));
    expect(one, isNot(two));
  });

  test('a share comes from the source it is given, so it can be pinned in a test', () {
    expect(newShare(Random(7)), newShare(Random(7)));
  });

  test('a key never says its share, wherever it is printed', () {
    final share = newShare();
    final key = DeviceKey(slot: 'slot-3', share: share);

    expect('$key', contains('slot-3'));
    expect('$key', isNot(contains(share)));
  });

  // Only iOS, Android and signed macOS keep a share from other programs of the same user.
  test('a desktop keystore is never declared stronger than it is', () {
    expect(storageOn('linux'), KeyslotStorage.userScoped);
    expect(storageOn('windows'), KeyslotStorage.userScoped);
    expect(storageOn('macos'), KeyslotStorage.userScoped, reason: 'nothing here knows it was signed');
    expect(storageOn('android'), KeyslotStorage.applicationScoped);
    expect(storageOn('ios'), KeyslotStorage.applicationScoped);
  });

  test('a key is kept per machine, and forgetting one leaves the others', () async {
    final store = MemoryDeviceKeyStore();
    await store.write('node-a', const DeviceKey(slot: 'slot-1', share: 'a'));
    await store.write('node-b', const DeviceKey(slot: 'slot-2', share: 'b'));

    await store.delete('node-a');

    expect(await store.read('node-a'), isNull);
    expect((await store.read('node-b'))?.slot, 'slot-2');
  });
}
