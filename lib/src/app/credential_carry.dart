import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// Something on this computer that a credential can be carried from to a host.
///
/// Never holds the value: only what a person needs to tell one from another.
sealed class CarrySource {
  const CarrySource({this.whyNot});

  /// Why this one cannot be carried, null when it can. Shown beside it, greyed.
  final String? whyNot;

  /// What it is, in a few words.
  String get label;

  /// What else is known of it: kind, account, age or expiry, as far as known.
  String get facts;

  /// Its key among the dialog's rows.
  String get id;
}

/// An entry of this computer's porelo vault.
class VaultEntrySource extends CarrySource {
  /// Constructor taking the entry's name and type.
  const VaultEntrySource({required this.name, required this.type, required this.characters, super.whyNot});

  /// Its name in the vault, which is also what it goes under on the host.
  final String name;

  /// Its type, empty when it has none.
  final String type;

  /// How long it is: how somebody tells two apart without the value.
  final int characters;

  @override
  String get label => name;

  @override
  String get facts => <String>[if (type.isNotEmpty) type, if (characters > 0) '$characters characters'].join(' · ');

  @override
  String get id => 'vault $name';
}

/// A local agent's own sign-in, read from its files as the local import reads them.
class AgentSignInSource extends CarrySource {
  /// Constructor taking the agent and what is known of its sign-in.
  const AgentSignInSource({
    required this.agent,
    required this.agentLabel,
    this.kind = '',
    this.account = '',
    this.age = '',
    super.whyNot,
  });

  /// The agent's name, as porelo knows it.
  final String agent;

  /// Its name for a person.
  final String agentLabel;

  /// Its kind, as porelo lists it; empty when not known.
  final String kind;

  /// The account it is signed in as, empty when not known.
  final String account;

  /// How old it is or when it expires, empty when not known.
  final String age;

  @override
  String get label => "$agentLabel's own sign-in";

  @override
  String get facts => <String>[
    'agent sign-in',
    if (kind.isNotEmpty) kind,
    if (account.isNotEmpty) account,
    if (age.isNotEmpty) age,
  ].join(' · ');

  @override
  String get id => 'agent $agent';
}

/// What carrying did, in words for a person.
class CarryOutcome {
  /// Constructor taking every field.
  const CarryOutcome({required this.stored, required this.exists, required this.words, this.name = ''});

  /// Whether the host now holds it.
  final bool stored;

  /// Whether the host already holds one under that name and kept it: asking again with replace overwrites it.
  final bool exists;

  /// One or two sentences.
  final String words;

  /// The vault key it went, or would go, under on the host.
  final String name;
}

/// Which of this computer's vault entries and local agents' sign-ins can go to a host for [provider].
///
/// Vault entries of the provider's own name or type are offered; others are not this provider's. An agent is offered
/// for each sign-in porelo lists the installed agents holding for it ([importable], from `ImportableCredentials`).
/// From a Porelo without that list, an agent is offered when it reaches the provider's upstream or was found signed in
/// to it, greyed when it found itself signed out or signed in elsewhere, and where it cannot say, carrying finds out.
List<CarrySource> sourcesFor(
  Provider provider, {
  required VaultState? vault,
  required List<Agent> agents,
  List<ImportableCredential>? importable,
}) {
  final vaultShut = vault == null
      ? "This computer's vault could not be read."
      : vault.readable
      ? null
      : "This computer's vault is shut; open it here to carry from it.";
  return <CarrySource>[
    // A shut or unread vault lists nothing, which is not the same as holding nothing: its place stays, greyed.
    if (vaultShut != null)
      VaultEntrySource(name: provider.credentialName, type: provider.credentialType, characters: 0, whyNot: vaultShut)
    else
      for (final entry in vault!.credentials)
        if (entry.name == provider.credentialName ||
            (provider.credentialType.isNotEmpty && entry.type == provider.credentialType))
          VaultEntrySource(name: entry.name, type: entry.type, characters: entry.characters, whyNot: vaultShut),
    // What porelo lists the agents holding is the answer; what each agent found of itself is only the older guess.
    if (importable != null)
      // One row per agent: a seal names the agent and the provider only, so two kinds of one agent are one source.
      for (final MapEntry(key: agent, value: kinds) in _kindsByAgent(importable, provider.name).entries)
        AgentSignInSource(agent: agent, agentLabel: _labelOf(agent, agents), kind: kinds.join(', '))
    else
      for (final agent in agents)
        if (agent.allowedDomains.contains(provider.upstream) || agent.foundProvider == provider.name)
          AgentSignInSource(
            agent: agent.name,
            agentLabel: agent.label.isEmpty ? agent.name : agent.label,
            whyNot: _agentWhyNot(agent, provider),
          ),
  ];
}

