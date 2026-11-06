import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';

import '../support/organization_fixtures.dart';

/// A store whose reads and writes answer when the test says.
class _Slow implements OrganizationSource {
  final reads = <Completer<OrganizationView>>[];
  final writes = <OrganizationWrite>[];
  Object? writeFails;
  Completer<void>? writing;

  @override
  Future<bool> handTokenTo(String host) async => false;

  @override
  Future<OrganizationView> read() {
    final read = Completer<OrganizationView>();
    reads.add(read);
    return read.future;
  }

  @override
  Future<ProjectView> readProject(String project) async => demoProject;

  @override
  Future<ProjectInitDraft> readProjectInit(String checkout, {String? project, String? name, String? upstream}) async =>
      throw const OrganizationRefused('No checkout draft was supplied.');

  @override
  Future<List<OrganizationKey>> myKeys() async => const [];

  @override
  Future<List<ListedProject>> myProjects() async => const [];

  @override
  Future<void> apply(OrganizationWrite write) async {
    writes.add(write);
    await writing?.future;
    if (writeFails case final fails?) throw fails;
  }
}

OrganizationView _at(String revision) => OrganizationView(
  name: 'acme',
  keptIn: 'here',
  vouchedBy: 'GitHub',
  revision: revision,
  me: 'olive',
  persons: const [],
  projects: const [],
  hosts: const [],
  owners: const [],
);

void main() {
  late _Slow store;
  late Organization organization;

  Future<void> readAt(String revision) async {
    final read = organization.refresh();
    store.reads.last.complete(_at(revision));
    await read;
  }

  /// Answers every read asked for, at [revision].
  Future<T> answering<T>(Future<T> asked, String revision) async {
    var done = false;
    unawaited(asked.whenComplete(() => done = true));
    while (!done) {
      await pumpEventQueue();
      for (final read in store.reads) {
        if (!read.isCompleted) read.complete(_at(revision));
      }
    }
    return asked;
  }

  setUp(() {
    store = _Slow();
    organization = Organization(store);
    addTearDown(organization.dispose);
  });

  // Harm: one unexpected error leaves every later change refused as "another change", for the rest of the session.
  test('a store failing unexpectedly is said in words, and ends the asking', () async {
    await readAt('r1');
    store.writeFails = const FormatException('the store broke');
    final refusal = await answering(organization.write(OrganizationChange.addProject, {'project': 'p'}), 'r1');
    expect(refusal, isNotNull);
    expect(refusal, isNot(contains('the store broke')));
    expect(organization.busy, isFalse);
  });

  // Harm: the same change asked again under the same id but a newer revision reads as another change.
  test('a change with no answer is asked again with its id and its revision', () async {
    await readAt('r1');
    store.writeFails = const OrganizationRefused('No answer.', answered: false);
    await answering(organization.write(OrganizationChange.addProject, {'project': 'p'}), 'r2');
    store.writeFails = null;
    await answering(organization.write(OrganizationChange.addProject, {'project': 'p'}), 'r2');
    expect(store.writes[1].id, store.writes[0].id);
    expect(store.writes[1].base, 'r1');
    await answering(organization.write(OrganizationChange.addProject, {'project': 'p'}), 'r2');
    expect(store.writes[2].id, isNot(store.writes[0].id), reason: 'an answered change is a new one when asked again');
    expect(store.writes[2].base, 'r2');
  });

  // Harm: a second change goes out against the revision the first one has just moved past.
  test('the change stays busy until the read after it is in', () async {
    await readAt('r1');
    final first = organization.write(OrganizationChange.addProject, {'project': 'p'});
    await pumpEventQueue();
    expect(store.reads, hasLength(2), reason: 'the first change has been answered and is reading');
    expect(
      await organization.write(OrganizationChange.addProject, {'project': 'q'}),
      'Another change is still being asked for.',
    );
    store.reads.last.complete(_at('r2'));
    await first;
    expect(organization.busy, isFalse);
  });

  // Harm: a slow read from before a change puts the older state back, and the next change is refused against it.
  test('an older read answering late does not replace a newer one', () async {
    final older = organization.refresh();
    final newer = organization.refresh();
    store.reads[1].complete(_at('r2'));
    await newer;
    store.reads[0].complete(_at('r1'));
    await older;
    expect(organization.view?.revision, 'r2');
  });

  // Harm: a revoked card is offered what the store refuses, or an accepted card its identity source could not yet say
  // anything about loses its roles while the forge is away.
  test('a card holds roles unless it is revoked', () {
    expect(organizationFor('nora').holdsRoles, isTrue);
    expect(organizationFor('rex').holdsRoles, isFalse);
    expect(organizationFor('mia').holdsRoles, isTrue);
  });

  group('with no organization on this computer', () {
    // Harm: a person on a new computer is told only that something failed, and has no way on.
    test('the read says so, and a set-up can be asked for, naming no base', () async {
      final source = FixtureOrganization(_at('r'))
        ..refuseReads = const OrganizationRefused('no organization', reason: 'no-organization');
      final organization = Organization(source);
      addTearDown(organization.dispose);
      await organization.refresh();
      expect(organization.noOrganization, isTrue);
      expect(organization.view, isNull);

      expect(await organization.write(OrganizationChange.removeProject, const {'project': 'p'}), isNotNull);
      expect(source.writes, isEmpty);

      source.afterWrite = (_) {
        source.refuseReads = null;
        return _at('r2');
      };
      expect(await organization.write(OrganizationChange.chooseOrganization, const {'address': 'x'}), isNull);
      expect(source.writes.single.base, '');
      expect(organization.noOrganization, isFalse);
      expect(organization.view?.revision, 'r2');
    });

    // Harm: a word on another failure reads as no organization, and offers to replace one that is there.
    test('another refusal is no such word', () async {
      final source = FixtureOrganization(_at('r'))
        ..refuseReads = const OrganizationRefused('down', reason: 'cannot-say');
      final organization = Organization(source);
      addTearDown(organization.dispose);
      await organization.refresh();
      expect(organization.noOrganization, isFalse);
      expect(organization.problem, 'down');
    });

    // Harm: choosing another organization is asked against the old one's revision, which means nothing to the new.
    test('choosing another with one read names no base either', () async {
      final source = FixtureOrganization(_at('r'));
      final organization = Organization(source);
      addTearDown(organization.dispose);
      await organization.refresh();
      await organization.write(OrganizationChange.chooseOrganization, const {'address': 'x', 'replace': 'yes'});
      expect(source.writes.single.base, '');
    });
  });
}
