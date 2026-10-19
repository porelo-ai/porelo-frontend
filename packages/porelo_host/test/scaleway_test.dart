import 'dart:convert';

import 'package:porelo_host/porelo_host.dart';
import 'package:test/test.dart';

/// Scaleway's API as recorded: each answer by method and path, every request kept.
class RecordedApi {
  RecordedApi(this.answers);

  final Map<String, ApiAnswer> answers;
  final requests = <(String, String, Map<String, Object?>?)>[];

  Future<ApiAnswer> call(String method, String path, {Map<String, Object?>? body}) async {
    requests.add((method, path, body));
    final key = '$method ${path.split('?').first}';
    final answer = answers[key];
    if (answer == null) throw StateError('no recorded answer for $key');
    return answer;
  }
}

const zone = '/baremetal/v1/zones/fr-par-1';
const offers = ApiAnswer(200, <String, Object?>{
  'offers': <Object?>[
    <String, Object?>{'id': 'offer-1', 'name': 'EM-I220E-NVME', 'stock': 'available'},
  ],
});
const systems = ApiAnswer(200, <String, Object?>{
  'os': <Object?>[
    <String, Object?>{'id': 'os-24', 'name': 'Ubuntu', 'version': '24.04', 'enabled': true},
    <String, Object?>{'id': 'os-26', 'name': 'Ubuntu', 'version': '26.04', 'enabled': true},
  ],
});

Map<String, Object?> server({
  String id = 'srv-1',
  String status = 'ready',
  String install = 'completed',
  List<String> tags = const <String>['porelo-project=demo', 'porelo-host-key=AAAAHOST'],
}) => <String, Object?>{
  'id': id,
  'status': status,
  'tags': tags,
  'install': <String, Object?>{'status': install},
  'ips': <Object?>[
    <String, Object?>{'address': '2001:db8::7', 'version': 'IPv6'},
    <String, Object?>{'address': '203.0.113.7', 'version': 'IPv4'},
  ],
};

