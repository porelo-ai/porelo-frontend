import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_host/porelo_host.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/project_access_contract.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/settings.dart';

import '../support/host_registry.dart';
import '../support/project_access.dart';

void main() {
  late Settings settings;
  late ProjectAccessFixture fixture;
  final bob = AccessDeveloper(login: 'bob', role: 'developer', fingerprint: personFingerprint);
  setUp(() {
    settings = Settings(MemorySettingsStore());
    fixture = ProjectAccessFixture();
  });
  tearDown(() {
    settings.dispose();
    fixture.registry.dispose();
  });

  // Harm: refused or changed keys must never become project access grants.
  for (final reason in [
    'refused-card',
    'ineligible-key',
    'missing-admission',
    'wrong-repository',
    'unverified-project',
    'signing-agent',
  ]) {
    test('$reason produces no signing, upload or host change', () async {
      switch (reason) {
        case 'refused-card':
          fixture.registrySource.refusedPerson = true;
        case 'ineligible-key':
          fixture.eligible = false;
        case 'missing-admission':
          fixture.registrySource.admitted = false;
        case 'wrong-repository':
          fixture.registrySource.accessRepository = 'git@example.org:other/access.git';
        case 'unverified-project':
          fixture.verifiedProject = 'other';
        case 'signing-agent':
          fixture.signing = false;
      }
      final access = await fixture.access(settings);
      await expectLater(access.change('demo', bob, remove: false), throwsA(isA<RegistryRefusal>()));
      expect(fixture.calls, isEmpty);
      expect(fixture.hostPeople, {
        'demo': <String, String>{},
        'other': {'bob': 'active'},
      });
    });
  }

  // Harm: a replacement approved for a different access scope must not grant access here.
  test('a lost-key replacement is eligible only for the project Core authorizes', () async {
    fixture.registrySource.refusedPerson = true;
    fixture.replacement = true;
    final access = await fixture.access(settings);
    await access.read('demo');
    expect(access.candidates.map((card) => card.login), ['bob']);
    await expectLater(access.change('other', bob, remove: false), throwsA(isA<RegistryRefusal>()));
    expect(fixture.calls, isEmpty);
    await access.change('demo', bob, remove: false);
    expect(fixture.hostPeople['demo'], {'bob': 'active'});
    expect(fixture.members['bob']!.fingerprint, personFingerprint);
  });

  // Harm: publishing and upload failures must not sync old intake or duplicate a signed edit.
  for (final stage in ['publish', 'upload', 'apply']) {
    test('$stage failure resumes the same published revision after restart', () async {
      fixture.fail = stage;
      final store = MemorySettingsStore();
      final first = Settings(store);
      addTearDown(first.dispose);
      final access = await fixture.access(first);
      await expectLater(access.change('demo', bob, remove: false), throwsFormatException);
      final revision = first.projectAccess('demo')!.revision;
      if (stage == 'publish') expect(fixture.calls, ['file', 'publish']);
      if (stage == 'upload') expect(fixture.calls, ['file', 'publish', 'connect', 'upload']);
      expect(first.projectAccess('demo')!.confirmed, isFalse);
      fixture.fail = null;
      fixture.uploads.clear();
      final restored = Settings(store);
      await restored.load();
      addTearDown(restored.dispose);
      final resumed = await fixture.access(restored);
      await resumed.retry();
      expect(fixture.filed.length, 1);
      expect(restored.projectAccess('demo')!.revision, revision);
      expect(restored.projectAccess('demo')!.confirmed, isTrue);
      expect(fixture.hostPeople['demo'], {'bob': 'active'});
    });
  }

  // Harm: a project lock must not lock the host account or remove other project membership.
  test('lock, unlock and remove affect only the selected project repositories and rooms', () async {
    final access = await fixture.access(settings);
    await access.change('demo', bob, remove: false);
    await access.lock('bob', locked: true);
    expect(fixture.members['bob']!.locked, isTrue);
    expect(fixture.repositories, {
      'demo': <String>{},
      'other': {'bob'},
    });
    expect(fixture.rooms, {
      'demo': <String>{},
      'other': {'bob'},
    });
    expect(fixture.accounts, {'alice', 'bob'});
    expect(fixture.hostPeople, {
      'demo': {'bob': 'locked'},
      'other': {'bob': 'active'},
    });
    await access.lock('bob', locked: false);
    expect(fixture.repositories, {
      'demo': {'bob'},
      'other': {'bob'},
    });
    expect(fixture.rooms, {
      'demo': {'bob'},
      'other': {'bob'},
    });
    await access.change('demo', fixture.members['bob']!, remove: true);
    expect(fixture.hostPeople, {
      'demo': <String, String>{},
      'other': {'bob': 'active'},
    });
    expect(fixture.accounts, {'alice', 'bob'});
  });

  // Harm: acknowledgments for another project or revision must not complete this request.
  for (final mismatch in ['project', 'access', 'project-revision']) {
    test('a wrong $mismatch answer leaves delivery pending', () async {
      if (mismatch == 'project') fixture.wrongProject = 'other';
      if (mismatch == 'access') fixture.wrongAccess = registryBefore;
      if (mismatch == 'project-revision') fixture.wrongProjectRevision = registryBefore;
      final access = await fixture.access(settings);
      await expectLater(access.change('demo', bob, remove: false), throwsA(isA<RegistryRefusal>()));
      expect(access.pending, isTrue);
    });
  }

  // Harm: reopening a dialog while an upload waits must not sign or register twice.
  test('concurrent controllers cannot duplicate publication', () async {
    fixture.uploadStarted = Completer<void>();
    final release = Completer<void>();
    fixture.holdUpload = release.future;
    final access = await fixture.access(settings);
    final running = access.change('demo', bob, remove: false);
    await fixture.uploadStarted!.future;
    final other = await fixture.access(settings);
    await expectLater(other.retry(), throwsA(isA<RegistryRefusal>()));
    release.complete();
    await running;
    expect(fixture.calls.where((call) => call == 'file').length, 1);
    expect(fixture.calls.where((call) => call == 'apply').length, 1);
  });

  // Harm: a callback retained across admission loss must not upload or register.
  test('admission lost while connecting prevents delivery', () async {
    final access = await fixture.access(settings);
    fixture.onConnect = () async {
      fixture.registrySource.admitted = false;
      await fixture.registry.refresh();
    };
    await expectLater(access.register(), throwsA(isA<RegistryRefusal>()));
    expect(fixture.calls, ['file', 'publish', 'connect']);
    expect(settings.projectAccess('demo')!.confirmed, isFalse);
  });

  // Harm: signing a self-revocation must not leave published access undeliverable.
  test('self-removal delivers the signed change after current admin authority ends', () async {
    final alice = AccessDeveloper(login: 'alice', role: 'admin', fingerprint: adminFingerprint);
    fixture.members['alice'] = alice;
    fixture.hostPeople['demo']!['alice'] = 'active';
    fixture.selfRevokes = true;
    final access = await fixture.access(settings);
    await access.change('demo', alice, remove: true);
    expect(fixture.authorized, isFalse);
    expect(fixture.hostPeople['demo']!.containsKey('alice'), isFalse);
    expect(settings.projectAccess('demo')!.confirmed, isTrue);
  });

  // Harm: revoking signing authority must not hide delivery recovery or enable another grant.
  test('self-removal upload failure permits only delivery recovery', () async {
    final alice = AccessDeveloper(login: 'alice', role: 'admin', fingerprint: adminFingerprint);
    fixture.members['alice'] = alice;
    fixture.selfRevokes = true;
    fixture.fail = 'upload';
    final access = await fixture.access(settings);
    await expectLater(access.change('demo', alice, remove: true), throwsFormatException);
    expect(access.unavailable(), isNotNull);
    expect(access.unavailable(delivery: true), isNull);
    fixture.fail = null;
    await access.retry();
    expect(fixture.filed.length, 1);
    expect(settings.projectAccess('demo')!.confirmed, isTrue);
    await expectLater(access.change('demo', bob, remove: false), throwsA(isA<RegistryRefusal>()));
    expect(fixture.filed.length, 1);
  });

  // Harm: a lost publication receipt must not strand self-removal after restart.
  test('self-removal recovers publication whose durable receipt was lost', () async {
    final store = _LostPublicationReceipt();
    final first = Settings(store);
    addTearDown(first.dispose);
    final alice = AccessDeveloper(login: 'alice', role: 'admin', fingerprint: adminFingerprint);
    fixture.members['alice'] = alice;
    fixture.selfRevokes = true;
    final access = await fixture.access(first);
    await expectLater(access.change('demo', alice, remove: true), throwsA(isA<Exception>()));
    expect(fixture.published.length, 1);
    expect(first.projectAccess('demo')!.published, isFalse);
    final restored = Settings(store);
    addTearDown(restored.dispose);
    await restored.load();
    final resumed = await fixture.access(restored);
    await resumed.read('demo');
    expect(
      resumed.unavailable(delivery: true),
      isNull,
      reason: 'Retry must allow read-only reconciliation of a signed change',
    );
    await resumed.retry();
    expect(fixture.filed.length, 1);
    expect(fixture.calls.where((call) => call == 'publish').length, 1);
    expect(restored.projectAccess('demo')!.confirmed, isTrue);
  });

  // Harm: signing-time authority must come from Core's exact accepted commit verdict.
  test('Core refusal of published delivery prevents connection and upload', () async {
    fixture.deliveryAuthorized = false;
    final access = await fixture.access(settings);
    await expectLater(access.register(), throwsFormatException);
    expect(fixture.calls, ['file', 'publish']);
    expect(settings.projectAccess('demo')!.confirmed, isFalse);
  });

  // Harm: a changed host card under the same name must not reuse the old connection.
  for (final stage in ['connect', 'upload']) {
    test('a host pin changed during $stage prevents the next delivery step', () async {
      void replace() {
        fixture.host = PreparedHost.read({...sshCompletion(), 'address': '203.0.113.9'});
      }

      if (stage == 'connect') fixture.onConnect = replace;
      if (stage == 'upload') fixture.onUpload = replace;
      final access = await fixture.access(settings);
      await expectLater(access.register(), throwsA(isA<RegistryRefusal>()));
      expect(fixture.calls, isNot(contains('apply')));
      if (stage == 'connect') expect(fixture.calls, isNot(contains('upload')));
      expect(settings.projectAccess('demo')!.confirmed, isFalse);
    });
  }

  // Harm: malformed persistence must not silently discard unfinished access work.
  test('progress refuses invalid ordering, identities and scope', () async {
    final access = await fixture.access(settings);
    await access.register();
    final valid = settings.projectAccess('demo')!.stored;
    for (final fields in [
      {'revision': 'invalid'},
      {'published': false},
      {'uploaded': false},
      {
        'change': {...settings.projectAccess('demo')!.change.stored, 'host': '../other'},
      },
      {
        'change': {...settings.projectAccess('demo')!.change.stored, 'action': 'purge'},
      },
    ]) {
      expect(() => ProjectAccessProgress.read({...valid, ...fields}), throwsA(isA<Exception>()));
    }
  });
}

class _LostPublicationReceipt extends MemorySettingsStore {
  bool fail = true;
  @override
  Future<void> write(Map<String, Object?> values) async {
    final work = values['projectAccess'];
    if (fail && work is Map && work['demo'] is Map && (work['demo'] as Map)['published'] == true) {
      fail = false;
      throw const FormatException('The publication receipt was not saved.');
    }
    await super.write(values);
  }
}
