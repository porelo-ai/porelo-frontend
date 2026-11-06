import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/porelo_organization_source.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

/// The fields `porelo org --json` writes.
const _org = {
  'name': 'acme',
  'kept_in': 'the GitHub organization acme',
  'address': 'github.com:acme/org.git',
  'forge': 'github.com',
  'settings': 'adapter: git\nsettings:\n  repository: git@github.com:acme/org.git\n',
  'vouched_by': 'GitHub',
  'revision': '56420b3',
  'stale': false,
  'me': {
    'login': 'alice',
    'card': 'trusted',
    'owner': false,
    'admin_of_hosts': <String>[],
    'projects': [
      {'project': 'demo', 'role': 'admin'},
    ],
  },
  'owners': [
    {'login': 'mia', 'fingerprint': 'SHA256:m', 'backup': false},
  ],
  'people': [
    {
      'login': 'alice',
      'name': 'Alice Example',
      'email': 'alice@example.org',
      'fingerprint': 'SHA256:a',
      'state': 'trusted',
      'vouched': 'yes',
      'expires': '2028-11-02',
      'revoked': false,
      'why': '',
    },
    {'login': 'fay', 'fingerprint': 'SHA256:f', 'state': 'first-seen', 'vouched': 'cannot-say', 'revoked': false},
    {'login': 'rex', 'fingerprint': 'SHA256:r', 'state': 'trusted', 'vouched': 'yes', 'revoked': true},
    {'login': 'zed', 'fingerprint': null, 'state': 'refused', 'vouched': 'no', 'revoked': false, 'why': 'a bad card'},
  ],
  'projects': [
    {
      'project': 'demo',
      'admins': ['alice'],
      'members': ['carol'],
      'first_admin': 'alice',
      'opened': true,
      'host': 'build',
    },
  ],
  'hosts': [
    {
      'host': 'build',
      'address': 'build.example.org',
      'ssh_port': 22,
      'ssh_host_key': 'ssh-ed25519 AAAA',
      'services': {
        'forge': {'web_port': 3000, 'git_port': 2222},
        'matrix': {'port': 8448},
      },
      'admins': [
        {'login': 'hank', 'key': 'ssh-ed25519 AAAA', 'fingerprint': 'SHA256:h', 'backup': false},
      ],
      'projects': ['demo'],
    },
    {
      'host': 'new',
      'address': null,
      'ssh_port': null,
      'ssh_host_key': null,
      'services': null,
      'admins': [
        {'login': 'hank', 'key': 'ssh-ed25519 AAAA', 'fingerprint': 'SHA256:h', 'backup': false},
      ],
      'projects': <String>[],
    },
  ],
  'warnings': ['a warning'],
  'refusals': [
    {'revision': 'e3b390c', 'path': 'hosts/other/host.yml', 'why': 'signed by SHA256:x, not a host admin'},
  ],
  'sole_without_backup': [
    {'role': 'owner', 'host': null, 'login': 'mia'},
  ],
  'a_field_of_later': 1,
};

/// The fields `porelo project show demo --json` writes.
const _project = {
  'project': 'demo',
  'revision': '56420b3',
  'stale': false,
  'matrix_registration_entry': null,
  'first_admin': 'alice',
  'host': 'build',
  'opened': true,
  'address': 'git@github.com:acme/demo.git',
  'me': {'role': 'admin', 'locked': false},
  'members': [
    {'login': 'alice', 'role': 'admin', 'locked': false},
    {'login': 'fay', 'role': 'developer', 'locked': true},
  ],
  'repositories': {
    'state': 'read',
    'revision': 'a1b2c3d',
    'names': [
      {'name': 'app', 'upstream': 'git@github.com:acme/app.git'},
    ],
  },
};

