import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart' show PreparedHost;

import '../support/host_organization.dart' show hostKey, sshCompletion;

void main() {
  // Harm: one task's confirmed branch becomes another task's destination after a restart.
  test('last forwarded branches survive a restart with every identity component isolated', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    await settings.rememberForwardedBranch('machine', 'project', 'repository', 'task', 'fix-2');
    for (final identity in [
      ('other', 'project', 'repository', 'task'),
      ('machine', 'other', 'repository', 'task'),
      ('machine', 'project', 'other', 'task'),
      ('machine', 'project', 'repository', 'other'),
      ('machine', 'project', '', 'task'),
    ]) {
      final (machine, project, repository, task) = identity;
      await settings.rememberForwardedBranch(machine, project, repository, task, 'separate');
    }
    final again = Settings(store);
    addTearDown(again.dispose);
    await again.load();
    expect(again.lastForwardedBranch('machine', 'project', 'repository', 'task'), 'fix-2');
    expect(again.lastForwardedBranch('machine', 'project', '', 'task'), 'separate');
    expect(again.lastForwardedBranch('machine', 'project', 'repository', 'absent'), isNull);
  });

  // Harm: removing a task forgets the offer a later task under the same container name was given meanwhile, so that
  // task is never reported to the planner.
  test('a removal forgets only what was kept before it, not an offer kept while it is written', () async {
    final settings = Settings(MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    await settings.seeReports('laptop', 'porelo-demo-pi', 'run-1', 3);
    expect(settings.reportsSeen('laptop', 'porelo-demo-pi', 'run-1'), 3);

    final removal = settings.forgetRemovedTask('laptop', 'porelo-demo-pi');
    await settings.rememberPlanningOffer(machine: 'laptop', container: 'porelo-demo-pi', offer: 'a later offer');
    await removal;

    expect(settings.planningOffer('laptop', 'porelo-demo-pi'), 'a later offer');
    expect(
      settings.reportsSeen('laptop', 'porelo-demo-pi', 'run-1'),
      0,
      reason: 'the removed task\'s reports went with it',
    );
  });

  // Harm: reports the person read show as new again after a restart, an older number takes a newer one's place, or a
  // stored entry nobody wrote is trusted; what an earlier build kept of ideas and discussions stays in the file for ever.
  test('the reports seen survive a restart, only grow, are checked when read, and old idea marks go', () async {
    final store = MemorySettingsStore({
      'ideasHanded': ['an earlier build\'s marks'],
      'discussions': ['an earlier build\'s discussions'],
      'reportsSeen': [
        {'machine': 'laptop', 'container': 'porelo-demo-pi', 'run': 'kept', 'seen': 2},
        {'machine': 'laptop', 'container': 'porelo-demo-pi', 'run': 'zero', 'seen': 0},
        {'machine': 'laptop', 'container': 'porelo-demo-pi', 'run': 'text', 'seen': '2'},
        {'machine': '', 'container': 'porelo-demo-pi', 'run': 'nameless', 'seen': 2},
        {'machine': 'laptop', 'container': 'porelo\u0000pi', 'run': 'control', 'seen': 2},
        'not an entry',
      ],
    });
    final settings = Settings(store);
    addTearDown(settings.dispose);
    await settings.load();
    expect(settings.reportsSeen('laptop', 'porelo-demo-pi', 'kept'), 2);
    for (final run in ['zero', 'text', 'nameless', 'control']) {
      expect(settings.reportsSeen('laptop', 'porelo-demo-pi', run), 0, reason: run);
    }

    await settings.seeReports('laptop', 'porelo-demo-pi', 'kept', 5);
    await settings.seeReports('laptop', 'porelo-demo-pi', 'kept', 4);
    final again = Settings(store);
    addTearDown(again.dispose);
    await again.load();

    expect(again.reportsSeen('laptop', 'porelo-demo-pi', 'kept'), 5);
    final written = await store.read();
    expect(written.containsKey('ideasHanded'), isFalse);
    expect(written.containsKey('discussions'), isFalse);
  });

  // Harm: malformed settings supply a branch or identity that was never confirmed.
  test('every field of a stored forward is checked before it is used', () async {
    const good = {'machine': 'machine', 'project': 'project', 'repository': '', 'task': 'task', 'branch': 'fix-2'};
    for (final field in good.keys) {
      for (final invalid in [
        null,
        7,
        false,
        <Object?>[],
        <String, Object?>{},
        '\x00',
        if (field != 'repository') '',
        if (field == 'branch') ' fix-2 ',
      ]) {
        final settings = Settings(
          MemorySettingsStore({
            'forwardedBranches': [
              {...good, field: invalid},
            ],
          }),
        );
        await settings.load();
        expect(settings.lastForwardedBranch('machine', 'project', '', 'task'), isNull, reason: '$field: $invalid');
        settings.dispose();
      }
    }
  });

  // Harm: a record of the removed form runs a command with a flag the host's program no longer takes.
  test('a stored rental without the current form is not read', () {
    expect(HostUpRecord.fromStored({'scalewayProject': 'provider', 'account': 'worker'}), isNull);
  });

  // Harm: a host saved by name or IPv6 address is dropped at the next start, and with it the way to give it back.
  for (final address in ['orchard.example.org', '2001:db8::7']) {
    test('a host given and prepared at $address survives a restart', () async {
      final record = HostUpRecord(
        host: 'orchard',
        hostName: 'orchard',
        givenAddress: address,
        givenHostKey: hostKey,
        preparedHost: PreparedHost.read({...sshCompletion(), 'address': address}),
      );
      final store = MemorySettingsStore({
        'hostUps': {'orchard': record.stored},
      });
      final settings = Settings(store);
      addTearDown(settings.dispose);
      await settings.load();
      expect(settings.hostUp('orchard')?.givenAddress, address);
      expect(settings.hostUp('orchard')?.preparedHost?.address, address);
    });
  }

  test('tresor folders are kept separately and invalid stored fields are ignored', () async {
    final store = MemorySettingsStore(<String, Object?>{
      'tresorFolders': <Object?, Object?>{'demo': '/first', 'bad': 7, 9: '/wrong', 'empty': '', 'nul': '/a\x00b'},
    });
    final settings = Settings(store);
    await settings.load();
    expect(settings.tresorFolder('demo'), '/first');
    for (final name in ['bad', '9', 'empty', 'nul']) {
      expect(settings.tresorFolder(name), isNull);
    }
    await settings.rememberTresorFolder('other', '/second');
    await settings.rememberTresorFolder('demo', '/changed');
    final again = Settings(store);
    await again.load();
    expect(again.tresorFolder('demo'), '/changed');
    expect(again.tresorFolder('other'), '/second');
    await again.rememberTresorFolder('demo', null);
    final last = Settings(store);
    await last.load();
    expect(last.tresorFolder('demo'), isNull);
    expect(last.tresorFolder('other'), '/second');
  });

  // Harm: a host's key goes into a file the person did not choose, or one they let go is opened again.
  test(
    'the secrets file is kept by its path, a relative or broken one is ignored, and letting it go is kept',
    () async {
      final store = MemorySettingsStore(<String, Object?>{'secretsFile': 'relative.kdbx'});
      final settings = Settings(store);
      await settings.load();
      expect(settings.secretsFile, isNull);
      await settings.rememberSecretsFile('/home/person/Porelo/secrets.kdbx');
      final again = Settings(store);
      await again.load();
      expect(again.secretsFile, '/home/person/Porelo/secrets.kdbx');
      await again.rememberSecretsFile(null);
      final last = Settings(store);
      await last.load();
      expect(last.secretsFile, isNull);
    },
  );

  test('new machines run work as agent until somebody says otherwise, and it is kept', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    expect(settings.workUser, 'agent');

    await settings.setWorkUser('builder');

    final again = Settings(store);
    await again.load();
    expect(again.workUser, 'builder');
  });

  test('a name no Linux machine would accept is never kept', () async {
    final settings = Settings(MemorySettingsStore());

    for (final wrong in <String>['Root', 'with space', '9lives', '', "a'b", 'x' * 33]) {
      await settings.setWorkUser(wrong);
      expect(settings.workUser, 'agent', reason: '"$wrong" was kept');
    }
  });

  test('a wrong name stored by hand reads as the default', () async {
    final settings = Settings(MemorySettingsStore(<String, Object?>{'workUser': "x'; rm -rf /"}));

    await settings.load();

    expect(settings.workUser, 'agent');
  });

  // The harm: a second entry of one name, written by hand, was watched beside the first, so calls
  // meant for one machine went through the other's tunnel.
  test('a second machine of a name already read is dropped, the first kept', () async {
    final settings = Settings(
      MemorySettingsStore(<String, Object?>{
        'machines': <Map<String, Object?>>[
          <String, Object?>{'name': 'vm', 'socket': '/tmp/first.sock'},
          <String, Object?>{'name': 'vm', 'socket': '/tmp/second.sock'},
          <String, Object?>{'name': 'other', 'socket': '/tmp/other.sock'},
        ],
      }),
    );

    final machines = await settings.machines();

    expect(
      [for (final each in machines) '${each.name} ${each.socketPath}'],
      <String>['vm /tmp/first.sock', 'other /tmp/other.sock'],
    );
  });

  // The harm: what a later version or another reader of the file wrote at its top level was lost
  // at the next save.
  test('a key this version does not know is kept when the settings are written', () async {
    final store = MemorySettingsStore(<String, Object?>{
      'fromLater': <String, Object?>{'kept': true},
      'workUser': 'agent',
    });
    final settings = Settings(store);
    await settings.load();

    await settings.setRefreshSeconds(30);

    final written = await store.read();
    expect(written['fromLater'], <String, Object?>{'kept': true});
    expect(written['refreshSeconds'], 30);
  });
}
