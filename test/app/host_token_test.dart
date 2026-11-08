import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart' show Connection;
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/app/host_token.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

/// The kept token goes to the machine on standard input alone. These look for it where it must not be.
void main() {
  const token = 'ghp_the-secret-value';

  Future<ForgeConnection> keeping() async {
    final tokens = MemoryForgeTokens();
    await tokens.write('github.com', token);
    return ForgeConnection(tokens);
  }

  // Harm: a token on a command line is seen by every process on the computer.
  test('it reaches the command on standard input and on no argument', () async {
    final forges = await keeping();
    String? program;
    List<String>? arguments;
    String? fed;
    Map<String, String>? seen;
    await forges.feedKeptToken(
      'github.com',
      <String>['ssh', '-T', 'root@build', 'refresh'],
      run: (name, words, {inDirectory, environment = const {}, input}) async {
        program = name;
        arguments = words;
        fed = input;
        seen = environment;
        return (code: 0, out: '', err: '');
      },
    );
    expect(program, 'ssh');
    expect(arguments, <String>['-T', 'root@build', 'refresh']);
    expect(fed, '$token\n');
    expect(seen!.values.join(), isNot(contains(token)));
  });

  // Harm: a machine or ssh echoing what it was sent puts the token on the page and in the log.
  test('what the command says comes back without it', () async {
    final forges = await keeping();
    final ran = await forges.feedKeptToken('github.com', <String>[
      '/bin/sh',
      '-c',
      r'read given; echo "out $given"; echo "err $given" >&2; exit 3',
    ]);
    expect(ran.code, 3);
    expect(ran.out, 'out [redacted]\n');
    expect(ran.err, 'err [redacted]\n');
  }, skip: Platform.isWindows);

  // Harm: only the first line reaches the machine, and the rest would never be taken out of its words.
  test('a kept value of more than one word is not sent', () async {
    final tokens = MemoryForgeTokens();
    await tokens.write('github.com', 'ghp_one\nghp_two');
    var ran = false;
    await expectLater(
      ForgeConnection(tokens).feedKeptToken(
        'github.com',
        <String>['ssh'],
        run: (name, words, {inDirectory, environment = const {}, input}) async {
          ran = true;
          return (code: 0, out: '', err: '');
        },
      ),
      throwsA(isA<WorkspaceRefused>()),
    );
    expect(ran, isFalse);
  });

  // Harm: a command that echoes the token base64-encoded puts it on the page all the same.
  test('its encoded form is taken out too', () async {
    final forges = await keeping();
    final ran = await forges.feedKeptToken('github.com', <String>[
      '/bin/sh',
      '-c',
      r'read given; printf %s "$given" | base64 -w0 >&2; exit 1',
    ]);
    expect(ran.err, '[redacted]');
  }, skip: Platform.isWindows);

  test('blank is not a kept token', () async {
    final tokens = MemoryForgeTokens();
    await tokens.write('github.com', '   ');
    expect(await ForgeConnection(tokens).hasToken('github.com'), isFalse);
  });

  test('with no token kept it refuses, and runs nothing', () async {
    final forges = ForgeConnection(MemoryForgeTokens());
    var ran = false;
    await expectLater(
      forges.feedKeptToken(
        'github.com',
        <String>['ssh'],
        run: (name, words, {inDirectory, environment = const {}, input}) async {
          ran = true;
          return (code: 0, out: '', err: '');
        },
      ),
      throwsA(isA<WorkspaceRefused>()),
    );
    expect(ran, isFalse);
  });

  test('what is said of the answer', () {
    expect(tokenGivenWords('build', 'GitHub', (code: 0, out: '', err: '')), isNull);
    expect(
      tokenGivenWords('build', 'GitHub', (code: 1, out: '', err: 'HTTP 403: Resource not accessible')),
      contains('needs Administration: write'),
    );
    expect(tokenGivenWords('build', 'GitHub', (code: 255, out: '', err: 'refused')), contains('did not reach build'));
    expect(tokenGivenWords('build', 'GitHub', (code: 2, out: '', err: 'no such project')), contains('no such project'));
    expect(tokenGivenWords('build', 'GitHub', (code: 2, out: '', err: '')), contains('code 2'));
  });

  // Harm: a person is told nothing changed; the promise of what is done with the token must stand in the dialog.
  test('the words say what it is for, the right it needs, and where it goes', () {
    final words = keptTokenWords('build', 'GitHub', 'GitHub');
    expect(words, contains('Administration: write'));
    expect(words, contains('It does not keep the token'));
    expect(words, contains('on no command line, in no log and in no file'));
    expect(noTokenWords('build', 'GitHub'), contains('under My forges'));
  });

  // Harm: a person who declared the organization's token by the command line is told none is kept, and the machine
  // waits for a token it could have had.
  test("the vault's token for the organization is the longest present declaration for git", () {
    Connection token(String id, String match, {String kind = 'TOKEN', String purpose = 'git', bool present = true}) =>
        Connection(
          id: id,
          kind: kind,
          match: match,
          user: '',
          purpose: purpose,
          source: 'VAULT',
          protected: true,
          present: present,
          expires: '',
        );
    final held = [
      token('wide', 'https://github.com/'),
      token('org', 'https://github.com/porelo-ai/'),
      token('key', 'https://github.com/porelo-ai/porelo', kind: 'SSH_KEY'),
      token('images', 'https://github.com/porelo-ai/porelo.git', purpose: 'registry'),
      token('gone', 'https://github.com/porelo-ai/porelo.g', present: false),
    ];
    expect(declaredOrganizationToken('git@github.com:porelo-ai/porelo.git', held)?.id, 'org');
    expect(declaredOrganizationToken('https://github.com/porelo-ai/porelo.git', held)?.id, 'org');
    expect(declaredOrganizationToken('git@gitlab.com:porelo-ai/porelo.git', held), isNull);
    // Porelo may answer the scp form without its user; the token declared for it must still be found.
    expect(declaredOrganizationToken('github.com:porelo-ai/porelo.git', held)?.id, 'org');
    expect(declaredOrganizationToken(r'C:\porelo\org', held), isNull, reason: 'a Windows path is no address');
  });
}
