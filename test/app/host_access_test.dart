import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_host/porelo_host.dart' show PreparedHost;
import 'package:yaml/yaml.dart';

import '../support/host_organization.dart';

void main() {
  late Settings settings;
  setUp(() => settings = Settings(MemorySettingsStore()));
  tearDown(() => settings.dispose());

  group('who may prepare a host', () {
    // Harm: anybody with a card prepares a host in the organization's name.
    test('only a host admin of that very host', () async {
      final fixture = HostFixture()..adminHosts = {'orchard'};
      final access = await fixture.access(settings);
      expect(access.unavailable('orchard'), isNull);
      expect(access.unavailable('demo'), allOf(contains('host admin of demo'), contains('hank')));
      expect(access.unavailable('nowhere'), allOf(contains('owner'), contains('mia')));
      await expectLater(access.check('demo'), throwsA(isA<HostAccessRefused>()));
    });

    // Harm: a right taken away keeps working on what was read earlier.
    test('judged on a fresh read before a side effect', () async {
      final fixture = HostFixture();
      final access = await fixture.access(settings);
      expect(access.unavailable('orchard'), isNull);
      fixture.admin = false;
      await expectLater(access.machineFile('orchard'), throwsA(isA<HostAccessRefused>()));
    });

    // Harm: a security check rests on a state that could not be fetched, so a revoked admin's pin goes to a new host.
    test('a stale answer prepares nothing', () async {
      final fixture = HostFixture()..stale = true;
      final access = await fixture.access(settings);
      expect(access.unavailable('orchard'), contains('older state'));
      await expectLater(access.machineFile('orchard'), throwsA(isA<HostAccessRefused>()));
    });

    // Harm: nobody is told why the entry stays shut.
    test("an organization that cannot be read is said by Porelo's words, a person not proven by theirs", () async {
      final refused = HostFixture()..readRefusal = 'the forge could not say';
      expect((await refused.access(settings)).unavailable('orchard'), 'the forge could not say');
      final unproven = HostFixture();
      final proof = FixtureProof(unproven)..next = null;
      final access = await unproven.access(settings, proof: proof);
      expect(access.unavailable('orchard'), 'Your key is revoked.');
    });

    // Harm: a card under another login is taken for this person's.
    test('a proven login the organization does not answer as me is no admin', () async {
      final fixture = HostFixture()..actor = const HostAdminIdentity('hank', personFingerprint, hostKey);
      expect((await fixture.access(settings)).unavailable('orchard'), contains('no card of yours'));
    });
  });

  group('what up is handed', () {
    // Harm: up runs for 20 minutes and then finds nothing it can read.
    test('the machine file holds the settings, the forge and every key, and only root-like eyes can read it', () async {
      final fixture = HostFixture()
        ..keys = const [
          HostAdminKey(login: 'alice', key: hostKey),
          HostAdminKey(login: 'alice', key: backupKey, backup: true),
        ];
      final access = await fixture.access(settings, realFiles: true);
      final file = File(await access.machineFile('orchard'));
      final part = loadYaml(await file.readAsString())['organization'];
      expect(part['settings'], 'the unread settings');
      expect(part['known_hosts'], '$forgeLine\n');
      expect(part['pin'], 'alice $hostKey\nalice $backupKey\n');
      expect((await file.stat()).mode & 0x3f, 0, reason: 'nobody else reads it');
    });

    // Harm: an admin added since the last try is never let in, since the older file stands in the way of the new pin.
    test('a later try hands on the pin of that moment', () async {
      final fixture = HostFixture();
      final access = await fixture.access(settings, realFiles: true);
      await access.machineFile('orchard');
      fixture.keys = const [HostAdminKey(login: 'alice', key: backupKey)];
      final file = File(await access.machineFile('orchard'));
      expect(loadYaml(await file.readAsString())['organization']['pin'], 'alice $backupKey\n');
    });

    // Harm: a key the organization never took acts as the host admin of that login, and a server is rented and rooted.
    test('a key that is not the one the organization holds prepares nothing', () async {
      final fixture = HostFixture()
        ..card = const OrganizationPerson(login: 'alice', standing: CardStanding.trusted, key: 'SHA256:another');
      final access = await fixture.access(settings);
      expect(access.unavailable('orchard'), isNotNull);
      await expectLater(access.machineFile('orchard'), throwsA(isA<HostAccessRefused>()));
    });

    // Harm: a card the store refused or revoked holds no role, and still prepares a host under its login.
    for (final standing in [CardStanding.refused, CardStanding.revoked]) {
      test('a card that is ${standing.name} prepares nothing', () async {
        final fixture = HostFixture()
          ..card = OrganizationPerson(login: 'alice', standing: standing, key: adminFingerprint);
        final access = await fixture.access(settings);
        expect(access.unavailable('orchard'), isNotNull);
      });
    }

    // Harm: no organization address is known, and a host is rented all the same, to follow nothing.
    for (final (what, fixture) in [
      ('no settings', HostFixture()..settings = null),
      ('no forge', HostFixture()..forge = null),
      ('empty settings', HostFixture()..settings = ''),
    ]) {
      test('$what answered: nothing is offered and nothing written', () async {
        final access = await fixture.access(settings);
        expect(access.unavailable('orchard'), HostAccess.noAddress);
        await expectLater(access.machineFile('orchard'), throwsA(isA<HostAccessRefused>()));
        expect(fixture.machineFiles, isEmpty);
      });
    }

    // Harm: a host is handed another organization's settings, or a changed copy, and follows the wrong one.
    test('the settings go to the host as Porelo answered them, whole', () async {
      final fixture = HostFixture()..settings = 'adapter: git\naddress: "git@example.org:acme/org.git"\n';
      final access = await fixture.access(settings);
      final path = await access.machineFile('orchard');
      final file = loadYaml(fixture.machineFiles[path]!) as Map;
      expect((file['organization'] as Map)['settings'], fixture.settings);
    });

    // Harm: a host is rented that could not trust its forge, and then cannot follow.
    test('no key of the forge in known_hosts stops before any file is written', () async {
      final fixture = HostFixture()..knownHosts = '';
      final access = await fixture.access(settings);
      await expectLater(
        access.machineFile('orchard'),
        throwsA(isA<HostAccessRefused>().having((each) => each.words, 'words', contains('first use is not trusted'))),
      );
    });
  });

  group('the card', () {
    PreparedHost prepared() => PreparedHost.read({
      'name': 'orchard',
      'address': '203.0.113.7',
      'ssh_host_key': hostKey,
      'services': <String, Object?>{},
    }, hostName: 'orchard');

    // Harm: a host with no forge is given a forge's ports on its card, and members are sent to a port nothing serves.
    test('a host naming no service gives no port', () async {
      final fixture = HostFixture();
      final access = await fixture.access(settings);
      expect(await access.writeCard(prepared()), isNull);
      final input = fixture.writes.single.input;
      expect(input.keys, unorderedEquals(['host', 'address', 'port', 'hostKey']));
      expect(fixture.writes.single.id, matches(RegExp(r'^[A-Za-z0-9._-]{1,64}$')));
    });

    // Harm: a refusal is lost and the host taken for named.
    test("a refusal comes back in the store's words", () async {
      final fixture = HostFixture()..writeRefusal = 'the organization moved on';
      final access = await fixture.access(settings);
      expect(await access.writeCard(prepared()), 'the organization moved on');
    });
  });
}
