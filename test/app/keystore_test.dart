import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/device_key.dart';
import 'package:porelo_frontend/src/app/keystore.dart';

/// A keystore that refuses, and quotes what it was given the way a platform message can.
class _Refusing implements FlutterSecureStorage {
  @override
  Future<void> write({required String key, required String? value, AppleOptions? iOptions,
          AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions,
          AppleOptions? mOptions, WindowsOptions? wOptions}) async =>
      throw PlatformException(code: 'no secret service', message: 'could not store $value');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

  test('a key is kept per node and read back as it was written', () async {
    final store = PlatformDeviceKeyStore();

    await store.write('node-a', const DeviceKey(slot: 'slot-1', share: 'c2hhcmU='));

    final kept = await store.read('node-a');
    expect(kept?.slot, 'slot-1');
    expect(kept?.share, 'c2hhcmU=');
    expect(await store.read('node-b'), isNull, reason: "one node's key opened another's");
  });

  test('deleting forgets that node only', () async {
    final store = PlatformDeviceKeyStore();
    await store.write('node-a', const DeviceKey(slot: 'slot-1', share: 'YQ=='));
    await store.write('node-b', const DeviceKey(slot: 'slot-2', share: 'Yg=='));

    await store.delete('node-a');

    expect(await store.read('node-a'), isNull);
    expect((await store.read('node-b'))?.slot, 'slot-2');
  });

  test('an entry this did not write is no key, so enrolling again replaces it', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{'porelo-device-key:node-a': 'not json'});

    expect(await PlatformDeviceKeyStore().read('node-a'), isNull);
  });

  test("a refusal says the keystore's reason and never what was being written", () async {
    final store = PlatformDeviceKeyStore(storage: _Refusing());

    final failure = await store
        .write('node-a', const DeviceKey(slot: '', share: 'the-share-itself'))
        .then<Object?>((_) => null, onError: (Object error) => error);

    expect(failure, isA<DeviceKeyStoreFailed>());
    expect('$failure', contains('no secret service'));
    expect('$failure', isNot(contains('the-share-itself')));
  });

  test('on Linux it claims user scope, never more', () {
    expect(PlatformDeviceKeyStore().storage, storageHere);
  });
}