Map<String, List<String>> _kindsByAgent(List<ImportableCredential> rows, String provider) {
  final kinds = <String, List<String>>{};
  for (final row in rows) {
    if (row.provider != provider) continue;
    final held = kinds.putIfAbsent(row.agent, () => <String>[]);
    if (row.kind.isNotEmpty && !held.contains(row.kind)) held.add(row.kind);
  }
  return kinds;
}

String _labelOf(String agent, List<Agent> agents) {
  final known = agents.where((each) => each.name == agent).firstOrNull;
  return known == null || known.label.isEmpty ? agent : known.label;
}

/// Why [agent]'s own sign-in cannot go for [provider], as far as what it found of itself says; null when it can, or
/// when it cannot say, which never reads as signed out.
String? _agentWhyNot(Agent agent, Provider provider) {
  final name = agent.label.isEmpty ? agent.name : agent.label;
  if (agent.found == 'NOT_SIGNED_IN') return '$name is not signed in on this computer. Sign in with it here first.';
  if (agent.foundProvider.isNotEmpty && agent.foundProvider != provider.name) {
    return '$name is signed in to ${agent.foundProvider}, not ${provider.label}.';
  }
  return null;
}

/// Carries [source] from [here], this computer, to [host], porelo to porelo.
///
/// The host makes a one-use key, this computer seals the value to it, and the host opens it. The window holds only
/// the ciphertext, for the one call that hands it on: never shown, logged or kept. A host's key is gone after one
/// receipt, whatever its outcome, so asking again with [replace] seals afresh.
Future<CarryOutcome> carry({
  required CarriesCredentials here,
  required CarriesCredentials host,
  required CarrySource source,
  required String provider,
  bool replace = false,
}) async {
  final receiver = await host.credentialReceiver();
  // Nothing is taken from this computer for a host that could not store it.
  if (!receiver.isReady) {
    return CarryOutcome(
      stored: false,
      exists: false,
      words: receiver.outcome == 'VAULT_LOCKED'
          ? "The host's vault is shut, so it could not take it. It is opened at the host."
          : 'The host is not ready to take it: ${receiver.outcome}.',
    );
  }
  final sealed = switch (source) {
    VaultEntrySource(:final name) => await here.sealCredential(key: receiver.key, name: name),
    AgentSignInSource(:final agent) => await here.sealCredential(key: receiver.key, agent: agent, provider: provider),
  };
  if (!sealed.isSealed) return CarryOutcome(stored: false, exists: false, words: _sealWords(sealed), name: sealed.name);
  final received = await host.receiveCredential(
    sealed: sealed.sealed,
    name: sealed.name,
    kind: sealed.kind,
    replace: replace,
  );
  return CarryOutcome(
    stored: received.outcome == 'STORED',
    exists: received.outcome == 'EXISTS',
    words: _receiveWords(received, sealed.name),
    name: sealed.name,
  );
}

String _sealWords(SealedCredential said) {
  final words = switch (said.outcome) {
    'NO_SUCH_ENTRY' => "This computer's vault no longer holds that entry.",
    'VAULT_LOCKED' => "This computer's vault is shut, so nothing could be taken from it. Open it here first.",
    'TOO_LARGE' => 'That entry is too large to carry to a host.',
    'BAD_KEY' => "The host's key could not be used. Try again.",
    'NO_SUCH_AGENT' => 'That agent is not installed on this computer.',
    'NO_CONFIG_DIRECTORY' => 'That agent keeps its sign-in somewhere this computer could not find.',
    'NOTHING_TO_IMPORT' =>
      'That agent is not signed in on this computer, so there is nothing to carry. Sign in with it here first.',
    'WRONG_PROVIDER' => "That agent's sign-in is for another provider.",
    'FAILED' => 'It could not be taken from this computer.',
    _ => '${said.outcome}.',
  };
  return '$words ${said.detail}'.trim();
}

String _receiveWords(ReceivedCredential said, String name) {
  final words = switch (said.outcome) {
    'STORED' => 'Carried: the host holds it as $name.',
    'EXISTS' => 'The host already holds $name and kept it. Carry it again to replace it.',
    'VAULT_LOCKED' => "The host's vault is shut, so it could not take it. It is opened at the host.",
    'NO_RECEIVER' => 'The host no longer waited for it. Try again.',
    'REFUSED' => 'The host refused it.',
    _ => '${said.outcome}.',
  };
  return '$words ${said.detail}'.trim();
}
