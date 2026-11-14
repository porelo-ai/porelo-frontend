import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/credential_carry.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';

const _cipher = 'c2VhbGVkLXRvLXRoZS1ob3N0';

/// One end of a carry, writing down what it was asked.
class _End implements CarriesCredentials {
  _End(this.name, this.calls);

  final String name;
  final List<String> calls;
  int receivers = 0;
  SealedCredential seals = const SealedCredential(
    outcome: 'SEALED',
    sealed: _cipher,
    name: 'anthropic',
    kind: 'api-key',
    detail: '',
  );
  List<String> receives = <String>['STORED'];
  String receiverOutcome = 'READY';

  @override
  Future<List<ImportableCredential>> importableCredentials() async => const <ImportableCredential>[];

  @override
  Future<CredentialReceiver> credentialReceiver() async {
    receivers++;
    calls.add('$name receiver');
    return CredentialReceiver(outcome: receiverOutcome, key: 'key$receivers', until: '2026-11-14T16:30:00Z');
  }

  @override
  Future<SealedCredential> sealCredential({
    required String key,
    String? name,
    String? agent,
    String? provider,
    String? configDirectory,
  }) async {
    calls.add('${this.name} seal to $key name=$name agent=$agent provider=$provider');
    return seals;
  }

  @override
  Future<ReceivedCredential> receiveCredential({
    required String sealed,
    required String name,
    required String kind,
    required bool replace,
  }) async {
    calls.add('${this.name} receive $sealed as $name/$kind replace=$replace');
    return ReceivedCredential(outcome: receives.removeAt(0), detail: '');
  }
}

const _provider = Provider(
  name: 'anthropic',
  label: 'Anthropic',
  upstream: 'api.anthropic.com',
  dialects: <String>[],
  authenticated: false,
  credentialType: 'api-key',
  credentialName: 'anthropic',
  storeCommand: '',
);

