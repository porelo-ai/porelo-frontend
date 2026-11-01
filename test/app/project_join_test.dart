import 'dart:async';
import 'dart:io';

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
        login: 'porelo-alice',
        source: 'https://forge.example/team/$project.git',
        revision: revision,
        signers: [personKey],
        homeserver: 'https://matrix.orchard.porelo.internal',
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
      login: 'porelo-alice',
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
    expect(join.problem, contains('could not be confirmed'));
    expect(join.progress, isNull, reason: 'its tunnel was taken down, so nothing of it is said as connected');
    await Future.wait([join.join(), join.join()]);
    expect(join.joined, isTrue);
    // The tunnel of the unconfirmed second try was taken down, so the third raised it anew: never two at once.
    expect(host.calls.where((call) => call.startsWith('connect')), hasLength(3));
    expect(host.calls.where((call) => call.startsWith('release')), hasLength(1));
    expect(host.calls.where((call) => call.startsWith('follow')), hasLength(2));
    expect(machines.all.where((m) => m.kind == 'host'), hasLength(1));
  });

  // Harm: a join that is not confirmed keeps its card tunnel and pinned files, which refuse the host's next card.
  for (final (name, fail) in <(String, void Function())>[
    ('a follow that fails', () => host.followFails = const FormatException('daemon went away')),
    ('another revision', () => host.confirms = 'c' * 40),
  ]) {
    test('a join not confirmed after $name takes its card tunnel down', () async {
      final shown = offer();
      core.answer = [shown];
      fail();
      final join = joining(shown);
      await join.join();
      expect(join.joined, isFalse);
      expect(host.calls.last, 'release ${shown.host.name}');
      expect(machines.all.where((m) => m.kind == 'host'), isEmpty);
    });
  }

  // Harm: a join takes down the tunnel of an account watched already, or of a join still running on the host.
  test('a join not confirmed leaves a watched account\'s tunnel up', () async {
    final shown = offer();
    final other = offer(project: 'billing');
    core.answer = [shown, other];
    await joining(shown).join();
    host.confirms = 'c' * 40;
    final second = joining(other);
    await second.join();
    expect(second.joined, isFalse);
    expect(host.calls.where((call) => call.startsWith('release')), isEmpty);
  });

  // Harm: a watched card account whose ssh host is another than the card's is taken for this host's account.
  test('a card account reached under another ssh host is not this host\'s', () {
    final shown = offer();
    final card = HostCardSsh(
      name: shown.host.name,
      address: shown.host.address,
      sshPort: shown.host.sshPort,
      hostKey: shown.host.sshHostKey,
      login: shown.login,
      publicKey: shown.host.sshHostKey,
      webPort: 3000,
      gitPort: 3001,
      matrixPort: 8448,
    );
    final machine = Machine.fromHostCard(card, socketPath: '/unused', sshConfig: '/unused/orchard.conf');
    expect(shown.reaches(machine), isTrue);
    final elsewhere = Machine.fromStored({...machine.stored, 'host': 'grove'});
    expect(shown.reaches(elsewhere), isFalse);
  });

  // Harm: a join follows on a card account whose tunnel is down or uses another ssh configuration, reaching
  // whatever answers on its local socket.
  test('a card account whose tunnel is not up with its own configuration is followed on by nothing', () async {
    final shown = offer();
    core.answer = [shown];
    host.up = false;
    final join = joining(shown);
    await join.join();
    expect(join.joined, isFalse);
    expect(join.problem, contains('did not confirm this host'));
    expect(host.calls.where((call) => call.startsWith('follow')), isEmpty);
  });

  // Harm: a first follow the daemon answered and recorded is refused, because only `Following` says what is in force.
  test('a first follow is confirmed by what the host follows afterwards', () async {
    final shown = offer();
    core.answer = [shown];
    final join = joining(shown);
    await join.join();
    expect(join.problem, isNull);
    expect(join.joined, isTrue);
    expect(settings.projectHost('demo'), shown.host.name);
  });

  // Harm: a follow the daemon refused, its vault shut here, is said as a mismatch or as nothing, and the person does
  // not learn to unlock.
  test('a follow the daemon refuses is said in its words, and saves nothing', () async {
    final shown = offer();
    core.answer = [shown];
    host.outcome = 'VAULT_LOCKED';
    final join = joining(shown);
    await join.join();
    expect(join.joined, isFalse);
    expect(join.problem, contains("This account's store is shut"));
    expect(settings.projectHost('demo'), isNull);
    expect(host.calls.last, 'release ${shown.host.name}');
  });

  // Harm: a watched account whose tunnel is not up yet, its key locked at the start, refuses every join for good.
  test('a watched account whose tunnel is not up is raised before it is followed on', () async {
    final shown = offer();
    final other = offer(project: 'billing');
    core.answer = [shown, other];
    await joining(shown).join();
    host.up = false;
    host.upOnRaise = true;
    final second = joining(other);
    await second.join();
    expect(second.problem, isNull);
    expect(second.joined, isTrue);
    expect(host.calls, contains('raise ${shown.host.name}'));
    host.up = false;
    host.upOnRaise = false;
    final third = joining(offer(project: 'ledger'));
    core.answer = [shown, other, third.offer];
    await third.join();
    expect(third.joined, isFalse);
    expect(third.problem, contains('did not confirm this host'));
  });

  // Harm: a watched account reached with a key the person has rotated away from is followed on with the old key.
  test('a watched account of an older key of the person is raised anew with the card now', () async {
    final shown = offer();
    final other = offer(project: 'billing');
    core.answer = [shown, other];
    await joining(shown).join();
    host.isCurrent = false;
    final second = joining(other);
    await second.join();
    expect(second.joined, isTrue);
    expect(host.calls.where((call) => call.startsWith('connect')), hasLength(2));
  });

  // Harm: two joins on one host, one failing to connect, both skip taking down the tunnel the other raised, which
  // keeps its pins and refuses the host's next card.
  test('a join that raised a tunnel takes it down when unconfirmed, whatever another join on the host does', () async {
    final shown = offer();
    final rotated = JoinOffered(
      project: 'billing',
      host: PreparedHost.read({...hostValues(), 'ssh_host_key': _otherHostKey}),
      login: 'porelo-alice',
      source: 'https://forge.example/team/billing.git',
      revision: 'a' * 40,
      signers: [personKey],
    );
    core.answer = [shown, rotated];
    host.followHeld = Completer<void>();
    host.followFails = const FormatException('daemon went away');
    final first = joining(shown).join();
    await pumpEventQueue();
    expect(host.calls.last, startsWith('follow demo'));
    host.connectHeld = Completer<void>();
    final second = joining(rotated).join();
    await pumpEventQueue();
    expect(host.calls.last, 'connect ${shown.host.name}');
    host.followHeld!.complete();
    await first;
    host.tunnelFails = const RegistryRefusal('The tunnel to the host could not be raised.');
    host.connectHeld!.complete();
    await second;
    expect(host.calls.where((call) => call.startsWith('release')), ['release ${shown.host.name}']);
  });

  // Harm: a card account watched under another name is missed, and the join's teardown removes its live files.
  test('a card account watched under another name refuses the join with words', () async {
    final shown = offer();
    core.answer = [shown];
    final card = HostCardSsh(
      name: shown.host.name,
      address: shown.host.address,
      sshPort: shown.host.sshPort,
      hostKey: _otherHostKey,
      login: shown.login,
      publicKey: personKey,
      webPort: 3000,
      gitPort: 3001,
      matrixPort: 8448,
    );
    final watched = Machine.fromHostCard(card, socketPath: '/unused', sshConfig: '/unused/orchard.conf');
    await machines.add(Machine.fromStored({...watched.stored, 'name': 'my-orchard'}));
    final join = joining(shown);
    await join.join();
    expect(join.joined, isFalse);
    expect(join.problem, allOf(contains('my-orchard'), contains('watched here already')));
    expect(host.calls, isEmpty);
  });

  // Harm: the account was added and watched, the list of machines not saved, and the person is told nothing was
  // saved; a retry then never saves it.
  test('a list of machines that cannot be saved after the account was added says so, and a retry saves it', () async {
    final store = _FailingMachines();
    settings = Settings(store);
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    addTearDown(machines.dispose);
    addTearDown(settings.dispose);
    final shown = offer();
    core.answer = [shown];
    final join = joining(shown);
    await join.join();
    expect(join.joined, isFalse);
    expect(machines.all.where((m) => m.kind == 'host'), hasLength(1));
    expect(join.problem, allOf(isNot(contains('Nothing was saved')), contains('could not be saved')));
    store.fails = false;
    await join.join();
    expect(join.joined, isTrue);
    expect(store.saved, contains(shown.host.name));
  });

  // Harm: the project was followed and the account added, and the person is told nothing was saved.
  test('an association that cannot be saved after the account was added says so', () async {
    final store = _FailingProjectHosts();
    settings = Settings(store);
    machines = Machines(settings, reach: (_) => FakeBackend(const []), tunnels: RecordingTunnels());
    addTearDown(machines.dispose);
    addTearDown(settings.dispose);
    final shown = offer();
    core.answer = [shown];
    final join = joining(shown);
    await join.join();
    expect(join.joined, isFalse);
    expect(machines.all.where((m) => m.kind == 'host'), hasLength(1));
    expect(join.problem, isNot(contains('Nothing was saved')));
    expect(join.problem, contains('is watched'));
    store.fails = false;
    await join.join();
    expect(join.joined, isTrue);
    expect(settings.projectHost('demo'), shown.host.name);
  });

  // Harm: a follow running the right project commit on another access file is taken as joined.
  test('a follow is confirmed by its access commit, never by its project commit', () {
    final shown = offer();
    Followed at({required String commit, required String access}) =>
        Followed(name: 'demo', url: shown.source, commit: commit, accessCommit: access, signers: [pinnedAs(personKey)]);
    expect(shown.confirms(at(commit: shown.revision, access: 'b' * 40)), isFalse);
    expect(shown.confirms(at(commit: 'b' * 40, access: shown.revision)), isTrue);
  });

  // Harm: a project already followed at the verified revision is followed again.
  test('a project followed already at the verified revision is not followed again', () async {
    final shown = offer();
    core.answer = [shown];
    host.following['demo'] = Followed(
      name: 'demo',
      url: shown.source,
      accessCommit: shown.revision,
      signers: [pinnedAs(personKey)],
    );
    final join = joining(shown);
    await join.join();
    expect(join.joined, isTrue);
    expect(host.calls.where((call) => call.startsWith('follow')), isEmpty);
  });

  // Harm: an unverified or other-source follow at the verified hash is saved as a verified join.
  for (final (name, before) in [
    (
      'unverified',
      (JoinOffered shown) => Followed(name: 'demo', url: shown.source, accessCommit: shown.revision, unverified: true),
    ),
    (
      'other-source',
      (JoinOffered shown) =>
          Followed(name: 'demo', url: 'https://elsewhere.example/demo.git', accessCommit: shown.revision),
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
    expect(machines.all.where((m) => m.name == shown.host.name && shown.reaches(m)), hasLength(1));
  });

  // Harm: a watched entry by the host's name that is not this card's account is silently kept in place of the joined
  // one, or an older card of the host blocks it, while the join is said done.
  for (final (name, watched) in <(String, Machine Function(JoinOffered))>[
    (
      'a socket entry',
      (shown) => Machine(name: shown.host.name, socketPath: '/unused/orchard.sock', host: 'root@${shown.host.address}'),
    ),
    (
      'an older card',
      (shown) => Machine.fromHostCard(
        HostCardSsh(
          name: shown.host.name,
          address: '198.51.100.9',
          sshPort: 22,
          hostKey: shown.host.sshHostKey,
          login: shown.login,
          publicKey: shown.host.sshHostKey,
          webPort: 3000,
          gitPort: 3001,
          matrixPort: 8448,
        ),
        socketPath: '/unused',
        sshConfig: '/unused/orchard.conf',
      ),
    ),
  ]) {
    test('$name watched by the host\'s name refuses the join with words', () async {
      final shown = offer();
      core.answer = [shown];
      await machines.add(watched(shown));
      final join = joining(shown);
      await join.join();
      expect(join.joined, isFalse);
      expect(join.problem, contains('watched here already'));
      expect(host.calls, isEmpty);
      expect(settings.projectHost('demo'), isNull);
    });
  }

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
        login: 'porelo-alice',
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
        'host_card': _card(),
        'homeserver': 'https://matrix.orchard.porelo.internal',
        'source': 'https://forge.example/team/demo.git',
        'access_repository': 'https://forge.example/team/access.git',
        'revision': 'a' * 40,
        'signers': [personKey],
        'admins': [
          {'login': 'bob', 'name': 'Bob', 'email': null},
        ],
      },
    ],
    'refused': <Map<String, Object?>>[
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
    final rows = readJoinable(joinable(), login: 'porelo-alice');
    final offered = rows.whereType<JoinOffered>().single;
    expect(offered.same(offer()), isTrue);
    final unreadable = rows.whereType<JoinUnreadable>().single;
    expect(unreadable.words, contains('billing-access.git'));
    expect(unreadable.words, contains('Bob (bob), bob@example.org'));
    expect(unreadable.words, contains('Core says: not signed by a verified admin.'), reason: 'why it was refused');
  });

  // Harm: a broken answer, or a card for another host, shows as an empty list or a row to click.
  for (final (name, change) in <(String, void Function(Map<String, Object?>))>[
    ('missing refused', (json) => json.remove('refused')),
    (
      'a host card for another host',
      (json) => (((json['projects'] as List).single as Map)['host_card'] as Map)['host'] = 'grove',
    ),
    ('a row for another login', (json) => ((json['projects'] as List).single as Map)['host_account'] = 'porelo-bob'),
    (
      'an access repository with credentials',
      (json) =>
          ((json['projects'] as List).single as Map)['access_repository'] = 'ssh://git:secret@forge.example/a.git',
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
      expect(() => readJoinable(json, login: 'porelo-alice'), throwsA(isA<RegistryRefusal>()));
    });
  }

  // Harm: a host whose access file the registry refused makes the whole answer unreadable, or leaves its projects
  // offered as though their file had been read.
  test('a host whose access file was refused closes its projects and names the host', () {
    final json = joinable();
    (json['refused'] as List).add({
      'project': null,
      'host': 'orchard',
      'access_repository': null,
      'why': 'hosts/orchard/access.yml in 1111111: not signed by a host admin',
      'admins': [
        {'login': 'carol', 'name': 'Carol', 'email': null},
      ],
    });
    final rows = readJoinable(json, login: 'porelo-alice');
    expect(rows.whereType<JoinOffered>(), isEmpty, reason: 'nothing on a refused host is offered');
    final host = rows.whereType<JoinUnreadable>().where((row) => row.repository == null).single;
    expect(host.words, allOf(contains('orchard'), contains('Carol (carol)')));
  });

  test('a refused row with only one of project and access repository refuses the answer whole', () {
    final json = joinable();
    ((json['refused'] as List).single as Map)['project'] = null;
    expect(() => readJoinable(json, login: 'porelo-alice'), throwsA(isA<RegistryRefusal>()));
  });

  // Harm: a credential in a refused row's access repository is kept and shown on the row.
  for (final address in [
    'https://bob:secret@forge.example/access.git',
    'git@forge.example:team/access.git?token=secret',
    'https://forge.example/team/access.git#token=secret',
    'https://forge.example/https://bob:secret@other.example/access.git',
    'ssh://git@forge.example/team/bob:secret@access.git',
    'git@forge.example:team/bob:secret@access.git',
    'https://bob%3Asecret%40forge.example/access.git',
  ]) {
    test('an unreadable access repository $address is named by its project, never shown', () {
      final json = joinable();
      _refusal(json)['access_repository'] = address;
      final rows = readJoinable(json, login: 'porelo-alice');
      final row = rows.whereType<JoinUnreadable>().single;
      expect(row.repository, isNull);
      expect(row.words, allOf(contains('billing'), isNot(contains('secret'))));
      expect(rows.whereType<JoinOffered>(), hasLength(1), reason: 'the other rows stay');
    });
  }

  // Harm: an address or homeserver with a credential, in a form the first check let pass, is kept in the offer.
  for (final (field, value) in [
    ('source', 'git@forge.example:team/demo.git?token=secret'),
    ('source', 'https://forge.example/team/demo.git#token=secret'),
    ('source', 'https://forge.example/team/alice:secret@demo.git'),
    ('source', 'git@forge.example:team/alice:secret@demo.git'),
    ('access_repository', 'git@forge.example:team/access.git?token=secret'),
    ('access_repository', 'https://forge.example/https://bob:secret@other.example/access.git'),
    ('homeserver', 'https://alice:secret@matrix.example'),
    ('homeserver', 'https://matrix.example/?access_token=secret'),
    ('homeserver', 'https://matrix.example/#secret'),
  ]) {
    test('a joinable $field $value refuses the answer whole', () {
      final json = joinable();
      _first(json)[field] = value;
      expect(() => readJoinable(json, login: 'porelo-alice'), throwsA(isA<RegistryRefusal>()));
    });
  }

  // Harm: an address Core's rule does not take, or a port no host listens on, is offered to click.
  for (final (field, value) in [
    ('source', 'ssh://git@[:::]:22/team/demo.git'),
    ('source', 'ssh://git@forge.example:99999/team/demo.git'),
    ('source', 'ssh://git@forge.example:0/team/demo.git'),
    ('source', 'https://forge.example:0/team/demo.git'),
    ('source', 'https://forge.example:65536/team/demo.git'),
    ('homeserver', 'matrix.example'),
    ('homeserver', 'https://matrix.example:0'),
    ('homeserver', 'unix:run/porelo-matrix/client.sock'),
    ('homeserver', 'unix:/run/../etc/client.sock'),
  ]) {
    test('a joinable $field $value is its own refusal, never offered', () {
      final json = joinable();
      _first(json)[field] = value;
      final rows = readJoinable(json, login: 'porelo-alice');
      expect(rows.whereType<JoinOffered>(), isEmpty);
      expect(rows.whereType<JoinUnusable>().single.key, 'demo@orchard');
    });
  }

  // Harm: a project whose homeserver is a socket behind its host's gate can never be joined from here.
  test('a homeserver socket on the host is read', () {
    final json = joinable();
    _first(json)['homeserver'] = 'unix:/run/porelo-matrix/client.sock';
    final offer = readJoinable(json, login: 'porelo-alice').whereType<JoinOffered>().single;
    expect(offer.homeserver, 'unix:/run/porelo-matrix/client.sock');
    offer.check();
  });

  test('a homeserver base URL with a port and a path is read', () {
    final json = joinable();
    _first(json)['homeserver'] = 'https://matrix.example:8448/base';
    expect(readJoinable(json, login: 'porelo-alice').whereType<JoinOffered>().single.homeserver, endsWith('/base'));
  });

  // Harm: a form Core answers is refused, so the person sees no way in, or one row hides every other.
  for (final (name, change) in <(String, void Function(Map<String, Object?>))>[
    ('an admin without an accepted card', (json) => _first(json)['admins'] = [_nobody]),
    ('a refused row\'s admin without an accepted card', (json) => _refusal(json)['admins'] = [_nobody]),
    ('a DNS address', (json) => (_first(json)['host_card'] as Map)['address'] = 'orchard.example.org'),
    ('an IPv6 address', (json) => (_first(json)['host_card'] as Map)['address'] = '2001:db8::7'),
    ('an ssh:// source', (json) => _first(json)['source'] = 'ssh://git@forge.example:2222/team/demo.git'),
    ('an scp source of another user', (json) => _first(json)['source'] = 'forgejo@forge.example:team/demo.git'),
    ('an ssh:// access repository', (json) => _first(json)['access_repository'] = 'ssh://git@forge.example/a.git'),
    ('a project name with a digit first', (json) => _first(json)['project'] = '2026-demo'),
  ]) {
    test('Core\'s answer with $name is read', () {
      final json = joinable();
      change(json);
      final offered = readJoinable(json, login: 'porelo-alice').whereType<JoinOffered>().single;
      final project = _first(json)['project'] as String;
      expect(offered.key, '$project@orchard');
      expect(offered.source, _first(json)['source']);
      expect(offered.host.address, (_first(json)['host_card'] as Map)['address']);
    });
  }

  test('an admin without an accepted card is named by their login', () {
    final json = joinable();
    _refusal(json)['admins'] = [_nobody];
    expect(
      readJoinable(json, login: 'porelo-alice').whereType<JoinUnreadable>().single.words,
      contains('carol (carol)'),
    );
  });

  // Harm: one row Core answered in a form not joined here hides every other row, or is offered to click.
  test('a row in a form not joined here is its own refusal beside the others', () {
    final json = joinable();
    final second = Map<String, Object?>.of(_first(json))
      ..['project'] = 'billing'
      ..['source'] = 'git://forge.example/team/billing.git';
    json['projects'] = [_first(json), second];
    json['refused'] = <Object?>[];
    final rows = readJoinable(json, login: 'porelo-alice');
    expect(rows.whereType<JoinOffered>().map((row) => row.project), ['demo']);
    final unusable = rows.whereType<JoinUnusable>().single;
    expect(unusable.key, 'billing@orchard');
    expect(unusable.words, contains('Bob (bob)'));
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

/// Core's host card of orchard, exactly as `registry joinable` answers it.
Map<String, Object?> _card() => {'host': 'orchard', ...hostValues()..remove('name'), 'signed_by': 'SHA256:${'A' * 43}'};

/// An admin Core names without an accepted card.
const _nobody = {'login': 'carol', 'name': null, 'email': null};

Map<String, Object?> _first(Map<String, Object?> json) => (json['projects'] as List).first as Map<String, Object?>;

Map<String, Object?> _refusal(Map<String, Object?> json) => (json['refused'] as List).first as Map<String, Object?>;

/// Another host key of orchard, as a rotated host card names it.
const _otherHostKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

/// Settings whose list of machines cannot be written while [fails].
class _FailingMachines extends MemorySettingsStore {
  bool fails = true;

  /// The names of the machines last saved.
  List<String> saved = [];

  @override
  Future<void> write(Map<String, Object?> values) async {
    final machines = values['machines'];
    final names = [
      if (machines is List)
        for (final each in machines)
          if (each is Map) '${each['name']}',
    ];
    if (fails && names.length > 1) throw const FileSystemException('disk full');
    saved = names;
    await super.write(values);
  }
}

/// Settings whose project and host association cannot be written while [fails].
class _FailingProjectHosts extends MemorySettingsStore {
  bool fails = true;

  @override
  Future<void> write(Map<String, Object?> values) async {
    final hosts = values['projectHosts'];
    if (fails && hosts is Map && hosts.isNotEmpty) throw const FileSystemException('disk full');
    await super.write(values);
  }
}
