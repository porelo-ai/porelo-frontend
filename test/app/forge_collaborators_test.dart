import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/forge.dart';

void main() {
  late List<({String method, Uri uri, String? body})> requests;
  late Map<String, ForgeReply> answers;
  ForgeReply reply(int status, Object body) => (status: status, body: jsonEncode(body), headers: <String, String>{});
  GitHub github() => GitHub(
    'test-token',
    http: (method, uri, headers, body) async {
      expect(headers['Authorization'], 'Bearer test-token');
      expect(uri.toString(), isNot(contains('test-token')));
      requests.add((method: method, uri: uri, body: body));
      return answers['$method ${uri.path}?${uri.query}'] ?? answers['$method ${uri.path}'] ?? reply(404, {});
    },
  );
  setUp(() {
    requests = [];
    answers = {};
  });

  // Harm: granting an existing reader can fail or replace their stronger repository permission.
  test('every existing reader permission avoids a second grant', () async {
    answers['PUT /repos/team/access/collaborators/alice'] = reply(500, {'message': 'A second grant failed.'});
    for (final permission in ['read', 'triage', 'write', 'maintain', 'admin']) {
      requests.clear();
      answers['GET /repos/team/access/collaborators/alice/permission'] = reply(200, {'permission': permission});
      expect(await github().grantRead('team/access', 'alice'), 'already has read access');
      expect(requests.map((request) => '${request.method} ${request.uri.path}'), [
        'GET /repos/team/access/collaborators/alice/permission',
      ]);
    }
  });

  // Harm: an unreadable or unknown permission can trigger a grant without confirming that access is absent.
  test('permission failures name the failed call and never grant', () async {
    answers['GET /repos/team/access/collaborators/alice/permission'] = reply(500, {
      'message': 'Permission lookup failed.',
    });
    await expectLater(
      github().grantRead('team/access', 'alice'),
      throwsA(
        isA<ForgeRefused>().having(
          (error) => error.words,
          'forge answer and call',
          allOf(
            contains('GET /repos/team/access/collaborators/alice/permission'),
            contains('Permission lookup failed.'),
          ),
        ),
      ),
    );
    expect(requests.every((request) => request.method == 'GET'), isTrue);
    for (final permission in [null, 'unknown']) {
      answers['GET /repos/team/access/collaborators/alice/permission'] = reply(200, {'permission': permission});
      await expectLater(github().grantRead('team/access', 'alice'), throwsA(isA<ForgeRefused>()));
    }
    expect(requests.where((request) => request.method == 'PUT'), isEmpty);
  });

  // Harm: admin status alone or a refused token must never authorize an unchecked access edit.
  test('Administration is checked and refused calls redact the token', () async {
    answers['GET /repos/team/access'] = reply(200, {
      'permissions': {'admin': false},
    });
    await expectLater(
      github().checkAdministration('team/access'),
      throwsA(isA<ForgeRefused>().having((e) => e.words, 'needed right', contains('Administration: Read and write'))),
    );
    for (final status in [401, 403, 404, 422]) {
      answers['PUT /repos/team/access/collaborators/alice'] = reply(status, {'message': 'test-token was refused'});
      await expectLater(
        github().grantRead('team/access', 'alice'),
        throwsA(
          isA<ForgeRefused>().having(
            (e) => e.words,
            'safe reason',
            allOf(
              isNot(contains('test-token')),
              contains('PUT /repos/team/access/collaborators/alice'),
              contains('[redacted] was refused'),
            ),
          ),
        ),
      );
    }
  });

  // Harm: an unidentifiable malformed answer prevents recovery of an unconfirmed collaborator change.
  for (final operation in ['grantRead', 'readAccess', 'invitations']) {
    for (final payload in ['not JSON', 'wrong shape', 'missing fields', 'invalid fields']) {
      test('$operation names its failed call for $payload in a success payload', () async {
        final invitation = operation == 'invitations';
        final endpoint = invitation
            ? '/repos/team/access/invitations?per_page=100&page=1'
            : '/repos/team/access/collaborators/alice/permission';
        answers['GET /repos/team/access/invitations'] = reply(200, []);
        answers['GET $endpoint'] = switch (payload) {
          'not JSON' => (status: 200, body: '<html>sign in</html>', headers: <String, String>{}),
          'wrong shape' => reply(200, invitation ? {} : []),
          'missing fields' => reply(200, invitation ? [<String, Object>{}] : <String, Object>{}),
          _ => reply(
            200,
            invitation
                ? [
                    {
                      'id': 1,
                      'invitee': {'login': '../alice'},
                    },
                  ]
                : {'permission': 17},
          ),
        };
        await expectLater(
          operation == 'grantRead'
              ? github().grantRead('team/access', 'alice')
              : github().readAccess('team/access', ['alice']),
          throwsA(isA<ForgeRefused>().having((error) => error.words, 'failed call', contains('GET $endpoint'))),
        );
        expect(requests.where((request) => request.method != 'GET'), isEmpty);
      });
    }
  }

  // Harm: an unexpected successful grant status can hide which mutation remains unconfirmed.
  test('an unconfirmed grant names its PUT call', () async {
    answers['PUT /repos/team/access/collaborators/alice'] = reply(200, {});
    await expectLater(
      github().grantRead('team/access', 'alice'),
      throwsA(
        isA<ForgeRefused>().having(
          (error) => error.words,
          'failed call',
          contains('PUT /repos/team/access/collaborators/alice'),
        ),
      ),
    );
  });

  // Harm: adding a developer with greater rights exposes writable private access settings.
  test('the collaborator API requests only pull permission and reads both successful outcomes', () async {
    for (final status in [201, 204]) {
      answers['PUT /repos/team/access/collaborators/alice'] = reply(status, {});
      expect(await github().grantRead('team/access', 'alice'), status == 201 ? 'invited' : 'can read');
      expect(jsonDecode(requests.last.body!), {'permission': 'pull'});
    }
    expect(requests.map((r) => r.method), ['GET', 'PUT', 'GET', 'PUT']);
  });

  // Harm: unsafe components can mutate another API resource with the same token.
  test('repository and collaborator path components are checked before any request', () async {
    for (final name in ['../access', 'team/access/elsewhere', 'team/..']) {
      await expectLater(github().grantRead(name, 'alice'), throwsA(isA<ForgeRefused>()));
    }
    for (final login in ['../alice', 'alice?permission=admin', 'a--b']) {
      await expectLater(github().grantRead('team/access', login), throwsFormatException);
    }
    expect(requests, isEmpty);
  });

  // Harm: missed invitation pages can leave an invitation usable after removal.
  test('pending invitations are paginated and canceled before direct access is removed', () async {
    answers['GET /repos/team/access/invitations?per_page=100&page=1'] = reply(200, [
      for (var n = 0; n < 100; n++)
        {
          'id': n + 1,
          'invitee': {'login': 'user$n'},
        },
    ]);
    answers['GET /repos/team/access/invitations?per_page=100&page=2'] = reply(200, [
      {
        'id': 101,
        'invitee': {'login': 'ALICE'},
      },
    ]);
    answers['DELETE /repos/team/access/invitations/101'] = reply(204, {});
    answers['DELETE /repos/team/access/collaborators/alice'] = reply(204, {});
    await github().revokeRead('team/access', 'alice');
    expect(requests.map((r) => '${r.method} ${r.uri.path}'), [
      'GET /repos/team/access/invitations',
      'GET /repos/team/access/invitations',
      'DELETE /repos/team/access/invitations/101',
      'DELETE /repos/team/access/collaborators/alice',
    ]);
  });

  // Harm: an invitation is not accepted access, and inherited access must not appear revoked.
  test('forge states distinguish invited effective read and absent access', () async {
    answers['GET /repos/team/access/invitations'] = reply(200, [
      {
        'id': 1,
        'invitee': {'login': 'alice'},
      },
    ]);
    answers['GET /repos/team/access/collaborators/bob/permission'] = reply(200, {'permission': 'read'});
    answers['GET /repos/team/access/collaborators/carol/permission'] = reply(404, {});
    expect(await github().readAccess('team/access', ['alice', 'bob', 'carol']), {
      'alice': 'invited',
      'bob': 'can read',
      'carol': 'no read access',
    });
  });

  // Harm: repeated upstream pages can hold the access editor in a loop indefinitely.
  test('a repeated invitation page fails fast', () async {
    answers['GET /repos/team/access/invitations'] = reply(200, [
      for (var n = 0; n < 100; n++)
        {
          'id': n + 1,
          'invitee': {'login': 'user$n'},
        },
    ]);
    await expectLater(
      github().readAccess('team/access', ['alice']),
      throwsA(isA<ForgeRefused>().having((e) => e.words, 'repeated page', contains('repeated'))),
    );
    expect(requests, hasLength(2));
  });
}