void main() {
  late List<String> calls;
  late _End here;
  late _End host;
  setUp(() {
    calls = <String>[];
    here = _End('here', calls);
    host = _End('host', calls);
  });

  // Harm: the value is sealed to a stale or wrong key, or the host is handed something other than what was sealed.
  test('a vault entry is sealed here to the host key and opened there', () async {
    final said = await carry(
      here: here,
      host: host,
      source: const VaultEntrySource(name: 'anthropic', type: 'api-key', characters: 51),
      provider: 'anthropic',
    );
    expect(calls, <String>[
      'host receiver',
      'here seal to key1 name=anthropic agent=null provider=null',
      'host receive $_cipher as anthropic/api-key replace=false',
    ]);
    expect(said.stored, isTrue);
    expect(said.words, 'Carried: the host holds it as anthropic.');
  });

  // Harm: an agent's sign-in is asked for by a vault name, or without the provider it is for.
  test("an agent's own sign-in is sealed by agent and provider", () async {
    await carry(
      here: here,
      host: host,
      source: const AgentSignInSource(agent: 'claude', agentLabel: 'Claude Code'),
      provider: 'anthropic',
    );
    expect(calls[1], 'here seal to key1 name=null agent=claude provider=anthropic');
  });

  // Harm: a refusal to seal still reaches the host, or the person is told nothing they can act on.
  test('nothing to seal never reaches the host and says what to do', () async {
    here.seals = const SealedCredential(outcome: 'NOTHING_TO_IMPORT', sealed: '', name: '', kind: '', detail: '');
    final said = await carry(
      here: here,
      host: host,
      source: const AgentSignInSource(agent: 'claude', agentLabel: 'Claude Code'),
      provider: 'anthropic',
    );
    expect(calls.where((c) => c.startsWith('host receive ')), isEmpty);
    expect(said.stored, isFalse);
    expect(said.words, contains('Sign in with it here first'));
  });

  // Harm: replacing reuses the host's spent one-use key, so the replace can never work.
  test('a kept entry is replaced with a fresh key and a fresh seal', () async {
    host.receives = <String>['EXISTS', 'STORED'];
    const source = VaultEntrySource(name: 'anthropic', type: 'api-key', characters: 51);
    final first = await carry(here: here, host: host, source: source, provider: 'anthropic');
    expect(first.exists, isTrue);
    expect(first.stored, isFalse);
    final again = await carry(here: here, host: host, source: source, provider: 'anthropic', replace: true);
    expect(again.stored, isTrue);
    expect(calls.where((c) => c.startsWith('host receiver')), hasLength(2));
    expect(calls.last, 'host receive $_cipher as anthropic/api-key replace=true');
    expect(calls[4], startsWith('here seal to key2'));
  });

  // Harm: the words a person reads, or a printed answer, carry the ciphertext.
  test('neither the value nor the ciphertext is in any words', () async {
    for (final outcome in <String>['STORED', 'EXISTS', 'VAULT_LOCKED', 'NO_RECEIVER', 'REFUSED']) {
      host.receives = <String>[outcome];
      final said = await carry(
        here: here,
        host: host,
        source: const VaultEntrySource(name: 'anthropic', type: 'api-key', characters: 51),
        provider: 'anthropic',
      );
      expect(said.words, isNot(contains(_cipher)));
    }
    expect('${here.seals}', isNot(contains(_cipher)));
  });

  // Harm: another provider's entries are offered, or a shut vault's entries look carriable.
  test("the sources are this provider's vault entries and the agents that reach it", () {
    const vault = VaultState(
      vault: 'vault',
      exists: true,
      readable: true,
      credentials: <Credential>[
        Credential(name: 'anthropic', type: 'api-key', characters: 51, settings: <String, String>{}),
        Credential(name: 'git.example.org', type: 'token', characters: 40, settings: <String, String>{}),
      ],
      connections: <Connection>[],
    );
    final sources = sourcesFor(
      _provider,
      vault: vault,
      agents: const <Agent>[
        Agent(
          name: 'claude',
          label: 'Claude Code',
          binary: 'claude',
          version: '',
          from: '',
          allowedDomains: <String>['api.anthropic.com'],
        ),
        Agent(
          name: 'codex',
          label: 'Codex',
          binary: 'codex',
          version: '',
          from: '',
          allowedDomains: <String>['api.openai.com'],
        ),
        Agent(
          name: 'pi',
          label: 'pi',
          binary: 'pi',
          version: '',
          from: '',
          found: 'NOT_SIGNED_IN',
          allowedDomains: <String>['api.anthropic.com'],
        ),
      ],
    );
    expect(sources.map((s) => s.id), <String>['vault anthropic', 'agent claude', 'agent pi']);
    expect(sources[0].whyNot, isNull);
    expect(sources[0].facts, 'api-key · 51 characters');
    expect(sources[1].whyNot, isNull);
    expect(sources[2].whyNot, contains('not signed in on this computer'));
  });

  // Harm: a shut vault reads as one holding nothing for the provider, so nobody thinks to open it.
  test("a shut vault keeps the provider's place, greyed with why", () {
    const shut = VaultState(
      vault: 'vault',
      exists: true,
      readable: false,
      credentials: <Credential>[],
      connections: <Connection>[],
    );
    final sources = sourcesFor(_provider, vault: shut, agents: const <Agent>[]);
    expect(sources.single.id, 'vault anthropic');
    expect(sources.single.whyNot, contains('shut'));
    expect(sourcesFor(_provider, vault: null, agents: const <Agent>[]).single.whyNot, contains('could not be read'));
  });

  // Harm: an agent signed in to another provider is offered, and carrying it would store the wrong sign-in.
  test('an agent signed in to another provider is greyed', () {
    final sources = sourcesFor(
      _provider,
      vault: null,
      agents: const <Agent>[
        Agent(
          name: 'omp',
          label: 'omp',
          binary: 'omp',
          version: '',
          from: '',
          foundProvider: 'openai',
          allowedDomains: <String>['api.anthropic.com'],
        ),
      ],
    );
    expect(sources.last.whyNot, 'omp is signed in to openai, not Anthropic.');
  });

  // Harm: a refusal here is said in words that do not tell the person what to do.
  test("each refusal to seal says what to do, in the daemon's words too", () async {
    here.seals = const SealedCredential(
      outcome: 'VAULT_LOCKED',
      sealed: '',
      name: 'anthropic',
      kind: '',
      detail: 'Run porelo vault unlock.',
    );
    final said = await carry(
      here: here,
      host: host,
      source: const VaultEntrySource(name: 'anthropic', type: 'api-key', characters: 51),
      provider: 'anthropic',
    );
    expect(
      said.words,
      "This computer's vault is shut, so nothing could be taken from it. Open it here first. Run porelo vault unlock.",
    );
  });

  // Harm: this computer's credential is sealed for a host whose shut vault cannot take it.
  test("a host's shut vault takes nothing, and nothing is sealed here", () async {
    host.receiverOutcome = 'VAULT_LOCKED';
    final said = await carry(
      here: here,
      host: host,
      source: const VaultEntrySource(name: 'anthropic', type: 'api-key', characters: 51),
      provider: 'anthropic',
    );
    expect(calls, <String>['host receiver']);
    expect(said.words, contains("The host's vault is shut"));
  });

  // Harm: an entry too large to carry reads as an unknown code, not as why it cannot go.
  test('an entry too large to carry says so', () async {
    here.seals = const SealedCredential(outcome: 'TOO_LARGE', sealed: '', name: 'anthropic', kind: '', detail: '');
    final said = await carry(
      here: here,
      host: host,
      source: const VaultEntrySource(name: 'anthropic', type: 'api-key', characters: 51),
      provider: 'anthropic',
    );
    expect(said.words, 'That entry is too large to carry to a host.');
  });

  // Harm: a sign-in porelo lists for the provider is missing, another provider's is offered, or a guess from the
  // agent's own finding wins over porelo's list.
  test("porelo's list of held sign-ins is the agent source when it answers", () {
    final sources = sourcesFor(
      _provider,
      vault: null,
      agents: const <Agent>[
        Agent(
          name: 'claude',
          label: 'Claude Code',
          binary: 'claude',
          version: '',
          from: '',
          found: 'NOT_SIGNED_IN',
          allowedDomains: <String>['api.anthropic.com'],
        ),
      ],
      importable: const <ImportableCredential>[
        ImportableCredential(agent: 'claude', provider: 'anthropic', kind: 'oauth'),
        ImportableCredential(agent: 'codex', provider: 'openai', kind: 'api-key'),
      ],
    );
    final agents = sources.whereType<AgentSignInSource>().toList();
    expect(agents.map((s) => s.id), <String>['agent claude']);
    expect(agents.single.label, "Claude Code's own sign-in");
    expect(agents.single.facts, 'agent sign-in · oauth');
    expect(agents.single.whyNot, isNull);
  });

  // Harm: one agent shows twice, so two rows share one key and the carry cannot say which is meant.
  test("an agent porelo lists twice for a provider is one source, with both kinds", () {
    final sources = sourcesFor(
      _provider,
      vault: null,
      agents: const <Agent>[],
      importable: const <ImportableCredential>[
        ImportableCredential(agent: 'claude', provider: 'anthropic', kind: 'oauth'),
        ImportableCredential(agent: 'claude', provider: 'anthropic', kind: 'api-key'),
        ImportableCredential(agent: 'pi', provider: '', kind: 'api-key'),
      ],
    ).whereType<AgentSignInSource>().toList();
    expect(sources.map((s) => s.id), <String>['agent claude']);
    expect(sources.single.facts, 'agent sign-in · oauth, api-key');
    expect(sources.single.label, "claude's own sign-in");
  });
}
