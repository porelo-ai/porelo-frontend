import 'dart:convert';

import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';

import 'world.dart';

/// A machine that carries credentials, porelo to porelo, acting on what it is told.
///
/// As a host it makes one-use keys and stores what was sealed to a live one, which is then what its `Providers` reads
/// as authenticated; as this computer it seals an entry of its vault, or a sign-in its agents hold, to a host's key.
/// What it seals names only the key, the entry's name and its kind: a stand-in has no value to hide, and none to leak.
class CarryingFakeBackend extends FakeBackend implements CarryingBackend {
  /// Constructor taking what the machine has on it.
  CarryingFakeBackend(super.tasks);

  /// The sign-ins its installed agents hold, as `ImportableCredentials` lists them. Set by the scenario.
  List<ImportableCredential> theSignInsItsAgentsHold = <ImportableCredential>[];

  /// Keys it made and no receipt has ended yet.
  final Set<String> _liveKeys = <String>{};
  int _keysMade = 0;

  /// Every seal asked of it, as asked: by vault name, or by agent and provider.
  final List<({String key, String? name, String? agent, String? provider})> sealsAsked =
      <({String key, String? name, String? agent, String? provider})>[];

  /// Every receipt asked of it, by name and whether it replaces, in order.
  final List<({String name, bool replace})> receiptsAsked = <({String name, bool replace})>[];

  /// Holds [name] of [kind] in its vault, and every provider that keeps its credential under [name] reads as
  /// authenticated, as a daemon reads a provider from what its vault holds.
  void holds(String name, String kind) {
    final store = theStoreIs;
    theStoreIs = VaultState(
      vault: store.vault,
      exists: true,
      credentials: <Credential>[
        for (final entry in store.credentials)
          if (entry.name != name) entry,
        Credential(name: name, type: kind, characters: 40),
      ],
      readable: store.readable,
      connections: store.connections,
    );
    final providers = theProvidersItHas;
    theProvidersItHas = Providers(
      providers: <Provider>[
        for (final each in providers.providers)
          each.credentialName == name
              ? Provider(
                  name: each.name,
                  label: each.label,
                  upstream: each.upstream,
                  dialects: each.dialects,
                  authenticated: true,
                  credentialType: each.credentialType,
                  credentialName: each.credentialName,
                  storeCommand: each.storeCommand,
                )
              : each,
      ],
      readable: providers.readable,
    );
  }

  /// The kind its vault holds [name] as, null when it holds no such entry.
  String? kindOf(String name) => theStoreIs.credentials.where((entry) => entry.name == name).firstOrNull?.type;

  @override
  Future<List<ImportableCredential>> importableCredentials() async => theSignInsItsAgentsHold;

  @override
  Future<CredentialReceiver> credentialReceiver() async {
    if (!theStoreIs.readable) return const CredentialReceiver(outcome: 'VAULT_LOCKED', key: '', until: '');
    // Thirty-two bytes, as an X25519 public half is, and a different one each time.
    final key = base64.encode(List<int>.filled(32, ++_keysMade));
    _liveKeys.add(key);
    return CredentialReceiver(key: key, until: '2099-01-01T00:00:00Z');
  }

  @override
  Future<SealedCredential> sealCredential({
    required String key,
    String? name,
    String? agent,
    String? provider,
    String? configDirectory,
  }) async {
    sealsAsked.add((key: key, name: name, agent: agent, provider: provider));
    SealedCredential refused(String outcome, {String named = ''}) =>
        SealedCredential(outcome: outcome, sealed: '', name: named, kind: '', detail: '');
    if (name != null && (agent != null || provider != null)) return refused('FAILED');
    if (_isNotAKey(key)) return refused('BAD_KEY', named: name ?? '');
    final String sealedName;
    final String kind;
    if (name != null) {
      if (!theStoreIs.readable) return refused('VAULT_LOCKED');
      final entry = theStoreIs.credentials.where((each) => each.name == name).firstOrNull;
      if (entry == null) return refused('NO_SUCH_ENTRY');
      (sealedName, kind) = (entry.name, entry.type);
    } else {
      if (!theAgentsItHas.any((each) => each.name == agent)) return refused('NO_SUCH_AGENT');
      final held = theSignInsItsAgentsHold.where((each) => each.agent == agent && each.provider == provider);
      if (held.isEmpty) return refused('NOTHING_TO_IMPORT');
      // Under the name an import here would store it under: the provider's own key, as this machine names it.
      final stored = theProvidersItHas.providers.where((each) => each.name == provider).firstOrNull;
      (sealedName, kind) = (stored?.credentialName ?? provider!, held.first.kind);
    }
    final sealed = base64.encode(
      utf8.encode(jsonEncode(<String, String>{'to': key, 'name': sealedName, 'kind': kind})),
    );
    return SealedCredential(outcome: 'SEALED', sealed: sealed, name: sealedName, kind: kind, detail: '');
  }

  @override
  Future<ReceivedCredential> receiveCredential({
    required String sealed,
    required String name,
    required String kind,
    required bool replace,
  }) async {
    receiptsAsked.add((name: name, replace: replace));
    final opened = jsonDecode(utf8.decode(base64.decode(sealed))) as Map<String, dynamic>;
    // A key opens one entry at most, whatever became of it.
    if (!_liveKeys.remove(opened['to'])) return const ReceivedCredential(outcome: 'NO_RECEIVER', detail: '');
    if (opened['name'] != name || opened['kind'] != kind) {
      return const ReceivedCredential(outcome: 'REFUSED', detail: '');
    }
    if (!theStoreIs.readable) return const ReceivedCredential(outcome: 'VAULT_LOCKED', detail: '');
    if (kindOf(name) != null && !replace) return const ReceivedCredential(outcome: 'EXISTS', detail: '');
    holds(name, kind);
    return const ReceivedCredential(outcome: 'STORED', detail: '');
  }

  static bool _isNotAKey(String key) {
    try {
      return base64.decode(key).length != 32;
    } on FormatException {
      return true;
    }
  }
}
