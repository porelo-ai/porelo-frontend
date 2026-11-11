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

/// The organization at [revision], holding [project] beside nothing else.
OrganizationView _holding(String revision, [OrganizationProject? project, bool stale = false]) => OrganizationView(
  stale: stale,
  name: 'acme',
  keptIn: 'here',
  vouchedBy: 'GitHub',
  revision: revision,
  me: 'olive',
  projects: [?project],
);

/// A store that moves to what [whileAsked] answers while a write is asked, taken or refused.
class _Moving extends FixtureOrganization {
  _Moving(super.view);

  /// The state the store is in once the write was asked for.
  OrganizationView Function(OrganizationWrite write)? whileAsked;

  @override
  Future<void> apply(OrganizationWrite write) {
    if (whileAsked case final move?) view = move(write);
    return super.apply(write);
  }
}

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

  group('a project added with its repository in one step', () {
    const mine = {'project': 'mine', 'admin': 'olive', 'review': 'optional'};
    const added = OrganizationProject(name: 'mine', admins: ['olive'], opened: false);
    const halfway = OrganizationRefused(
      'project mine is added, and its repository is not: the forge refused: ask again with --id 1',
      reason: 'not-allowed',
    );

    /// An organization at r1 without the project, whose store moves to [whileAsked]'s answer while a write is asked.
    Future<(_Moving, Organization)> asking() async {
      final source = _Moving(_holding('r1'));
      final organization = Organization(source);
      addTearDown(organization.dispose);
      await organization.refresh();
      return (source, organization);
    }

    /// Asks for the project, refused [refusal] while the store moves to [revision] holding [project].
    Future<void> refused(
      _Moving source,
      Organization organization,
      String revision, {
      OrganizationProject? project = added,
      OrganizationRefused refusal = halfway,
    }) async {
      source
        ..whileAsked = ((_) => _holding(revision, project))
        ..refuseNext = refusal;
      expect(await organization.write(OrganizationChange.addProject, mine), isNotNull);
      source.whileAsked = null;
    }

    // Harm: the project stands without its repository, and asking again under a new id is refused as a project that
    // exists, so the step the refusal says is left can never be finished from here.
    test('refused after the project stood, is asked again under its id and revision, which finishes it', () async {
      final (source, organization) = await asking();
      await refused(source, organization, 'r2');
      expect(await organization.write(OrganizationChange.addProject, mine), isNull);
      expect(source.writes[1].id, source.writes[0].id);
      expect(source.writes[1].base, 'r1');
    });

    // Harm: the same, after *Try again* was refused once more while the project still has no repository.
    test('refused again on asking again, is still asked under its first id', () async {
      final (source, organization) = await asking();
      await refused(source, organization, 'r2');
      await refused(source, organization, 'r3');
      expect(await organization.write(OrganizationChange.addProject, mine), isNull);
      expect(source.writes[1].id, source.writes[0].id);
      expect(source.writes[2].id, source.writes[0].id);
      expect(source.writes[2].base, 'r1');
    });

    // Harm: a refusal that added nothing, asked again on the revision it was refused against, is refused as moved on.
    test('refused before the project stood, is a new change on the newer revision when asked again', () async {
      final (source, organization) = await asking();
      await refused(source, organization, 'r2', project: null);
      await organization.write(OrganizationChange.addProject, mine);
      expect(source.writes[1].id, isNot(source.writes[0].id));
      expect(source.writes[1].base, 'r2');
    });

    // Harm: someone else added the same name meanwhile; asked again on the revision it was refused against, it is
    // refused as moved on for ever.
    test('refused as moved on while the project came to stand, is a new change when asked again', () async {
      final (source, organization) = await asking();
      await refused(
        source,
        organization,
        'r2',
        refusal: const OrganizationRefused('The organization has moved on.', reason: 'moved-on'),
      );
      await organization.write(OrganizationChange.addProject, mine);
      expect(source.writes[1].id, isNot(source.writes[0].id));
      expect(source.writes[1].base, 'r2');
    });

    // Harm: the same, where the project that came to stand is not the one asked for.
    for (final (what, project) in [
      ('with another admin', const OrganizationProject(name: 'mine', admins: ['hana'], opened: false)),
      ('with its repository', const OrganizationProject(name: 'mine', admins: ['olive'], opened: true)),
    ]) {
      test('refused while a project of the name came to stand $what, is a new change when asked again', () async {
        final (source, organization) = await asking();
        await refused(source, organization, 'r2', project: project);
        await organization.write(OrganizationChange.addProject, mine);
        expect(source.writes[1].id, isNot(source.writes[0].id));
        expect(source.writes[1].base, 'r2');
      });
    }

    // Harm: a read that failed or answered an old state says nothing of the project; asked again under a new id, the
    // project Porelo added is refused as one that exists.
    for (final (what, after) in [
      ('failed', (_Moving source) => source.refuseReads = const OrganizationRefused('Porelo cannot be reached.')),
      ('answered an old state', (_Moving source) => source.view = _holding('r1', null, true)),
    ]) {
      test('refused while the read after it $what, is asked again under its id', () async {
        final (source, organization) = await asking();
        source.whileAsked = (_) {
          after(source);
          return source.view;
        };
        source.refuseNext = halfway;
        await organization.write(OrganizationChange.addProject, mine);
        source
          ..whileAsked = null
          ..refuseReads = null;
        await organization.write(OrganizationChange.addProject, mine);
        expect(source.writes[1].id, source.writes[0].id);
      });
    }

    // Harm: a read asked for meanwhile overtakes the one after the refusal, which then decides on the old state.
    test('refused while another read overtakes the one after it, decides on the newer read', () async {
      await readAt('r1');
      store.writeFails = halfway;
      final asked = organization.write(OrganizationChange.addProject, mine);
      while (store.reads.length < 2) {
        await pumpEventQueue();
      }
      final overtaking = organization.refresh();
      store.reads[1].complete(_holding('r1'));
      await pumpEventQueue();
      store.reads[2].complete(_holding('r2', added));
      await overtaking;
      await asked;
      store.writeFails = null;
      await answering(organization.write(OrganizationChange.addProject, mine), 'r2');
      expect(store.writes[1].id, store.writes[0].id);
    });

    // Harm: the id of a project since finished or removed is asked again for a new project of the same name, which
    // Porelo takes as the old request.
    for (final (what, change, input) in [
      (
        'its repository was created',
        OrganizationChange.createProjectRepository,
        {'project': 'mine', 'review': 'optional'},
      ),
      ('it was removed', OrganizationChange.removeProject, {'project': 'mine'}),
    ]) {
      test('refused, then $what here, is a new change when asked again', () async {
        final (source, organization) = await asking();
        await refused(source, organization, 'r2');
        source.refuseReads = const OrganizationRefused('Porelo cannot be reached.');
        expect(await organization.write(change, input), isNull);
        await organization.write(OrganizationChange.addProject, mine);
        expect(source.writes[2].id, isNot(source.writes[0].id));
      });
    }

    for (final (what, project) in [
      ('has its repository', const OrganizationProject(name: 'mine', admins: ['olive'], opened: true)),
      ('is gone', null),
    ]) {
      test('refused, then read where the project $what, is a new change when asked again', () async {
        final (source, organization) = await asking();
        await refused(source, organization, 'r2');
        source.view = _holding('r3', project);
        await organization.refresh();
        await organization.write(OrganizationChange.addProject, mine);
        expect(source.writes[1].id, isNot(source.writes[0].id));
        expect(source.writes[1].base, 'r3');
      });
    }

    // Harm: *Try again* is held back to review a project page, while it only finishes what the refusal said is left.
    test('refused with a revision of its own, may be tried again at once', () async {
      final (source, organization) = await asking();
      source
        ..whileAsked = ((_) => _holding('r2', added))
        ..refuseNext = halfway;
      await organization.write(OrganizationChange.addProject, mine, base: 'r1', provisional: true);
      final row = organization.rowChanges.single;
      expect(organization.whyNoRetry(row), isNull);
    });
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

  group('the last read of a project', () {
    late OrganizationRowChange refused;

    /// An organization pat reads, whose page of demo read it once after a change of it was refused.
    Future<(FixtureOrganization, Organization)> remembered() async {
      final source = FixtureOrganization(organizationFor('pat'))
        ..refuseNext = const OrganizationRefused('The forge said no.');
      final organization = Organization(source);
      addTearDown(organization.dispose);
      await organization.refresh();
      const hana = {'project': 'demo', 'login': 'hana', 'role': 'developer'};
      await organization.write(OrganizationChange.addProjectMember, hana, base: 'p1', provisional: true);
      organization.rememberProjectRevision(demoProject);
      expect(organization.lastReadOf('demo'), demoProject);
      refused = organization.rowChanges.single;
      expect(organization.whyNoRetry(refused), isNull);
      return (source, organization);
    }

    /// Whether demo's refused change may be asked again without its page reading it again.
    bool reviewed(Organization organization) => organization.whyNoRetry(refused) == null;

    // Harm: another organization's project of the same name is shown at once as this one's.
    for (final change in [OrganizationChange.chooseOrganization, OrganizationChange.createOrganization]) {
      test('is forgotten once ${change.name} is taken', () async {
        final (_, organization) = await remembered();
        expect(await organization.write(change, const {'address': 'git@forge.example.org:other/org.git'}), isNull);
        expect(organization.lastReadOf('demo'), isNull);
        expect(reviewed(organization), isFalse, reason: 'its revision is no longer one of this organization');
      });
    }

    test('is forgotten once this computer names no organization', () async {
      final (source, organization) = await remembered();
      source.refuseReads = const OrganizationRefused('No organization.', reason: 'no-organization');
      await organization.refresh();
      expect(organization.lastReadOf('demo'), isNull);
      expect(reviewed(organization), isFalse);
    });

    // Harm: a page opened again shows the project as it stood before a change taken while the page was closed.
    test('is forgotten once a change of its project is taken', () async {
      final (_, organization) = await remembered();
      expect(
        await organization.write(OrganizationChange.lockProjectMember, const {'project': 'demo', 'login': 'mia'}),
        isNull,
      );
      expect(organization.lastReadOf('demo'), isNull);
      expect(reviewed(organization), isFalse, reason: 'its revision is the one before the change');
    });

    // Harm: a change written by an older Porelo itself leaves the project shown, and asked again, as it was before.
    test('is forgotten once an older Porelo writes its project file itself', () async {
      final (source, organization) = await remembered();
      source.writesProjectFiles = true;
      final asked = await organization.entryFor(OrganizationChange.changeProjectReview, const {
        'project': 'demo',
        'review': 'required',
      });
      expect((asked.byHand, asked.refusal), (null, null));
      expect(organization.lastReadOf('demo'), isNull);
      expect(reviewed(organization), isFalse);
    });

    // Harm: a project read that answers while an older Porelo writes the project file passes for the project after it.
    test('a read answering while an older Porelo writes the project file is not taken', () async {
      final (source, organization) = await remembered();
      final writing = Completer<void>();
      source
        ..writesProjectFiles = true
        ..holdWrites = writing.future;
      final mark = organization.writeMark;
      final asked = organization.entryFor(OrganizationChange.changeProjectReview, const {
        'project': 'demo',
        'review': 'required',
      });
      await pumpEventQueue();
      expect(organization.readsAfterWrites(mark), isFalse);
      writing.complete();
      await asked;
      expect(organization.readsAfterWrites(mark), isFalse);
    });

    // Harm: another organization's role or lock in a project of the same name is said in this one's.
    test('what project list said is forgotten with the organization, and only a fresh entry of it is named', () async {
      final (_, organization) = await remembered();
      organization.keepListed(const [ListedProject(name: 'demo', source: 'organization', role: 'admin')]);
      expect(organization.listedOf('demo')?.role, 'admin');
      expect(
        await organization.write(OrganizationChange.chooseOrganization, const {
          'address': 'git@forge.example.org:o/org.git',
        }),
        isNull,
      );
      expect(organization.listedOf('demo'), isNull);
      organization.keepListed(const [
        ListedProject(name: 'demo', source: 'organization', role: 'admin', stale: true),
        ListedProject(name: 'other', source: 'local'),
      ]);
      expect(organization.listedOf('demo'), isNull, reason: 'a stale answer');
      expect(organization.listedOf('other'), isNull, reason: "not the organization's");
    });

    // Harm: a removed project's page shows it at once as if it stood.
    test('is forgotten once the organization no longer holds its project, unless that read is stale', () async {
      final (source, organization) = await remembered();
      source.view = _holding('r2', null, true);
      await organization.refresh();
      expect(organization.lastReadOf('demo'), demoProject, reason: 'a stale read cannot tell it is gone');
      source.view = _holding('r3');
      await organization.refresh();
      expect(organization.lastReadOf('demo'), isNull);
      expect(reviewed(organization), isFalse);
    });
  });

  // Harm: a state kept from before reads as just read, so keys revoked since look current.
  test('a stale read says when the store was reached last, never the time it was asked', () async {
    final asked = DateTime.utc(2026, 11, 11, 9);
    final reached = DateTime.utc(2026, 11, 11, 6, 33);
    final store = FixtureOrganization(
      OrganizationView(
        stale: true,
        checkedAt: reached,
        name: 'acme',
        keptIn: 'here',
        vouchedBy: 'GitHub',
        revision: 'r1',
        me: 'olive',
      ),
    );
    final stale = Organization(store, clock: () => asked);
    addTearDown(stale.dispose);
    await stale.refresh();
    expect(stale.readAt, reached, reason: 'a stale state is as old as the last time the store was reached');

    store.view = OrganizationView(name: 'acme', keptIn: 'here', vouchedBy: 'GitHub', revision: 'r2', me: 'olive');
    await stale.refresh();
    expect(stale.readAt, asked, reason: 'a fresh state is as new as the read that brought it');
  });
}