void main() {
  late List<List<String>> asked;
  late Ran Function(List<String>) answer;

  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    expect(program, 'porelo');
    asked.add(arguments);
    return answer(arguments);
  }

  Ran says(Object? json) => (code: 0, out: jsonEncode(json), err: '');

  late PoreloOrganizationSource source;

  setUp(() {
    asked = [];
    answer = (_) => says(_org);
    source = PoreloOrganizationSource(run: run);
  });

  // Harm: a canceled trust choice records a key, or retrying a write under another ID duplicates its effects.
  test('an unknown forge key is confirmed before one retry of the exact request', () async {
    const words = "the forge's ssh host key is not trusted: see 'porelo credentials trust-host forge.example.org:2222'";
    var confirms = 0;
    var trust = false;
    source.confirmForgeHost = (host) async {
      expect(host, 'forge.example.org:2222');
      confirms++;
      return trust;
    };
    answer = (_) => (code: 70, out: jsonEncode({'reason': 'unknown-host-key', 'words': words}), err: '');
    final write = OrganizationWrite(
      change: OrganizationChange.createOrganization,
      input: const {'address': 'git@forge.example.org:acme/access.git'},
      person: '',
      base: '',
      id: 'same-id',
    );
    await expectLater(source.apply(write), throwsA(isA<OrganizationRefused>()));
    expect(asked, hasLength(1), reason: 'cancel must never retry the operation');
    trust = true;
    asked.clear();
    await expectLater(source.apply(write), throwsA(isA<OrganizationRefused>()));
    expect(asked, hasLength(2), reason: 'a repeated unknown-key failure must stop instead of opening a loop');
    expect(asked.first, asked.last, reason: 'a retry must keep the operation ID and every argument');
    expect(confirms, 2, reason: 'each request may ask for trust at most once');
  });

  // Harm: a malformed refusal is interpreted as permission to connect or change a trust store.
  test('a malformed unknown-host refusal opens no trust prompt', () async {
    var confirms = 0;
    source.confirmForgeHost = (_) async {
      confirms++;
      return true;
    };
    answer = (_) => (code: 70, out: '{"reason":"unknown-host-key","words":[]}', err: '');
    await expectLater(source.read(), throwsA(isA<OrganizationRefused>()));
    expect(confirms, 0);
    expect(asked, hasLength(1));
  });

  // Harm: an organization write reaches Core while its vault or token preparation was canceled.
  test('forge preparation precedes creation and opening and refusal prevents the write', () async {
    const repository = 'git@forge.example.org:acme/access.git';
    final prepared = <String>[];
    source.prepareForgeWrite = (address) async {
      prepared.add(address);
      throw const OrganizationRefused('The vault is shut.');
    };
    for (final change in [OrganizationChange.createOrganization, OrganizationChange.createProjectRepository]) {
      answer = (_) => says({..._org, 'address': repository});
      await expectLater(
        source.apply(
          OrganizationWrite(
            change: change,
            input: const {'address': repository, 'project': 'demo'},
            person: 'alice',
            base: 'base',
            id: 'id',
          ),
        ),
        throwsA(isA<OrganizationRefused>()),
      );
    }
    expect(prepared, [repository, repository]);
    expect(asked, [
      ['org', '--json'],
    ], reason: 'only the read needed to find the project forge may run');
  });

  group('reading', () {
    // Harm: a bad answer about who the Organization Admins are reads as the owners' rule, and widens rights.
    for (final (bad, name) in [
      ('nobody', 'a word'),
      (<Object?>['alice', 1], 'a list with something else'),
    ]) {
      test('Organization Admins given as $name cannot be said', () async {
        answer = (_) => says({..._org, 'organization_admins': bad});
        await expectLater(source.read(), throwsA(isA<OrganizationRefused>()));
      });
    }

    test('Organization Admins absent or listed read as they stand', () async {
      expect((await source.read()).organizationAdmins, isNull);
      answer = (_) => says({
        ..._org,
        'organization_admins': ['alice'],
      });
      expect((await source.read()).organizationAdmins, ['alice']);
    });

    // Harm: a page shows something Porelo did not say.
    test("the organization is read from the contract's example", () async {
      final view = await source.read();
      expect(asked.single, ['org', '--json']);
      expect(view.name, 'acme');
      expect(view.keptIn, 'the GitHub organization acme');
      expect(view.forge, 'github.com', reason: 'a host pins this forge by it');
      expect(view.settings, startsWith('adapter: git\n'), reason: 'a host follows the organization by it, unread');
      expect(view.vouchedBy, 'GitHub');
      expect(view.revision, '56420b3');
      expect(view.me, 'alice');
      expect(view.stale, isFalse);
      expect(view.owners, ['mia']);
      expect(view.projects.single.admins, ['alice']);
      expect(view.projects.single.members, ['carol']);
      expect(view.projects.single.host, 'build');
      expect(view.notes, [
        'a warning',
        'A change was refused at hosts/other/host.yml: signed by SHA256:x, not a host admin.',
        'mia is the only owner and has no backup key.',
      ]);
    });

    // Harm: an owner with no backup key reads as having one, and nobody makes the one that is missing.
    test('only an owner who has a backup key is said to have one', () async {
      answer = (_) => says({
        ..._org,
        'owners': [
          {'login': 'ana', 'fingerprint': 'SHA256:a', 'backup': false},
          {'login': 'mia', 'fingerprint': 'SHA256:m', 'backup': false},
          {'login': 'mia', 'fingerprint': 'SHA256:b', 'backup': true},
        ],
      });
      expect((await source.read()).ownersWithBackup, ['mia']);
    });

    // Harm: a backup key reads as a second owner or admin of the same login, and the last one's words go wrong.
    test('a backup key is no second owner or host admin, and a card says until when it holds', () async {
      answer = (_) => says({
        ..._org,
        'owners': [
          {'login': 'mia', 'fingerprint': 'SHA256:m', 'backup': false},
          {'login': 'mia', 'fingerprint': 'SHA256:b', 'backup': true},
        ],
        'hosts': [
          {
            ...((_org['hosts']! as List<Object?>).first! as Map<String, Object?>),
            'admins': [
              {'login': 'hank', 'key': 'ssh-ed25519 AAAA', 'fingerprint': 'SHA256:h', 'backup': false},
              {'login': 'hank', 'backup': true},
            ],
          },
        ],
      });
      final view = await source.read();
      expect(view.owners, ['mia']);
      expect(view.hosts.single.admins, ['hank']);
      expect(view.persons.first.login, 'alice');
      expect(view.persons.first.expires, '2028-11-02');
    });

    // Harm: a machine carrying only some of a project's repositories reads as carrying it whole.
    test('a host names the repositories it carries of a project carried in part, and no others', () async {
      answer = (_) => says({
        ..._org,
        'hosts': [
          {
            ...((_org['hosts']! as List<Object?>).first! as Map<String, Object?>),
            'projects': ['whole', 'part'],
            'repositories': {
              'part': ['api', 'web'],
            },
          },
        ],
      });
      final host = (await source.read()).hosts.single;
      expect(host.repositories, {
        'part': ['api', 'web'],
      });
      expect(host.carriesWhole('whole'), isTrue);
      expect(host.carriesWhole('part'), isFalse);
    });

    // Harm: a part the answer garbles reads as the whole project, and no other machine is offered the rest.
    test('a host whose carried repositories do not read is refused, never read as carrying the whole', () async {
      answer = (_) => says({
        ..._org,
        'hosts': [
          {
            ...((_org['hosts']! as List<Object?>).first! as Map<String, Object?>),
            'projects': ['part'],
            'repositories': {'part': 'api'},
          },
        ],
      });
      await expectLater(source.read(), throwsA(isA<OrganizationRefused>()));
    });

    // Harm: a card is shown as holding what it does not, and a role is taken from a card that holds it.
    test('a card stands as the rule says: trusted and first-seen hold, revoked and refused do not', () async {
      final view = await source.read();
      CardStanding standing(String login) => view.persons.singleWhere((each) => each.login == login).standing;
      expect(standing('alice'), CardStanding.trusted);
      expect(standing('fay'), CardStanding.notYet);
      expect(standing('rex'), CardStanding.revoked);
      expect(standing('zed'), CardStanding.refused);
      expect(view.holdingRoles.map((each) => each.login), ['alice', 'fay']);
      expect(view.persons.singleWhere((each) => each.login == 'fay').words, contains('GitHub cannot say'));
      expect(view.persons.singleWhere((each) => each.login == 'zed').words, 'a bad card');
    });

    // Harm: Connect is offered with no address, or pins nothing.
    test('a host is read with its services, and one just added with nothing yet', () async {
      final view = await source.read();
      final build = view.hosts.first;
      expect(build.address, 'build.example.org');
      expect(build.port, 22);
      expect(build.hostKey, 'ssh-ed25519 AAAA');
      expect((build.webPort, build.gitPort, build.matrixPort), (3000, 2222, 8448));
      expect(build.admins, ['hank']);
      final fresh = view.hosts.last;
      expect((fresh.address, fresh.port, fresh.hostKey, fresh.webPort), (null, null, null, null));
    });

    // Harm: a person with no card is offered nothing, or is named someone.
    test('a person with no card is nobody, and sees Add me', () async {
      answer = (_) => says({..._org, 'me': null});
      final view = await source.read();
      expect(view.myCard, isNull);
      expect(view.holdsRoles, isFalse);
    });

    // Harm: a locked member reads as a working one, or a local project vanishes.
    // Harm: other programs' words read wrongly: Core's own answer is the contract.
    test('asking what founding needs takes Core\'s words and files nothing', () async {
      answer = (_) => says({
        'ready': false,
        'followable': true,
        'needs': [
          {'name': 'token', 'state': 'cannot-tell', 'words': 'The vault is shut.', 'next': 'porelo vault unlock'},
          {'name': 'card', 'state': 'ready', 'words': 'You have a card.', 'next': null},
        ],
      });
      final needs = await source.checkFounding('git@forge.example.org:acme/org.git', replace: true);
      expect(asked.single, ['org', 'create', 'git@forge.example.org:acme/org.git', '--check', '--replace', '--json']);
      expect(needs.first.state, 'cannot-tell');
      expect(needs.first.next, 'porelo vault unlock');
      expect(needs.last.next, isNull);
    });

    test('project list is read with where each comes from, and who is locked', () async {
      answer = (_) => says({
        'revision': 'r',
        'projects': [
          {
            'project': 'demo',
            'source': 'organization',
            'role': 'admin',
            'locked': true,
            'host': 'build',
            'opened': true,
          },
          {'project': 'mine', 'source': 'local', 'role': null, 'locked': false, 'host': null, 'opened': null},
          {'project': 'default', 'source': 'built-in', 'role': null, 'locked': false, 'host': null, 'opened': null},
        ],
      });
      final listed = await source.myProjects();
      expect(asked.single, ['project', 'list', '--json']);
      expect(listed.first.ofTheOrganization, isTrue);
      expect(listed.first.locked, isTrue);
      expect(listed.first.host, 'build');
      expect([for (final project in listed) project.source], ['organization', 'local', 'built-in']);
    });

    // Harm: a malformed word on freshness passes a state the store could not vouch for as fresh.
    test('an organization whose stale is no truth value is an unreadable answer', () async {
      answer = (_) => says({..._org, 'stale': 'true'});
      await expectLater(source.read(), throwsA(isA<OrganizationRefused>()));
    });

    // Harm: the built-in project, which a person with no organization always has, makes the whole list unreadable.
    test('a list as the command answers with no organization holds the built-in project', () async {
      answer = (_) => says({
        'revision': null,
        'stale': false,
        'projects': [
          {'project': 'default', 'source': 'built-in', 'role': null, 'locked': false, 'host': null, 'opened': null},
        ],
      });
      final listed = await source.myProjects();
      expect(listed.single.name, 'default');
      expect(listed.single.ofTheOrganization, isFalse);
    });

    // Harm: a card whose revocation the answer does not state counts as trusted, and goes into a new host's pin.
    for (final revoked in <Object?>[null, 'true', 0]) {
      test('a person whose revoked reads $revoked is not trusted', () async {
        answer = (_) => says({
          ..._org,
          'people': [
            {'login': 'alice', 'fingerprint': 'SHA256:a', 'state': 'trusted', 'vouched': 'yes', 'revoked': revoked},
          ],
        });
        final view = await source.read();
        expect(view.persons.single.standing, isNot(CardStanding.trusted));
      });
    }

    // Harm: a stale listing permits a removal based on an unverified source.
    test('a project list whose stale is no truth value is an unreadable answer', () async {
      answer = (_) => says({
        'revision': 'r',
        'stale': 'true',
        'projects': [
          {'project': 'demo', 'source': 'organization', 'role': 'admin', 'locked': false, 'host': 'b', 'opened': true},
        ],
      });
      await expectLater(source.myProjects(), throwsA(isA<OrganizationRefused>()));
    });

    // Harm: a row whose lock cannot be read is taken for one not locked, and a locked person moves work.
    test('a project row with no readable lock is an unreadable answer', () async {
      answer = (_) => says({
        'revision': 'r',
        'projects': [
          {'project': 'demo', 'source': 'organization', 'role': 'admin', 'host': 'build', 'opened': true},
        ],
      });
      await expectLater(source.myProjects(), throwsA(isA<OrganizationRefused>()));
    });

    // Harm: the last state read, from when the store was out of reach, passes as a fresh list and decides a removal.
    test('a project list the store could not vouch for says so on each project', () async {
      answer = (_) => says({
        'revision': 'r',
        'stale': true,
        'projects': [
          {'project': 'mine', 'source': 'local', 'role': null, 'locked': false, 'host': null, 'opened': null},
        ],
      });
      expect((await source.myProjects()).single.stale, isTrue);
    });

    // Harm: a person's Connect writes no key, or the whole of an answer whose other fields have moved on is refused.
    test("the person's public key is read from identity show, whatever else it answers", () async {
      answer = (_) => says({
        'key': 'ssh-ed25519 AAAA',
        'organization': <Object?>[],
        'pending': [
          {'id': 'old-change', 'action': 'rotate', 'fingerprint': 'SHA256:old'},
          {'id': 'lost-change', 'action': 'revoke-lost', 'fingerprint': 'SHA256:new'},
        ],
        'later': 1,
      });
      expect(await source.myPublicKey(), 'ssh-ed25519 AAAA');
      expect(asked.single, ['identity', 'show', '--json']);
    });

    // Harm: a state from before a store went away reads as today's.
    test('a stale state is said to be stale', () async {
      answer = (_) => says({..._org, 'stale': true});
      expect((await source.read()).stale, isTrue);
    });

    // Harm: a change to a member is refused because only project.yml moved, or the other way round.
    test('a project is read with both of its revisions, and its members as the organization stands them', () async {
      await source.read();
      answer = (_) => says(_project);
      final view = await source.readProject('demo');
      expect(asked.last, ['project', 'show', 'demo', '--json']);
      expect(view.revision, '56420b3');
      expect(view.repositoriesRevision, 'a1b2c3d');
      expect(view.address, 'git@github.com:acme/demo.git');
      expect(view.repositories.single.address, 'git@github.com:acme/app.git');
      final fay = view.members.singleWhere((each) => each.login == 'fay');
      expect((fay.role, fay.locked, fay.standing), ('developer', true, CardStanding.notYet));
      expect(view.roles, ['developer', 'admin']);
    });

    // Harm: "could not say" reads as a project with no repositories.
    test('repositories that could not be read are said, never taken for none', () async {
      answer = (_) => says({
        ..._project,
        'repositories': {'state': 'cannot-say', 'revision': null, 'names': <Object>[]},
      });
      final view = await source.readProject('demo');
      expect(view.repositoriesProblem, contains('could not be read'));
      expect(view.repositoriesRevision, isNull);
    });

    // Harm: a project on this machine alone becomes unreadable, and is no longer matched to a forge by its upstreams.
    test('a project with no organization is read, its repositories with their upstreams', () async {
      answer = (_) => says({
        'project': 'solo',
        'revision': null,
        'first_admin': null,
        'host': null,
        'opened': null,
        'address': null,
        'me': null,
        'members': <Object>[],
        'repositories': {
          'state': 'read',
          'revision': null,
          'names': [
            {'name': 'app', 'upstream': 'git@github.com:acme/app.git'},
          ],
        },
      });
      final view = await source.readProject('solo');
      expect(view.name, 'solo');
      expect(view.repositoriesProblem, isNull);
      expect(view.repositories.single.name, 'app');
      expect(view.repositories.single.address, 'git@github.com:acme/app.git');
      expect(view.host, isNull);
      expect(view.members, isEmpty);
      final known = await Organization(source).readAddress('solo');
      expect((known.address, known.problem), (null, null));
    });

    // Harm: a repository without an upstream hides the whole project and its members.
    test('a repository with no upstream keeps its name and has no address', () async {
      answer = (_) => says({
        ..._project,
        'repositories': {
          'state': 'read',
          'revision': 'p1',
          'names': [
            {'name': 'scratch', 'upstream': null},
          ],
        },
      });
      final project = await source.readProject('demo');
      expect(project.repositories.single.name, 'scratch');
      expect(project.repositories.single.address, isNull);
      expect(project.members, hasLength(2));
    });

    // Harm: a project whose review is required reads as one nobody can say about, and its next repository loses the policy.
    test('the review policy of a project and of each repository is read as Core answers it', () async {
      answer = (_) => says({
        ..._project,
        'repositories': {
          'state': 'read',
          'revision': 'p1',
          'names': [
            {'name': 'app', 'upstream': 'git@github.com:acme/app.git', 'review': 'optional'},
            {'name': 'docs', 'upstream': 'git@github.com:acme/docs.git', 'review': 'required'},
          ],
          'review': 'required',
          'file_signer': 'alice',
        },
      });
      final project = await source.readProject('demo');
      expect(project.review, 'required');
      expect([for (final repository in project.repositories) repository.review], ['optional', 'required']);
    });

    // Harm: every row reads as fine, so one a machine takes nothing from goes unsaid; or every row of an
    // older Porelo, which does not say, is warned about.
    test('a row names no central only where Core says it is empty', () async {
      answer = (_) => says({
        ..._project,
        'repositories': {
          'state': 'read',
          'revision': 'p1',
          'names': [
            {'name': 'none', 'upstream': 'x', 'central': ''},
            {'name': 'has', 'upstream': 'x', 'central': 'y'},
            {'name': 'older', 'upstream': 'x'},
          ],
        },
      });
      final project = await source.readProject('demo');
      expect([for (final repository in project.repositories) repository.namesNoCentral], [true, false, false]);
    });

    // Harm: a project with its repository unmade reads as any other; or, on an older Porelo that does not
    // say, every project reads as one without.
    test('a project says whether its repository is filed only where Core says', () async {
      answer = (_) => says({
        ..._org,
        'projects': [
          {'project': 'none', 'admins': <String>[], 'members': <String>[], 'opened': false},
          {'project': 'has', 'admins': <String>[], 'members': <String>[], 'opened': true},
          {'project': 'older', 'admins': <String>[], 'members': <String>[]},
        ],
      });
      final view = await source.read();
      expect([for (final project in view.projects) project.hasNoRepository], [true, false, false]);
    });

    // Harm: a key that cannot sign is offered.
    test('only usable keys are offered, each as the forge lists it', () async {
      answer = (_) => says({
        'keys': [
          {'fingerprint': 'SHA256:a', 'key': 'ssh-ed25519 A', 'comment': 'mine', 'usable': true, 'key_listed': true},
          {'fingerprint': 'SHA256:b', 'key': 'ssh-ed25519 B', 'comment': 'x', 'usable': true, 'key_listed': false},
          {'fingerprint': 'SHA256:c', 'key': 'ssh-ed25519 C', 'comment': 'y', 'usable': true, 'key_listed': null},
          {'fingerprint': 'SHA256:d', 'key': 'ssh-rsa D', 'comment': 'z', 'usable': false, 'reason': 'key-not-ed25519'},
        ],
      });
      final keys = await source.myKeys();
      expect(asked.single, ['identity', 'keys', '--json']);
      expect(keys.map((key) => key.vouched), [true, false, null]);
      expect(keys.first.label, 'mine');
    });
  });

  group('what is not an answer', () {
    Future<OrganizationRefused> refusal() async {
      try {
        await source.read();
      } on OrganizationRefused catch (refused) {
        return refused;
      }
      fail('it was not refused');
    }

    // Harm: a person reads a stack trace, or nothing.
    test("a refusal is said in Porelo's words, and its reason is kept", () async {
      answer = (_) => (
        code: 65,
        out: '{"reason": "moved-on", "words": "the organization moved on", "revision": "56420b3"}',
        err: 'the organization moved on',
      );
      final refused = await refusal();
      expect(refused.words, 'the organization moved on');
      expect(refused.reason, 'moved-on');
      expect(refused.answered, isTrue);
    });

    // Harm: an empty organization repository is treated as a readable empty organization.
    test('an empty repository cannot say what the organization is', () async {
      answer = (_) => (
        code: 69,
        out: jsonEncode({'reason': 'cannot-say', 'words': 'the organization cannot be read', 'revision': null}),
        err: '',
      );
      final refused = await refusal();
      expect(refused.reason, 'cannot-say');
      expect(refused.answered, isFalse);
    });

    // Harm: a refusal hides the earlier change and sends the person into another rotation.
    test('a change that may have reached the store names its old id and lost key recovery', () async {
      answer = (_) => (
        code: 65,
        out: jsonEncode({
          'reason': 'exists',
          'words': 'the change old-change reached the organization or may have: go on with that id, or with porelo identity revoke --lost',
          'revision': 'r',
          'id': 'old-change',
        }),
        err: '',
      );
      await expectLater(
        source.apply(
          const OrganizationWrite(
            change: OrganizationChange.changeCard,
            input: {'key': 'SHA256:new'},
            person: 'alice',
            base: 'b',
            id: 'new-change',
          ),
        ),
        throwsA(
          isA<OrganizationRefused>()
              .having((refused) => refused.reason, 'reason', 'exists')
              .having((refused) => refused.words, 'old change', contains('old-change'))
              .having((refused) => refused.words, 'recovery command', contains('identity revoke --lost'))
              .having((refused) => refused.answered, 'new request was refused', isTrue),
        ),
      );
    });

    // Harm: asking again under a new id does the change twice; under the old one after it was refused, nothing.
    for (final (code, answered) in const [
      (64, true),
      (65, true),
      (66, true),
      (69, false),
      (70, false),
      (77, true),
      (78, true),
      (-9, false),
    ]) {
      test('exit $code ${answered ? 'made nothing' : 'may have made it, so the id stays'}', () async {
        answer = (_) => (code: code, out: '{"reason": "x", "words": "said"}', err: '');
        expect((await refusal()).answered, answered);
      });
    }

    // Harm: what the program wrote elsewhere, which may name a path or more, reaches the screen.
    test('a refusal with no words says so, and never what was written aside', () async {
      answer = (_) => (code: 70, out: 'garbage', err: 'a trace with /private/example/secret in it');
      final refused = await refusal();
      expect(refused.words, contains('did not say why'));
      expect(refused.words, isNot(contains('secret')));
    });

    // Harm: an answer that cannot be read is shown as an empty organization.
    for (final (name, out) in [
      ('no JSON', 'not json'),
      ('a list', '[]'),
      ('a field of the wrong kind', jsonEncode({..._org, 'name': 3})),
      (
        'a person of the wrong kind',
        jsonEncode({
          ..._org,
          'people': ['alice'],
        }),
      ),
    ]) {
      test('an unreadable answer, $name, is refused', () async {
        answer = (_) => (code: 0, out: out, err: '');
        final refused = await refusal();
        expect(refused.words, contains('could not be read'));
        expect(refused.answered, isFalse);
      });
    }

    // Harm: a field added later breaks every older interface.
    test('a field this build does not know is passed over', () async {
      expect((await source.read()).name, 'acme');
    });

    // Harm: a missing command line reads as a broken organization.
    test('no command line to run is said', () async {
      final none = PoreloOrganizationSource(
        run: (program, arguments, {inDirectory, environment = const {}, input}) async =>
            throw const ProcessException('porelo', []),
      );
      await expectLater(
        none.read(),
        throwsA(
          isA<OrganizationRefused>().having((refused) => refused.words, 'words', contains('could not be started')),
        ),
      );
    });
  });

  group('writes', () {
    Future<List<String>> asking(OrganizationChange change, Map<String, String> input) async {
      answer = (_) => says({'revision': '9d0fcc5', 'id': 'i', 'again': false});
      await source.apply(OrganizationWrite(change: change, input: input, person: 'alice', base: 'b', id: 'i'));
      return asked.last;
    }

    // Harm: a partial host update is refused locally instead of reaching the command that preserves other fields.
    test('changing a host address alone leaves the other fields to the command', () async {
      expect(await asking(OrganizationChange.changeHost, {'host': 'h', 'address': 'build.example.org'}), [
        'org',
        'host',
        'change',
        'h',
        '--address',
        'build.example.org',
        '--base',
        'b',
        '--id',
        'i',
        '--json',
      ]);
    });

    // Harm: founding from a local repository is shown as a successful organization.
    test('a file address is refused by org create', () async {
      answer = (arguments) {
        expect(arguments.take(3), ['org', 'create', 'file:///example/organization.git']);
        return (
          code: 64,
          out: jsonEncode({'reason': 'usage', 'words': 'that address is none', 'revision': null}),
          err: '',
        );
      };
      await expectLater(
        source.apply(
          const OrganizationWrite(
            change: OrganizationChange.createOrganization,
            input: {'address': 'file:///example/organization.git'},
            person: '',
            base: '',
            id: 'i',
          ),
        ),
        throwsA(isA<OrganizationRefused>().having((refused) => refused.reason, 'reason', 'usage')),
      );
    });

    // Harm: a page's change runs another command than the contract's, or as another person.
    for (final (change, input, command) in <(OrganizationChange, Map<String, String>, List<String>)>[
      (OrganizationChange.addOrganizationOwner, {'login': 'a'}, ['org', 'owner', 'add', 'a']),
      (OrganizationChange.addOrganizationAdmin, {'login': 'ann'}, ['org', 'admin', 'add', 'ann']),
      (OrganizationChange.removeOrganizationAdmin, {'login': 'ann'}, ['org', 'admin', 'remove', 'ann']),
      (OrganizationChange.removeOrganizationOwner, {'login': 'a'}, ['org', 'owner', 'remove', 'a']),
      (OrganizationChange.revokeCard, {'login': 'a'}, ['org', 'person', 'revoke', 'a']),
      (OrganizationChange.replaceCard, {'login': 'a', 'card': 'f'}, ['org', 'person', 'replace', 'a', '--card', 'f']),
      (OrganizationChange.addProject, {'project': 'p', 'admin': 'a'}, ['org', 'project', 'add', 'p', '--admin', 'a']),
      (OrganizationChange.removeProject, {'project': 'p'}, ['org', 'project', 'remove', 'p']),
      (OrganizationChange.changeProjectAdmin, {'project': 'p', 'admin': 'a'}, ['org', 'project', 'admin', 'p', 'a']),
      (OrganizationChange.addHost, {'host': 'h', 'admin': 'a'}, ['org', 'host', 'add', 'h', '--admin', 'a']),
      (OrganizationChange.removeHost, {'host': 'h'}, ['org', 'host', 'remove', 'h']),
      (
        OrganizationChange.changeHost,
        {'host': 'h', 'address': 'x', 'port': '22', 'hostKey': 'k', 'webPort': '1', 'gitPort': '2', 'matrixPort': '3'},
        [
          'org',
          'host',
          'change',
          'h',
          '--address',
          'x',
          '--ssh-port',
          '22',
          '--host-key',
          'k',
          '--forge-web-port',
          '1',
          '--forge-git-port',
          '2',
          '--matrix-port',
          '3',
        ],
      ),
      (OrganizationChange.addHostAdmin, {'host': 'h', 'login': 'a'}, ['org', 'host', 'admin', 'add', 'h', 'a']),
      (OrganizationChange.removeHostAdmin, {'host': 'h', 'login': 'a'}, ['org', 'host', 'admin', 'remove', 'h', 'a']),
      (OrganizationChange.addProjectToHost, {'host': 'h', 'project': 'p'}, ['org', 'host', 'carry', 'h', 'p']),
      (OrganizationChange.removeProjectFromHost, {'host': 'h', 'project': 'p'}, ['org', 'host', 'uncarry', 'h', 'p']),
      // Harm: a whole project carried, or taken off, when some of its repositories were meant.
      (
        OrganizationChange.addProjectToHost,
        {'host': 'h', 'project': 'p', 'repositories': 'api,web'},
        ['org', 'host', 'carry', 'h', 'p', '--repository', 'api', '--repository', 'web'],
      ),
      (
        OrganizationChange.removeProjectFromHost,
        {'host': 'h', 'project': 'p', 'repositories': 'api'},
        ['org', 'host', 'uncarry', 'h', 'p', '--repository', 'api'],
      ),
      (
        OrganizationChange.addProject,
        {'project': 'p', 'admin': 'a', 'review': 'optional'},
        ['org', 'project', 'add', 'p', '--admin', 'a', '--create-repository', '--review', 'optional'],
      ),
      (OrganizationChange.createProjectRepository, {'project': 'p'}, ['project', 'create-repository', 'p']),
      (OrganizationChange.changeProjectRepository, {'project': 'p', 'address': 'x'}, ['project', 'address', 'p', 'x']),
      (
        OrganizationChange.addProjectMember,
        {'project': 'p', 'login': 'a', 'role': 'admin'},
        ['project', 'member', 'add', 'p', 'a', '--role', 'admin'],
      ),
      (
        OrganizationChange.changeProjectMemberRole,
        {'project': 'p', 'login': 'a', 'role': 'developer'},
        ['project', 'member', 'role', 'p', 'a', 'developer'],
      ),
      (
        OrganizationChange.removeProjectMember,
        {'project': 'p', 'login': 'a'},
        ['project', 'member', 'remove', 'p', 'a'],
      ),
      (OrganizationChange.lockProjectMember, {'project': 'p', 'login': 'a'}, ['project', 'member', 'lock', 'p', 'a']),
      (
        OrganizationChange.unlockProjectMember,
        {'project': 'p', 'login': 'a'},
        ['project', 'member', 'unlock', 'p', 'a'],
      ),
      (
        OrganizationChange.changeHost,
        {'host': 'h', 'address': 'x', 'port': '22', 'hostKey': 'k', 'webPort': '', 'gitPort': '', 'matrixPort': ''},
        ['org', 'host', 'change', 'h', '--address', 'x', '--ssh-port', '22', '--host-key', 'k'],
      ),
      (
        OrganizationChange.changeHost,
        {'host': 'h', 'address': 'x', 'port': '22', 'hostKey': 'k', 'matrixPort': 'none'},
        [
          'org',
          'host',
          'change',
          'h',
          '--address',
          'x',
          '--ssh-port',
          '22',
          '--host-key',
          'k',
          '--matrix-port',
          'none',
        ],
      ),
      (OrganizationChange.changeCard, {'key': 'SHA256:k'}, ['identity', 'rotate', '--key', 'SHA256:k']),
      (
        OrganizationChange.addCard,
        {'key': 'SHA256:k', 'login': 'a', 'name': 'A B'},
        ['identity', 'create', '--login', 'a', '--name', 'A B', '--key', 'SHA256:k'],
      ),
      (
        OrganizationChange.addCard,
        {'key': 'SHA256:k', 'login': 'a', 'name': 'A B', 'email': 'a@b'},
        ['identity', 'create', '--login', 'a', '--name', 'A B', '--email', 'a@b', '--key', 'SHA256:k'],
      ),
    ]) {
      test('${change.name} runs ${command.take(3).join(' ')}, with its base and id', () async {
        expect(await asking(change, input), [...command, '--base', 'b', '--id', 'i', '--json']);
      });
    }

    for (final (change, input, command) in <(OrganizationChange, Map<String, String>, List<String>)>[
      (
        OrganizationChange.addProjectRepository,
        {'project': 'p', 'repository': 'r', 'address': 'x'},
        ['project', 'repository', 'add', 'p', 'r', '--upstream', 'x'],
      ),
      (
        OrganizationChange.nameRepositoryCentral,
        {'project': 'p', 'repository': 'r', 'central': 'x'},
        ['project', 'repository', 'change', 'p', 'r', '--central', 'x'],
      ),
      (
        OrganizationChange.removeProjectRepository,
        {'project': 'p', 'repository': 'r'},
        ['project', 'repository', 'remove', 'p', 'r'],
      ),
      (
        OrganizationChange.changeProjectReview,
        {'project': 'p', 'review': 'optional'},
        ['project', 'review', 'p', 'optional'],
      ),
    ]) {
      // Harm: a revision or id Porelo no longer takes refuses every change to a project's own file, and the person never
      // learns the entry to write.
      test('${change.name} runs ${command.take(3).join(' ')} with no base or id, and answers the entry', () async {
        answer = (_) => (
          code: 65,
          out: jsonEncode({
            'reason': 'by-hand',
            'words': 'Porelo changes no project file: …',
            'entry': 'repositories:\n  r: {}\n',
            'revision': null,
          }),
          err: '',
        );
        await expectLater(
          source.apply(OrganizationWrite(change: change, input: input, person: 'alice', base: 'b', id: 'i')),
          throwsA(
            isA<ProjectFileByHand>()
                .having((byHand) => byHand.entry, 'entry', 'repositories:\n  r: {}\n')
                .having((byHand) => byHand.project, 'project', 'p'),
          ),
        );
        expect(asked.last, [...command, '--json']);
      });
    }

    // Harm: a removal, which has nothing to write, reads as refused, or a cut-up entry is committed wrong.
    test('a by-hand answer with no entry is said in its own words, and as nothing changed', () async {
      answer = (_) =>
          (code: 65, out: jsonEncode({'reason': 'by-hand', 'words': 'add this entry: …', 'revision': null}), err: '');
      await expectLater(
        source.apply(
          const OrganizationWrite(
            change: OrganizationChange.removeProjectRepository,
            input: {'project': 'p', 'repository': 'r'},
            person: 'alice',
            base: 'b',
            id: 'i',
          ),
        ),
        throwsA(
          isA<ProjectFileByHand>()
              .having((byHand) => byHand.entry, 'entry', isNull)
              .having((byHand) => byHand.words, 'words', 'add this entry: …'),
        ),
      );
    });

    // Harm: an older Porelo wrote and signed the change itself; read as refused, asking again commits it twice.
    test('an older Porelo that wrote the change itself is taken as written', () async {
      answer = (_) => says({'revision': '9d0fcc5', 'id': 'org-1', 'again': false, 'of': 'project'});
      await source.apply(
        const OrganizationWrite(
          change: OrganizationChange.addProjectRepository,
          input: {'project': 'p', 'repository': 'r', 'address': 'x'},
          person: 'alice',
          base: '',
          id: '',
        ),
      );
      expect(asked.last, ['project', 'repository', 'add', 'p', 'r', '--upstream', 'x', '--json']);
    });

    // Harm: a first organization cannot be made, or a set-up runs with an id or base the contract does not take.
    test('a write with nothing accepted yet names no base', () async {
      answer = (_) => says({'revision': 'r', 'id': 'i', 'again': false});
      await source.apply(
        const OrganizationWrite(
          change: OrganizationChange.addCard,
          input: {'key': 'SHA256:k', 'login': 'a', 'name': 'A'},
          person: '',
          base: '',
          id: 'i',
        ),
      );
      expect(asked.last, [
        'identity',
        'create',
        '--login',
        'a',
        '--name',
        'A',
        '--key',
        'SHA256:k',
        '--id',
        'i',
        '--json',
      ]);
    });

    // Harm: an unsupported base makes founding fail after an organization was read.
    test('creating fills a repository under an id, and no base', () async {
      answer = (_) => says({'revision': 'r', 'id': 'i', 'again': false, 'address': 'x'});
      await source.apply(
        const OrganizationWrite(
          change: OrganizationChange.createOrganization,
          input: {'address': 'x'},
          person: '',
          base: 'b',
          id: 'i',
        ),
      );
      expect(asked.last, ['org', 'create', 'x', '--id', 'i', '--json']);
    });

    for (final (input, command) in <(Map<String, String>, List<String>)>[
      ({'address': 'x'}, ['setup', '--organization', 'x', '--json']),
      ({'address': 'x', 'replace': 'yes'}, ['setup', '--organization', 'x', '--replace', '--json']),
    ]) {
      // Harm: an unsupported base or id prevents choosing an organization.
      test('choosing runs ${command.join(' ')}', () async {
        answer = (_) => says({'revision': null});
        await source.apply(
          OrganizationWrite(
            change: OrganizationChange.chooseOrganization,
            input: input,
            person: '',
            base: 'b',
            id: 'i',
          ),
        );
        expect(asked.last, command);
      });
    }

    // Harm: a change missing what it needs runs a command that means something else.
    test('a change missing what it needs is refused, and nothing runs', () async {
      await expectLater(asking(OrganizationChange.removeHost, {}), throwsA(isA<OrganizationRefused>()));
      expect(asked, isEmpty);
    });
  });
}
