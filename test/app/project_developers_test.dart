// The access checkout protects its files with chmod on Linux.
@Tags(['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_checkout.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/project_developers.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/ui/project_developers_dialog.dart';
import 'package:yaml/yaml.dart';
import 'package:porelo_host/porelo_host.dart' show HostAdminRefused;

const ssh = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
final wg = base64Encode(List.filled(32, 1));

class FixtureAccess extends AccessCheckout {
  FixtureAccess(this.directory)
    : super(
        root: directory.path,
        project: 'demo',
        repository: 'https://github.com/team/access.git',
        signingKey: File('${directory.path}/signer.pub'),
      );
  final Directory directory;
  int published = 0;
  bool bundleFails = false;
  String publishedCommit = 'b' * 40;
  String? bundlePath;
  String get bundleContents => 'bundle for $publishedCommit';
  @override
  String get folder => directory.path;
  @override
  Future<void> open() async {}
  @override
  Future<void> close() async {}
  @override
  Future<String> revision() async => publishedCommit;
  @override
  Future<void> edit(String Function(String) change) async {
    final file = File('$folder/access.yml');
    await file.writeAsString(change(await file.readAsString()));
  }

  @override
  Future<void> commitPushAndBundle(
    String bundle, {
    String message = 'Set project host and Matrix access',
    void Function(String revision)? onPublished,
  }) async {
    published++;
    onPublished?.call(publishedCommit);
    await bundlePublished(bundle, publishedCommit);
  }

  @override
  Future<void> bundlePublished(String bundle, String published) async {
    if (bundleFails) throw const WorkspaceRefused('The local bundle could not be created.');
    if (published != publishedCommit) throw const WorkspaceRefused('Another access commit.');
    bundlePath = bundle;
    await File(bundle).writeAsString(bundleContents);
  }
}

void main() {
  late Directory scratch;
  late FixtureAccess access;
  late List<({String method, String path, String? body})> requests;
  late GitHub forge;
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('developers-');
    access = FixtureAccess(scratch);
    requests = [];
    await File('${scratch.path}/access.yml').writeAsString('''# Private access settings
host:
  network: 10.77.0.0/24 # Host VPN
  ssh_host_key: $ssh
developers: {} # Keep the developer list
transports: {matrix: {room: '#demo:example.org'}} # Keep the room
''');
    forge = GitHub(
      'test-token',
      http: (method, uri, headers, body) async {
        requests.add((method: method, path: uri.path, body: body));
        return (
          status: method == 'PUT'
              ? 201
              : uri.path.endsWith('/permission')
              ? 404
              : 200,
          body: jsonEncode(
            method == 'PUT'
                ? {'id': 1}
                : uri.path.endsWith('/invitations')
                ? [
                    {
                      'id': 1,
                      'invitee': {'login': 'dev-login'},
                    },
                  ]
                : {
                    'permissions': {'admin': true},
                  },
          ),
          headers: <String, String>{},
        );
      },
    );
  });
  tearDown(() => scratch.delete(recursive: true));

  // Harm: admission can overwrite other access data, duplicate a developer, or grant excess forge rights.
  test('adding a developer keeps fixture comments and grants read access once', () async {
    final developers = ProjectDevelopers(
      access: access,
      forge: forge,
      repository: 'team/access',
      sync: (project, access, {String? bundle}) async => DeveloperSyncAnswer.read(
        jsonEncode({
          'project': project,
          'commit': 'a' * 40,
          'access_commit': 'b' * 40,
          'added': ['developer'],
          'dropped': <String>[],
          'unchanged': false,
          'laptops_added': ['developer/l1'],
          'laptops_dropped': <String>[],
        }),
        project,
      ),
    );
    addTearDown(developers.dispose);
    await developers.add(
      'developer',
      'dev-login',
      'ssh_public_key: "$ssh laptop-comment"\nwireguard_public_key: "$wg"\n',
      '10.77.0.2',
    );
    expect(developers.problem, isNull);
    final text = await File('${scratch.path}/access.yml').readAsString();
    final yaml = loadYaml(text);
    expect(yaml['developers'], {
      'developer': {
        'forge_login': 'dev-login',
        'laptops': [
          {'ssh_public_key': ssh, 'wireguard_public_key': wg, 'vpn_address': '10.77.0.2'},
        ],
      },
    });
    expect(text, contains('# Private access settings'));
    expect(text, contains('# Host VPN'));
    expect(text, contains('# Keep the developer list'));
    expect(text, contains('# Keep the room'));
    expect(text, isNot(contains('laptop-comment')));
    final put = requests.where((r) => r.method == 'PUT').single;
    expect(put.path, '/repos/team/access/collaborators/dev-login');
    expect(jsonDecode(put.body!), {'permission': 'pull'});
  });

  Future<DeveloperSyncAnswer> synced(String project, AccessDevelopers access, {String? bundle}) async =>
      DeveloperSyncAnswer.read(
        jsonEncode({
          'project': project,
          'commit': 'a' * 40,
          'access_commit': 'b' * 40,
          'added': access.developers.keys.toList(),
          'dropped': <String>[],
          'unchanged': false,
          'laptops_added': <String>[],
          'laptops_dropped': <String>[],
        }),
        project,
      );
  String getBlock() => 'ssh_public_key: "$ssh"\nwireguard_public_key: "$wg"';

  // Harm: a redundant grant can fail publication even though the developer already has repository access.
  testWidgets('publishing an existing reader shows the permission without another grant', (tester) async {
    final api = GitHub(
      'test-token',
      http: (method, uri, headers, body) async {
        requests.add((method: method, path: uri.path, body: body));
        return (
          status: method == 'PUT' ? 500 : 200,
          body: jsonEncode(
            method == 'PUT'
                ? {'message': 'The existing reader cannot be granted again.'}
                : uri.path.endsWith('/permission')
                ? {'permission': 'read'}
                : uri.path.endsWith('/invitations')
                ? <Object>[]
                : {
                    'permissions': {'admin': true},
                  },
          ),
          headers: <String, String>{},
        );
      },
    );
    final model = ProjectDevelopers(access: access, forge: api, repository: 'team/access', sync: synced);
    addTearDown(model.dispose);
    await tester.runAsync(() => model.add('developer', 'dev-login', getBlock(), '10.77.0.2'));
    expect(model.problem, isNull);
    expect(requests.where((request) => request.method == 'PUT'), isEmpty);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProjectDevelopersDialog(developers: model)),
      ),
    );
    await tester.pump();
    expect(find.text('dev-login: already has read access.'), findsOneWidget);
  });

  // Harm: an invitation to a different role must not hide already confirmed repository access.
  test('an existing reader keeps its confirmed access despite a pending role invitation', () async {
    final api = GitHub(
      'test-token',
      http: (method, uri, headers, body) async {
        requests.add((method: method, path: uri.path, body: body));
        return (
          status: 200,
          body: jsonEncode(
            uri.path.endsWith('/permission')
                ? {'permission': 'write'}
                : uri.path.endsWith('/invitations')
                ? [
                    {
                      'id': 1,
                      'invitee': {'login': 'dev-login'},
                      'permissions': 'admin',
                    },
                  ]
                : {
                    'permissions': {'admin': true},
                  },
          ),
          headers: <String, String>{},
        );
      },
    );
    final model = ProjectDevelopers(access: access, forge: api, repository: 'team/access', sync: synced);
    addTearDown(model.dispose);
    await model.add('developer', 'dev-login', getBlock(), '10.77.0.2');
    expect(model.problem, isNull);
    expect(model.forgeStates['dev-login'], 'already has read access');
    await model.load();
    expect(model.forgeStates['dev-login'], 'already has read access');
    expect(requests.where((request) => request.method == 'PUT'), isEmpty);
  });

  // Harm: insufficient forge rights can publish a developer who cannot receive repository access.
  test('a token without Administration is refused before the fixture changes', () async {
    final before = await File('${access.folder}/access.yml').readAsString();
    final denied = GitHub(
      'test-token',
      http: (method, uri, headers, body) async =>
          (status: 403, body: '{"message":"test-token"}', headers: <String, String>{}),
    );
    final model = ProjectDevelopers(access: access, forge: denied, repository: 'team/access', sync: synced);
    addTearDown(model.dispose);
    await model.add('developer', 'dev-login', getBlock(), '10.77.0.2');
    expect(model.problem, contains('Administration: Read and write'));
    expect(model.problem, isNot(contains('test-token')));
    expect(await File('${access.folder}/access.yml').readAsString(), before);
    expect(access.published, 0);
  });

  // Harm: duplicate actions can publish the same account or allocate the same VPN twice.
  test('duplicate accounts and reserved addresses leave the published fixture unchanged', () async {
    final model = ProjectDevelopers(access: access, forge: forge, repository: 'team/access', sync: synced);
    addTearDown(model.dispose);
    for (final address in ['10.77.0.0', '10.77.0.1', '10.78.0.2']) {
      await model.add('developer', 'dev-login', getBlock(), address);
      expect(model.problem, isNotNull);
    }
    expect(access.published, 0);
    await model.add('developer', 'dev-login', getBlock(), '10.77.0.2');
    expect(model.problem, isNull);
    final before = await File('${access.folder}/access.yml').readAsString();
    await model.add('developer', 'dev-login', getBlock(), '10.77.0.3');
    expect(model.problem, isNotNull);
    await model.add('otherdev', 'other-login', getBlock(), '10.77.0.2');
    expect(model.problem, isNotNull);
    expect(await File('${access.folder}/access.yml').readAsString(), before);
    expect(access.published, 1);
    expect(requests.where((r) => r.method == 'PUT'), hasLength(1));
  });

  // Harm: a failed host sync must not leave removed developers holding forge access.
  test('removal revokes a pending invitation despite host refusal and retry does not repeat it', () async {
    var refuseSync = false;
    var syncCalls = 0;
    var invited = false;
    final api = GitHub(
      'test-token',
      http: (method, uri, headers, body) async {
        requests.add((method: method, path: uri.path, body: body));
        if (method == 'PUT') {
          invited = true;
          return (status: 201, body: '{}', headers: <String, String>{});
        }
        if (method == 'DELETE') {
          invited = false;
          return (status: 204, body: '', headers: <String, String>{});
        }
        if (uri.path.endsWith('/invitations')) {
          return (
            status: 200,
            body: jsonEncode(
              invited
                  ? [
                      {
                        'id': 7,
                        'invitee': {'login': 'dev-login'},
                      },
                    ]
                  : <Object>[],
            ),
            headers: <String, String>{},
          );
        }
        if (uri.path.endsWith('/permission')) return (status: 404, body: '{}', headers: <String, String>{});
        return (status: 200, body: '{"permissions":{"admin":true}}', headers: <String, String>{});
      },
    );
    final model = ProjectDevelopers(
      access: access,
      forge: api,
      repository: 'team/access',
      sync: (project, access, {String? bundle}) async {
        syncCalls++;
        if (refuseSync) throw const HostAdminRefused('The project admin is not admitted.');
        return synced(project, access);
      },
    );
    addTearDown(model.dispose);
    await model.add('developer', 'dev-login', getBlock(), '10.77.0.2');
    expect(model.problem, isNull);
    refuseSync = true;
    await model.remove('developer');
    expect(model.problem, contains('The project admin is not admitted.'));
    expect(model.needsRetry, isTrue);
    expect(loadYaml(await File('${access.folder}/access.yml').readAsString())['developers'], isEmpty);
    expect(requests.where((r) => r.method == 'DELETE').map((r) => r.path), [
      '/repos/team/access/invitations/7',
      '/repos/team/access/collaborators/dev-login',
    ]);
    refuseSync = false;
    await model.retry();
    expect(model.problem, isNull);
    expect(model.needsRetry, isFalse);
    expect(syncCalls, 3);
    expect(access.published, 2);
    expect(requests.where((r) => r.method == 'DELETE'), hasLength(2));
  });

  // Harm: a host that synced an older revision can make an unapplied change appear complete.
  test('a different access commit never confirms developer admission', () async {
    final model = ProjectDevelopers(
      access: access,
      forge: forge,
      repository: 'team/access',
      sync: (project, access, {String? bundle}) async => DeveloperSyncAnswer.read(
        jsonEncode({
          'project': project,
          'commit': 'a' * 40,
          'access_commit': 'c' * 40,
          'added': ['developer'],
          'dropped': <String>[],
          'unchanged': false,
          'laptops_added': <String>[],
          'laptops_dropped': <String>[],
        }),
        project,
      ),
    );
    addTearDown(model.dispose);
    await model.add('developer', 'dev-login', getBlock(), '10.77.0.2');
    expect(model.lastSync, isNull);
    expect(model.needsRetry, isTrue);
    expect(model.problem, contains('did not confirm'));
  });

  // Harm: a local bundle failure after a successful push must not lose host and forge application.
  test('a local failure after publication preserves the exact pending change for retry', () async {
    final model = ProjectDevelopers(access: access, forge: forge, repository: 'team/access', sync: synced);
    addTearDown(model.dispose);
    access.bundleFails = true;
    await model.add('developer', 'dev-login', getBlock(), '10.77.0.2');
    expect(model.needsRetry, isTrue);
    expect(model.problem, contains('published'));
    expect(requests.where((r) => r.method == 'PUT'), isEmpty);
    access.bundleFails = false;
    await model.retry();
    expect(model.problem, isNull);
    expect(model.needsRetry, isFalse);
    expect(access.published, 1);
    expect(requests.where((r) => r.method == 'PUT'), hasLength(1));
  });

  // Harm: refresh must not retarget a pending revoke to a newer developer list.
  test('refresh refuses to replace the revision of an unconfirmed access change', () async {
    final model = ProjectDevelopers(
      access: access,
      forge: forge,
      repository: 'team/access',
      sync: (_, _, {String? bundle}) async => throw const HostAdminRefused('Sync is unavailable.'),
    );
    addTearDown(model.dispose);
    await model.add('developer', 'dev-login', getBlock(), '10.77.0.2');
    expect(model.needsRetry, isTrue);
    await File('${access.folder}/access.yml')
        .writeAsString('host: {network: 10.78.0.0/24, ssh_host_key: "$ssh"}\ndevelopers: {}\n');
    await model.load();
    expect(model.problem, contains('Retry'));
    expect(model.listed!.network, '10.77.0.0/24');
    expect(model.listed!.developers.keys, ['developer']);
  });

  // Harm: removing the last laptop leaves an invalid signed developer identity.
  test('the last laptop cannot be removed independently', () async {
    final model = ProjectDevelopers(access: access, forge: forge, repository: 'team/access', sync: synced);
    addTearDown(model.dispose);
    await model.add('developer', 'dev-login', getBlock(), '10.77.0.2');
    await model.removeLaptop('developer', '10.77.0.2');
    expect(model.problem, contains('at least one laptop'));
    expect(access.published, 1);
    expect(model.listed!.developers['developer']!.laptops, hasLength(1));
  });
}
