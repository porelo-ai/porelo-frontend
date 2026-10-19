import 'dart:async';
import 'dart:convert';

import 'package:dbus/dbus.dart';

import 'secret_store.dart';

const _service = 'org.freedesktop.secrets';
const _prefix = 'org.freedesktop.Secret';

/// The freedesktop Secret Service over the session bus, in its default collection: GNOME Keyring
/// or KWallet, whichever the desktop runs, which unlock at login.
///
/// **One item per name, found by its attributes**, so a second write replaces the first. The
/// session is `plain`: the value crosses the local session bus to the keyring as it is, as
/// libsecret's own default does, and is never written anywhere by this side.
class SecretServiceStore implements SecretStore {
  /// Constructor taking the bus, so a test can use one of its own.
  SecretServiceStore({this.bus, this.promptWithin = const Duration(minutes: 2)});

  /// The bus to reach the keyring on; the session's own when null.
  final DBusClient? bus;

  /// How long a locked keyring's prompt may stand at the desktop before this gives up.
  final Duration promptWithin;

  late final DBusClient _client = bus ?? DBusClient.session();

  DBusRemoteObject get _secrets =>
      DBusRemoteObject(_client, name: _service, path: DBusObjectPath('/org/freedesktop/secrets'));

  DBusDict _attributes(String name) => DBusDict(DBusSignature('s'), DBusSignature('s'), <DBusValue, DBusValue>{
    const DBusString('application'): const DBusString('porelo-host'),
    const DBusString('name'): DBusString(name),
  });

  Future<DBusObjectPath> _session() async {
    final opened = await _call(_secrets, 'Service', 'OpenSession', <DBusValue>[
      const DBusString('plain'),
      const DBusVariant(DBusString('')),
    ]);
    return opened.returnValues[1].asObjectPath();
  }

  @override
  Future<String?> read(String name) async {
    final item = await _found(name);
    if (item == null) return null;
    final session = await _session();
    try {
      final got = await _call(DBusRemoteObject(_client, name: _service, path: item), 'Item', 'GetSecret', <DBusValue>[
        session,
      ]);
      final secret = got.returnValues.first.asStruct();
      return utf8.decode(secret[2].asByteArray().toList());
    } finally {
      await _close(session);
    }
  }

  @override
  Future<void> write(String name, String value) async {
    final collection = await _collection();
    final session = await _session();
    try {
      final made = await _call(
        DBusRemoteObject(_client, name: _service, path: collection),
        'Collection',
        'CreateItem',
        <DBusValue>[
          DBusDict.stringVariant(<String, DBusValue>{
            '$_prefix.Item.Label': DBusString('Porelo host: $name'),
            '$_prefix.Item.Attributes': _attributes(name),
          }),
          DBusStruct(<DBusValue>[
            session,
            DBusArray.byte(const <int>[]),
            DBusArray.byte(utf8.encode(value)),
            const DBusString('text/plain; charset=utf8'),
          ]),
          const DBusBoolean(true),
        ],
      );
      await _prompted(made.returnValues[1].asObjectPath());
    } finally {
      await _close(session);
    }
  }

  @override
  Future<void> close() async {
    // Only a bus this store opened itself is closed; one handed in belongs to its caller.
    if (bus == null) await _client.close();
  }

  @override
  Future<void> remove(String name) async {
    final item = await _found(name);
    if (item == null) return;
    final gone = await _call(
      DBusRemoteObject(_client, name: _service, path: item),
      'Item',
      'Delete',
      const <DBusValue>[],
    );
    await _prompted(gone.returnValues.first.asObjectPath());
  }

  /// The item kept under [name], unlocked, or null when there is none.
  Future<DBusObjectPath?> _found(String name) async {
    final found = await _call(_secrets, 'Service', 'SearchItems', <DBusValue>[_attributes(name)]);
    final unlocked = found.returnValues[0].asObjectPathArray().toList();
    if (unlocked.isNotEmpty) return unlocked.first;
    final locked = found.returnValues[1].asObjectPathArray().toList();
    if (locked.isEmpty) return null;
    await _unlock(<DBusObjectPath>[locked.first]);
    return locked.first;
  }

  /// The default collection, opened.
  Future<DBusObjectPath> _collection() async {
    final alias = await _call(_secrets, 'Service', 'ReadAlias', const <DBusValue>[DBusString('default')]);
    final collection = alias.returnValues.first.asObjectPath();
    if (collection.value == '/') {
      throw const SecretStoreFailed('no keyring is open: log in to the desktop, or open its keyring, and try again');
    }
    await _unlock(<DBusObjectPath>[collection]);
    return collection;
  }

  Future<void> _unlock(List<DBusObjectPath> objects) async {
    final unlocked = await _call(_secrets, 'Service', 'Unlock', <DBusValue>[DBusArray.objectPath(objects)]);
    await _prompted(unlocked.returnValues[1].asObjectPath());
  }

  /// Waits for a prompt the keyring put up at the desktop, if it put one up.
  Future<void> _prompted(DBusObjectPath prompt) async {
    if (prompt.value == '/') return;
    final object = DBusRemoteObject(_client, name: _service, path: prompt);
    final completed = DBusRemoteObjectSignalStream(object: object, interface: '$_prefix.Prompt', name: 'Completed');
    final done = completed.first;
    await _call(object, 'Prompt', 'Prompt', const <DBusValue>[DBusString('')]);
    final DBusSignal signal;
    try {
      signal = await done.timeout(promptWithin);
    } on TimeoutException {
      throw const SecretStoreFailed('the keyring is locked, and nobody opened it at the desktop');
    }
    if (signal.values.first.asBoolean()) {
      throw const SecretStoreFailed('opening the keyring was refused at the desktop');
    }
  }

  Future<void> _close(DBusObjectPath session) async {
    try {
      await _call(DBusRemoteObject(_client, name: _service, path: session), 'Session', 'Close', const <DBusValue>[]);
    } on SecretStoreFailed {
      // A session the keyring already dropped needs no closing.
    }
  }

  Future<DBusMethodSuccessResponse> _call(
    DBusRemoteObject on,
    String face,
    String method,
    List<DBusValue> values,
  ) async {
    try {
      return await on.callMethod('$_prefix.$face', method, values);
    } on DBusServiceUnknownException {
      throw const SecretStoreFailed('no Secret Service runs on this session bus: no keyring is open');
    } on DBusMethodResponseException catch (e) {
      throw SecretStoreFailed('the keyring refused $method: ${e.errorName}');
    }
  }
}
