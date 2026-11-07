import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart' show Connection;
import 'package:porelo_frontend/src/app/host_token_sources.dart';

const _declared = Connection(
  id: 'org-token',
  kind: 'TOKEN',
  match: 'https://forge.example.org/acme/',
  purpose: 'git',
  source: 'VAULT',
  present: true,
);

HostTokenSources _sources({
  required Future<List<Connection>> Function() declarations,
  Future<bool> Function(String address)? hasKept,
}) => HostTokenSources(
  forge: 'GitHub',
  repository: 'https://forge.example.org/acme/porelo.git',
  address: 'forge.example.org',
  declarations: declarations,
  hasKept: hasKept ?? (_) async => false,
  secrets: () => null,
);

void main() {
  // Harm: a source that could not be asked counts as holding no token, and the person is sent to sign in when the cause
  // is a daemon or a store that did not answer.
  test('a source that throws is said as failed, with its words, never as none', () async {
    final answers = await _sources(
      declarations: () async => throw const DeclarationsUnread("This computer's Porelo (porelod) did not answer: gone"),
      hasKept: (_) async => throw Exception('the secret store is locked'),
    ).ask();
    expect(answers.map((each) => each.source), [TokenSource.declared, TokenSource.kept, TokenSource.secretsFile]);
    expect(answers[0].state, TokenSourceState.failed);
    expect(answers[0].words, contains('did not answer'));
    expect(answers[1].state, TokenSourceState.failed);
    expect(answers[1].words, contains('the secret store is locked'));
    expect(answers[2].state, TokenSourceState.none);
  });

  // Harm: a token the vault declares is not offered, and the person is sent to sign in for one already there.
  test('the declared entry is found by name, and the kept token beside it', () async {
    final answers = await _sources(declarations: () async => [_declared], hasKept: (_) async => true).ask();
    expect(answers[0].state, TokenSourceState.found);
    expect(answers[0].declared?.id, 'org-token');
    expect(answers[0].words, contains('org-token'));
    expect(answers[1].state, TokenSourceState.found);
  });

  // Harm: an entry declared but absent reads as no declaration, and the person is not told which one to fill.
  test('an entry declared but not there is named as that', () async {
    final answers = await _sources(
      declarations: () async => [
        const Connection(
          id: 'org-token',
          kind: 'TOKEN',
          match: 'https://forge.example.org/acme/',
          purpose: 'git',
          source: 'VAULT',
          present: false,
        ),
      ],
    ).ask();
    expect(answers[0].state, TokenSourceState.none);
    expect(answers[0].words, contains('org-token is declared but not there'));
  });

  // Harm: the kept token is looked up under the repository's address, where none is ever kept, or the declared entry is
  // matched against a bare host, which no declaration's prefix fits: a token that is there is said to be missing.
  test('a declared entry is matched on the repository, a kept token asked for by its forge', () async {
    final asked = <String>[];
    final answers = await _sources(
      declarations: () async => const [_declared],
      hasKept: (address) async {
        asked.add(address);
        return address == 'forge.example.org';
      },
    ).ask();
    expect(answers[0].state, TokenSourceState.found);
    expect(asked, ['forge.example.org']);
    expect(answers[1].state, TokenSourceState.found);
  });
}
