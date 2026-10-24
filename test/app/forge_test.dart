import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';

void main() {
  late List<({String method, Uri uri, Map<String, String> headers, String? body})> asked;
  late Map<String, ForgeReply> answers;

  ForgeReply reply(int status, Object body, {Map<String, String> headers = const <String, String>{}}) =>
      (status: status, body: jsonEncode(body), headers: headers);

  GitHub github() => GitHub(
    'ghp_secret-token',
    http: (method, uri, headers, body) async {
      asked.add((method: method, uri: uri, headers: headers, body: body));
      return answers['$method ${uri.path}${uri.query.isEmpty ? '' : '?${uri.query}'}'] ??
          answers['$method ${uri.path}'] ??
          reply(404, <String, String>{'message': 'Not Found'});
    },
  );

  Map<String, Object?> repo(String name, {bool admin = false, bool push = false}) => <String, Object?>{
    'full_name': name,
    'ssh_url': 'git@github.com:$name.git',
    'clone_url': 'https://github.com/$name.git',
    'default_branch': 'main',
    'private': true,
    'permissions': <String, bool>{'admin': admin, 'push': push, 'pull': true},
  };

  setUp(() {
    asked = <({String method, Uri uri, Map<String, String> headers, String? body})>[];
    answers = <String, ForgeReply>{};
  });

  // As api.github.com/meta answered: the fingerprints without their `SHA256:`.
  test('the host keys GitHub publishes are read as fingerprints a machine names them by', () async {
    answers['GET /meta'] = reply(200, <String, Object>{
      'ssh_key_fingerprints': <String, String>{
        'SHA256_ECDSA': 'p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM',
        'SHA256_ED25519': '+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU',
      },
    });
    expect(await github().hostKeyFingerprints(), <String>[
      'SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM',
      'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU',
    ]);
  });

  test('a person\'s signing keys are read from what GitHub lists for anybody', () async {
    answers['GET /users/alice/ssh_signing_keys'] = reply(200, <Object>[
      <String, Object>{'id': 1, 'title': 'Laptop', 'key': 'ssh-ed25519 AAAAmine'},
    ]);
    final keys = await github().signingKeys('alice');
    expect([for (final each in keys) '${each.title} ${each.keyPart}'], <String>['Laptop ssh-ed25519 AAAAmine']);
  });

  test("a repository's branches are read by name, every page of them", () async {
    answers['GET /repos/acme/api/branches'] = reply(200, <Object>[
      <String, Object>{'name': 'main'},
      <String, Object>{'name': 'fix-rounding'},
    ]);
    expect(await github().branches('acme/api'), <String>['main', 'fix-rounding']);
  });

  // Harm: a token outside Authorization can leak through addresses, logs or payloads.
  test('the token goes in a header, never in the address', () async {
    answers['GET /user'] = reply(200, <String, String>{'login': 'alice'});

    expect((await github().whoAmI()).login, 'alice');
    expect(asked.single.headers['Authorization'], 'Bearer ghp_secret-token');
    expect(asked.single.uri.toString(), isNot(contains('ghp_secret-token')));
    expect(asked.single.body, isNull, reason: 'no token belongs in a request payload');
    expect(
      asked.single.headers.entries.where((each) => each.key != 'Authorization').map((each) => each.value).join(),
      isNot(contains('ghp_secret-token')),
    );
  });

  test('every page of repositories is read, with whether the person is an admin and may push', () async {
    answers['GET /user/repos?per_page=100&sort=full_name'] = reply(
      200,
      <Object?>[repo('acme/api', admin: true, push: true)],
      headers: <String, String>{
        'link': '<https://api.github.com/user/repos?per_page=100&sort=full_name&page=2>; rel="next"',
      },
    );
    answers['GET /user/repos?per_page=100&sort=full_name&page=2'] = reply(200, <Object?>[repo('acme/web', push: true)]);

    final found = await github().repositories();

    expect(found.map((each) => each.fullName), <String>['acme/api', 'acme/web']);
    expect(found.map((each) => each.admin), <bool>[true, false]);
    expect(found.map((each) => each.push), <bool>[true, true]);
    expect(found.first.sshUrl, 'git@github.com:acme/api.git');
  });

  test('a repository says whether it is a project already, and a missing file is no failure', () async {
    const has = ForgeRepository(
      fullName: 'acme/api',
      sshUrl: '',
      httpsUrl: '',
      defaultBranch: 'main',
      admin: true,
      push: true,
      private: true,
    );
    const hasNot = ForgeRepository(
      fullName: 'acme/web',
      sshUrl: '',
      httpsUrl: '',
      defaultBranch: 'trunk',
      admin: true,
      push: true,
      private: true,
    );
    answers['GET /repos/acme/api/contents/project.yml'] = reply(200, <String, String>{'name': 'project.yml'});

    expect(await github().hasProjectFile(has), isTrue);
    expect(await github().hasProjectFile(hasNot), isFalse);
    expect(asked.last.uri.queryParameters['ref'], 'trunk');
  });

  test('a token GitHub does not accept is said as that, with GitHub’s own words', () async {
    answers['GET /user'] = reply(401, <String, String>{'message': 'Bad credentials'});

    await expectLater(
      github().whoAmI(),
      throwsA(
        isA<ForgeRefused>()
            .having((it) => it.status, 'status', 401)
            .having(
              (it) => it.words,
              'words',
              'GitHub does not accept this token: it is wrong, expired or revoked. (Bad credentials)',
            ),
      ),
    );
  });

  // A project's repository says which forge set up here holds it, by its host, however git writes it.
  test('the host and owner/name of a repository are read from each way git writes its address', () {
    expect(hostOf('git@github.com:acme/api.git'), 'github.com');
    expect(hostOf('ssh://git@git.example.org/acme/api.git'), 'git.example.org');
    expect(hostOf('https://github.com/acme/api'), 'github.com');
    expect(hostOf('/srv/repos/api'), isNull);
    expect(fullNameOf('git@github.com:acme/api.git'), 'acme/api');
    expect(fullNameOf('https://github.com/acme/api'), 'acme/api');
    expect(fullNameOf('ssh://git@git.example.org/acme/api.git'), 'acme/api');
    expect(fullNameOf('/srv/repos/api'), isNull);
  });

  test('a next page on another host is refused, and the token is never sent there', () async {
    answers['GET /user/repos?per_page=100&sort=full_name'] = reply(
      200,
      <Object?>[repo('acme/api')],
      headers: <String, String>{'link': '<https://collector.example/user/repos?page=2>; rel="next"'},
    );

    await expectLater(github().repositories(), throwsA(isA<ForgeRefused>()));
    expect(asked.map((each) => each.uri.host), everyElement('api.github.com'));
  });

  test("where a repository is cloned from is made from its name and the forge's host, not its answer", () async {
    answers['GET /repos/acme/api'] = reply(200, <String, Object?>{
      ...repo('acme/api'),
      'ssh_url': 'git@collector.example:acme/api.git',
      'clone_url': 'https://collector.example/acme/api.git',
    });

    final found = await github().repository('acme/api');

    expect(found.httpsUrl, 'https://github.com/acme/api.git');
    expect(found.sshUrl, 'git@github.com:acme/api.git');
  });

  test('a name that is not owner/name is never a repository, so it never becomes a path', () async {
    answers['GET /user/repos?per_page=100&sort=full_name'] = reply(200, <Object?>[
      repo('acme/api'),
      repo('../../etc'),
      repo('acme/..'),
      repo('a/b/c'),
    ]);

    expect((await github().repositories()).map((each) => each.fullName), <String>['acme/api']);
    expect(GitHub.isFullName('acme/api'), isTrue);
    for (final bad in <String>['../x', 'acme/..', 'acme/.', 'a/b/c', 'acme', 'acme/a b', '']) {
      expect(GitHub.isFullName(bad), isFalse, reason: bad);
    }
  });

  test('the API of a GitHub is api.github.com for github.com, and /api/v3 on one of its own', () {
    expect(GitHub.apiOf('github.com'), Uri.parse('https://api.github.com'));
    expect(GitHub.apiOf('git.example.org'), Uri.parse('https://git.example.org/api/v3'));
  });

  // The harm: on a GitHub of its own every call went to the instance's root, past its /api/v3, so
  // nothing a person asked of it was answered and their token went to pages that are not the API.
  test('a GitHub of its own is asked under its /api/v3, for every call', () async {
    final enterprise = GitHub(
      'ghp_secret-token',
      api: GitHub.apiOf('git.example.org'),
      http: (method, uri, headers, body) async {
        asked.add((method: method, uri: uri, headers: headers, body: body));
        return reply(200, method == 'GET' && uri.path.endsWith('/user') ? <String, String>{'login': 'a'} : <Object>[]);
      },
    );
    await enterprise.whoAmI();
    await enterprise.repositories();
    await enterprise.branches('team/app');
    expect(
      [for (final each in asked) each.uri.path],
      <String>['/api/v3/user', '/api/v3/user/repos', '/api/v3/repos/team/app/branches'],
    );
    expect({for (final each in asked) each.uri.host}, <String>{'git.example.org'});
  });

  // The harm: what is not GitHub's refusal escaped as a raw exception that the forms do not catch,
  // so a button stayed busy for good and nothing was said.
  group('every way a request can fail is said as GitHub refusing it', () {
    GitHub answering(Future<ForgeReply> Function() answer) =>
        GitHub('ghp_secret-token', http: (method, uri, headers, body) => answer());

    test('a page that is not JSON, as a proxy or a captive portal answers', () async {
      final github = answering(() async => (status: 200, body: '<html>sign in</html>', headers: <String, String>{}));
      await expectLater(github.whoAmI(), throwsA(isA<ForgeRefused>()));
      await expectLater(github.repositories(), throwsA(isA<ForgeRefused>()));
    });

    test('JSON of another shape than the call reads', () async {
      final github = answering(() async => reply(200, <String, Object>{}));
      await expectLater(github.repositories(), throwsA(isA<ForgeRefused>()));
      await expectLater(github.branches('team/app'), throwsA(isA<ForgeRefused>()));
      final listing = answering(() async => reply(200, <Object>[]));
      await expectLater(listing.whoAmI(), throwsA(isA<ForgeRefused>()));
    });

    test('a TLS handshake or an HTTP exchange that breaks off', () async {
      await expectLater(
        answering(() => throw const HandshakeException('certificate unknown')).whoAmI(),
        throwsA(isA<ForgeRefused>()),
      );
      await expectLater(
        answering(() => throw const HttpException('Connection closed before full header was received')).whoAmI(),
        throwsA(isA<ForgeRefused>()),
      );
    });
  });

  // The harm: a forge that accepts and then says nothing held the form that asked for good.
  test('a forge that accepts and never answers is said as refusing, within the time given', () async {
    final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final held = <Socket>[];
    silent.listen(held.add);
    addTearDown(() async {
      for (final each in held) {
        each.destroy();
      }
      await silent.close();
    });
    final github = GitHub(
      'ghp_secret-token',
      api: Uri.parse('http://127.0.0.1:${silent.port}'),
      answerWithin: const Duration(seconds: 1),
    );
    await expectLater(github.whoAmI().timeout(const Duration(seconds: 10)), throwsA(isA<ForgeRefused>()));
  });
}