void main() {
  ScalewayElasticMetal adapter(RecordedApi api) => ScalewayElasticMetal(api: api.call, projectId: 'project-1');

  test('a rent names the offer, Ubuntu 26.04, the tags, the person\'s key and cloud-init\'s data', () async {
    final api = RecordedApi(<String, ApiAnswer>{
      'GET $zone/offers': offers,
      'GET $zone/os': systems,
      'GET /iam/v1alpha1/ssh-keys': const ApiAnswer(200, <String, Object?>{'ssh_keys': <Object?>[]}),
      'POST /iam/v1alpha1/ssh-keys': const ApiAnswer(200, <String, Object?>{'id': 'key-9'}),
      'POST $zone/servers': ApiAnswer(200, server(status: 'delivering', install: 'to_install')),
    });

    final host = await adapter(api).create(
      const HostRequest(
        name: 'demo',
        tags: <String>['porelo-project=demo', 'porelo-host-key=AAAAHOST'],
        sshPublicKey: 'ssh-ed25519 PERSON me@example',
        userData: '#cloud-config\n',
      ),
    );

    final rent = api.requests.singleWhere((r) => r.$1 == 'POST' && r.$2.endsWith('/servers')).$3!;
    expect(rent['offer_id'], 'offer-1');
    expect(rent['project_id'], 'project-1');
    expect(rent['tags'], <String>['porelo-project=demo', 'porelo-host-key=AAAAHOST']);
    expect(rent['install'], <String, Object?>{
      'os_id': 'os-26',
      'hostname': 'demo',
      'ssh_key_ids': <String>['key-9'],
    });
    expect(utf8.decode(base64.decode(rent['user_data'] as String)), '#cloud-config\n');
    expect(host.ready, isFalse, reason: 'delivering is not ready');
    expect(host.hostKey, 'ssh-ed25519 AAAAHOST', reason: 'the key the request made, read back from its tag');
  });

  test('the person\'s key already in the project is taken, not registered twice', () async {
    final api = RecordedApi(<String, ApiAnswer>{
      'GET $zone/offers': offers,
      'GET $zone/os': systems,
      'GET /iam/v1alpha1/ssh-keys': const ApiAnswer(200, <String, Object?>{
        'ssh_keys': <Object?>[
          <String, Object?>{'id': 'key-3', 'public_key': 'ssh-ed25519 PERSON other-comment'},
        ],
      }),
      'POST $zone/servers': ApiAnswer(200, server()),
    });

    await adapter(api).create(
      const HostRequest(name: 'demo', tags: <String>['porelo-project=demo'], sshPublicKey: 'ssh-ed25519 PERSON me'),
    );

    expect(api.requests.where((r) => r.$1 == 'POST' && r.$2 == '/iam/v1alpha1/ssh-keys'), isEmpty);
    final rent = api.requests.singleWhere((r) => r.$2.endsWith('/servers')).$3!;
    expect((rent['install'] as Map)['ssh_key_ids'], <String>['key-3']);
  });

  test('ready is the server ready and its install completed, at its IPv4 address', () async {
    final api = RecordedApi(<String, ApiAnswer>{'GET $zone/servers/srv-1': ApiAnswer(200, server())});
    final host = await adapter(api).state('srv-1');
    expect(host.ready, isTrue);
    expect(host.address, '203.0.113.7');

    final installing = RecordedApi(<String, ApiAnswer>{
      'GET $zone/servers/srv-1': ApiAnswer(200, server(install: 'installing')),
    });
    expect((await adapter(installing).state('srv-1')).ready, isFalse);
  });

  test('a host is found again by its project tag, and one being deleted is not found', () async {
    final api = RecordedApi(<String, ApiAnswer>{
      'GET $zone/servers': ApiAnswer(200, <String, Object?>{
        'servers': <Object?>[server(id: 'old', status: 'deleting'), server(id: 'srv-1')],
      }),
    });
    expect((await adapter(api).find('porelo-project=demo'))!.id, 'srv-1');
    expect(api.requests.single.$2, contains('tags=porelo-project%3Ddemo'));
  });

  test('a server without a project tag is never given back', () async {
    final api = RecordedApi(<String, ApiAnswer>{
      'GET $zone/servers/srv-x': ApiAnswer(200, server(id: 'srv-x', tags: const <String>['someone-else'])),
      'DELETE $zone/servers/srv-x': const ApiAnswer(200, null),
    });
    await expectLater(adapter(api).release('srv-x'), throwsA(isA<ProviderFailed>()));
    expect(api.requests.where((r) => r.$1 == 'DELETE'), isEmpty, reason: 'nothing of somebody else\'s is deleted');
  });

  test('a tagged server is given back', () async {
    final api = RecordedApi(<String, ApiAnswer>{
      'GET $zone/servers/srv-1': ApiAnswer(200, server()),
      'DELETE $zone/servers/srv-1': const ApiAnswer(204, null),
    });
    await adapter(api).release('srv-1');
    expect(api.requests.last.$1, 'DELETE');
  });

  test('a key without the permission and an offer out of stock are said as such', () async {
    final denied = RecordedApi(<String, ApiAnswer>{
      'GET $zone/servers': const ApiAnswer(403, <String, Object?>{'message': 'insufficient permissions'}),
    });
    await expectLater(
      adapter(denied).find('porelo-project=demo'),
      throwsA(predicate((Object e) => '$e' == 'the key may not list the servers: insufficient permissions')),
    );

    final empty = RecordedApi(<String, ApiAnswer>{
      'GET $zone/offers': const ApiAnswer(200, <String, Object?>{
        'offers': <Object?>[
          <String, Object?>{'id': 'offer-1', 'name': 'EM-I220E-NVME', 'stock': 'empty'},
        ],
      }),
    });
    await expectLater(
      adapter(empty).create(const HostRequest(name: 'demo', tags: <String>[], sshPublicKey: 'ssh-ed25519 K')),
      throwsA(predicate((Object e) => '$e' == 'EM-I220E-NVME is out of stock in fr-par-1')),
    );
  });
}
