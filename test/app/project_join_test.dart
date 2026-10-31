import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_join.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart' show FakeBackend;
import '../support/host_admin.dart';
import '../support/project_join.dart';
import '../support/signed_host.dart';

void main() {
  late Settings settings;
  late Machines machines;
  late FakeDiscovery core;
  late FakeJoinHost host;

  JoinOffered offer({String project = 'demo', String revision = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'}) =>
      JoinOffered(
        project: project,
        host: PreparedHost.read(hostValues()),
        source: 'https://forge.example/team/$project.git',
        revision: revision,
        signers: [personKey],
      );

  ProjectJoin joining(JoinOffered shown) {
    final join = ProjectJoin(offer: shown, discovery: core, host: host, machines: machines, settings: settings);
    addTearDown(join.dispose);
    return join;
  }

  setUp(() {
    settings = Settings(MemorySettingsStore());
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    core = FakeDiscovery();
    host = FakeJoinHost();
    addTearDown(machines.dispose);
    addTearDown(settings.dispose);
  });

  // Harm: an admission Core no longer verifies is joined from what the row once showed.
  for (final (name, answer) in [
    ('revoked', <JoinAdmission>[]),
    ('stale', <JoinAdmission>[offer(revision: 'b' * 40)]),
  ]) {
    test('a $name admission follows, writes and connects nothing', () async {
      final join = joining(offer());
      core.answer = answer;
      await join.join();
      expect(join.joined, isFalse);
      expect(join.problem, contains('no longer verifies'));
      expect(host.calls, isEmpty);
      expect(settings.projectHost('demo'), isNull);
      expect(machines.all.where((m) => m.kind == 'host'), isEmpty);
    });
  }

  // Harm: Core's refusal is taken as an empty answer, or the join goes ahead without Core.
  test('a Core refusal starts nothing', () async {
    final join = joining(offer());
    core.refusal = const RegistryRefusal('The access file is not signed by a verified project admin.');
    await join.join();
    expect(join.problem, contains('not signed'));
    expect(host.calls, isEmpty);
  });

  // Harm: an incomplete verdict, here a credential in the address, is followed.
  test('an incomplete verdict is refused before any connection', () async {
    final shown = JoinOffered(
      project: 'demo',
      host: PreparedHost.read(hostValues()),
      source: 'https://user:secret@forge.example/team/demo.git',
      revision: 'a' * 40,
      signers: [personKey],
    );
    core.answer = [shown];
    final join = joining(shown);
    await join.join();
    expect(join.joined, isFalse);
    expect(join.problem, isNot(contains('secret')));
    expect(host.calls, isEmpty);
  });

  // Harm: one click follows without Core's signers, or saves before the host confirms.
  test('one click follows with Core\'s signers on the tunnel, then records the confirmed membership', () async {
    final shown = offer();
    core.answer = [shown];
    final join = joining(shown);
    await join.join();
    expect(join.problem, isNull);
    expect(join.joined, isTrue);
    expect(host.calls, ['connect ${shown.host.name}', 'follow demo ${shown.source} $personKey']);
    expect(settings.projectHost('demo'), shown.host.name);
    expect(machines.all.where((m) => m.kind == 'host' && m.hostCard?.name == shown.host.name), hasLength(1));
  });

  // Harm: the person is said ready while the host runs another revision.
  test('a host that confirms another revision saves nothing', () async {
    final shown = offer();
    core.answer = [shown];
    host.confirms = 'c' * 40;
    final join = joining(shown);
    await join.join();
    expect(join.joined, isFalse);
    expect(join.problem, contains('did not confirm'));
    expect(settings.projectHost('demo'), isNull);
    expect(machines.all.where((m) => m.kind == 'host'), isEmpty);
  });

  // Harm: clicking twice, or retrying, duplicates follows, watched accounts or tunnels.
  test('double clicks and retries after a failed tunnel or follow do not duplicate anything', () async {
    final shown = offer();
    core.answer = [shown];
    final join = joining(shown);
    host.tunnelFails = const RegistryRefusal('The tunnel to the host could not be raised.');
    await join.join();
    expect(join.joined, isFalse);
    host.followFails = const FormatException('daemon went away');
    await join.join();
    expect(join.joined, isFalse);
    expect(join.progress, contains('not joined yet'));
    await Future.wait([join.join(), join.join()]);
    expect(join.joined, isTrue);
    expect(host.calls.where((call) => call.startsWith('connect')), hasLength(2));
    expect(host.calls.where((call) => call.startsWith('follow')), hasLength(2));
    expect(machines.all.where((m) => m.kind == 'host'), hasLength(1));
  });

  // Harm: a project already followed at the verified revision is followed again.
  test('a project followed already at the verified revision is not followed again', () async {
    final shown = offer();
    core.answer = [shown];
    host.following['demo'] = Followed(name: 'demo', url: shown.source, commit: shown.revision);
    final join = joining(shown);
    await join.join();
    expect(join.joined, isTrue);
    expect(host.calls.where((call) => call.startsWith('follow')), isEmpty);
  });

  // Harm: an unverified or other-source follow at the verified hash is saved as a verified join.
  for (final (name, before) in [
    (
      'unverified',
      (JoinOffered shown) => Followed(name: 'demo', url: shown.source, commit: shown.revision, unverified: true),
    ),
    (
      'other-source',
      (JoinOffered shown) => Followed(name: 'demo', url: 'https://elsewhere.example/demo.git', commit: shown.revision),
    ),
  ]) {
    test('an $name follow already there is followed again with Core\'s signers', () async {
      final shown = offer();
      core.answer = [shown];
      host.following['demo'] = before(shown);
      final join = joining(shown);
      await join.join();
      expect(join.joined, isTrue);
      expect(host.calls, contains('follow demo ${shown.source} $personKey'));
    });
  }

  // Harm: the daemon's unverified follow is taken as the verified join.
  test('a follow the daemon answers as unverified saves nothing', () async {
    final shown = offer();
    core.answer = [shown];
    host.unverified = true;
    final join = joining(shown);
    await join.join();
    expect(join.joined, isFalse);
    expect(settings.projectHost('demo'), isNull);
    expect(machines.all.where((m) => m.kind == 'host'), isEmpty);
  });

  // Harm: a card-less rental record for the host name is taken as the card tunnel.
  test('a rental record with the host\'s name is not taken for its card tunnel', () async {
    final shown = offer();
    core.answer = [shown];
    await machines.add(
      Machine(
        name: 'rental',
        kind: 'host',
        hostProject: shown.host.name,
        host: 'root@${shown.host.address}',
        socketPath: '/unused',
        remoteSocket: '/run/user/0/porelo',
      ),
    );
    final join = joining(shown);
    await join.join();
    expect(join.joined, isTrue);
    expect(host.calls.where((call) => call.startsWith('connect')), hasLength(1));
  });

  // Harm: two rows clicked at once open two tunnels to one host, or add its account twice.
  test('two projects joined at once on one host share one tunnel', () async {
    final first = offer();
    final second = offer(project: 'billing');
    core.answer = [first, second];
    await Future.wait([joining(first).join(), joining(second).join()]);
    expect(host.calls.where((call) => call.startsWith('connect')), hasLength(1));
    expect(machines.all.where((m) => m.hostCard != null), hasLength(1));
    expect(settings.projectHost('billing'), first.host.name);
  });

  // Harm: a credential in an address reaches the screen or the follow.
  for (final address in [
    'https://forge.example/team/demo.git?token=secret',
    'user:secret@forge.example:team/demo.git',
  ]) {
    test('a source $address is refused without showing it', () async {
      final shown = JoinOffered(
        project: 'demo',
        host: PreparedHost.read(hostValues()),
        source: address,
        revision: 'a' * 40,
        signers: [personKey],
      );
      core.answer = [shown];
      final join = joining(shown);
      await join.join();
      expect(join.problem, isNot(contains('secret')));
      expect(host.calls, isEmpty);
    });
  }

  // Harm: a second project on the same host opens a second tunnel or a second watched account.
  test('two projects on one host share its connection', () async {
    final first = offer();
    final second = offer(project: 'billing');
    core.answer = [first, second];
    await joining(first).join();
    await joining(second).join();
    expect(host.calls.where((call) => call.startsWith('connect')), hasLength(1));
    expect(machines.all.where((m) => m.hostCard != null), hasLength(1));
    expect(settings.projectHost('billing'), first.host.name);
  });

  Map<String, Object?> joinable() => {
    'projects': [
      {
        'project': 'demo',
        'host': 'orchard',
        'host_account': 'porelo-alice',
        'host_card': {...hostValues()..remove('name'), 'homeserver': 'matrix.orchard.porelo.internal'},
        'source': 'https://forge.example/team/demo.git',
        'access_repository': 'https://forge.example/team/access.git',
        'revision': 'a' * 40,
        'signers': [personKey],
        'admins': [
          {'login': 'bob', 'name': 'Bob', 'email': null},
        ],
      },
    ],
    'refused': [
      {
        'project': 'billing',
        'host': 'orchard',
        'access_repository': 'https://forge.example/team/billing-access.git',
        'why': 'not signed by a verified admin',
        'admins': [
          {'login': 'bob', 'name': 'Bob', 'email': 'bob@example.org'},
        ],
      },
    ],
  };

  // Harm: Core's joinable answer is misread, so a row shows another host, revision or signer than Core verified.
  test('Core\'s joinable answer becomes one offered row and one unreadable row', () {
    final rows = readJoinable(joinable());
    final offered = rows.whereType<JoinOffered>().single;
    expect(offered.same(offer()), isTrue);
    final unreadable = rows.whereType<JoinUnreadable>().single;
    expect(unreadable.words, contains('billing-access.git'));
    expect(unreadable.words, contains('Bob (bob), bob@example.org'));
  });

  // Harm: a broken answer, or a card for another host, shows as an empty list or a row to click.
  for (final (name, change) in <(String, void Function(Map<String, Object?>))>[
    ('missing refused', (json) => json.remove('refused')),
    (
      'a host card for another host',
      (json) => (((json['projects'] as List).single as Map)['host_card'] as Map)['name'] = 'grove',
    ),
    ('a project without signers', (json) => ((json['projects'] as List).single as Map).remove('signers')),
    (
      'a source with credentials',
      (json) => ((json['projects'] as List).single as Map)['source'] = 'https://forge.example/demo.git?token=secret',
    ),
  ]) {
    test('a joinable answer with $name is refused whole', () {
      final json = joinable();
      change(json);
      expect(() => readJoinable(json), throwsA(isA<RegistryRefusal>()));
    });
  }

  test('an unreadable access repository with a credential refuses the answer whole', () {
    final json = joinable();
    ((json['refused'] as List).single as Map)['access_repository'] = 'https://bob:secret@forge.example/access.git';
    expect(() => readJoinable(json), throwsA(isA<RegistryRefusal>()));
  });

  // Harm: an unreadable access repository is shown as nothing, or without who may grant it.
  test('an unreadable access repository names its address and who may grant it', () {
    const unreadable = JoinUnreadable(
      host: 'orchard',
      repository: 'https://forge.example/team/access.git',
      whoMay: [RegistryContact(login: 'bob', name: 'Bob', email: 'bob@example.org')],
    );
    expect(unreadable.words, contains('https://forge.example/team/access.git'));
    expect(unreadable.words, contains('Bob (bob), bob@example.org'));
  });
}
