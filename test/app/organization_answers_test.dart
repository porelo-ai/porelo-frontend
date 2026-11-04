import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';

import '../support/organization_fixtures.dart';

/// A store counting the reads a frame's questions cost, one held open where the test says.
class _Counting extends FixtureOrganization {
  _Counting() : super(organizationFor('mia'));

  final shows = <String>[];
  var lists = 0;
  Completer<void>? holdShows;
  var showing = 0;
  var mostShowingAtOnce = 0;

  @override
  Future<ProjectView> readProject(String project) async {
    shows.add(project);
    showing++;
    if (showing > mostShowingAtOnce) mostShowingAtOnce = showing;
    await holdShows?.future;
    showing--;
    return super.readProject(project);
  }

  @override
  Future<List<ListedProject>> myProjects() async {
    lists++;
    return super.myProjects();
  }
}

void main() {
  late _Counting store;
  late Organization organization;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 11, 2, 12);
    store = _Counting();
    organization = Organization(store, clock: () => now);
    addTearDown(organization.dispose);
  });

  group('a project address', () {
    // Harm: every frame of a forge page starts another `porelo project show`, each of which fetches.
    test('is read once however many frames ask, and again only once it has aged', () async {
      store.projects = {
        'one': const ProjectView(name: 'one', revision: 'r1', address: 'git@forge.example.org:a/one.git'),
      };
      for (var frame = 0; frame < 50; frame++) {
        organization.addressOf('one');
      }
      await pumpEventQueue();
      for (var frame = 0; frame < 50; frame++) {
        expect(organization.addressOf('one')?.address, 'git@forge.example.org:a/one.git');
      }
      await pumpEventQueue();
      expect(store.shows, ['one']);

      now = now.add(Organization.answersKeptFor);
      organization.addressOf('one');
      await pumpEventQueue();
      expect(store.shows, ['one', 'one']);
    });

    // Harm: a row's menu, built every frame for every project, reads what nobody asked about.
    test('is not read where the frame only looks', () async {
      expect(organization.addressOf('one', ask: false), isNull);
      await pumpEventQueue();
      expect(store.shows, isEmpty);
    });

    // Harm: opening a page of many projects starts as many commands at once, each fetching the same store.
    test('reads go one after the other', () async {
      store.holdShows = Completer<void>();
      store.projects = {
        for (final name in ['one', 'two', 'three']) name: ProjectView(name: name, revision: 'r1'),
      };
      for (final name in ['one', 'two', 'three']) {
        organization.addressOf(name);
      }
      await pumpEventQueue();
      expect(store.shows, ['one'], reason: 'the others wait their turn');
      store.holdShows!.complete();
      await pumpEventQueue();
      expect(store.shows, ['one', 'two', 'three']);
      expect(store.mostShowingAtOnce, 1);
    });

    // Harm: an address nobody filed reads as an empty one, or a refusal reads as there being none.
    test('absence and a refusal are each said as what they are', () async {
      store.projects = {'open': const ProjectView(name: 'open', revision: 'r1')};
      expect((await organization.readAddress('open')).address, isNull);
      expect((await organization.readAddress('open')).problem, isNull);
      final refused = await organization.readAddress('nobody');
      expect(refused.address, isNull);
      expect(refused.problem, 'There is no project nobody.');
    });

    // Harm: *Refresh* goes on showing an address that has changed, as nothing reads it again.
    test('refresh has the next need read it again', () async {
      await organization.readAddress('demo');
      expect(store.shows, ['demo']);
      await organization.refresh();
      expect(store.shows, ['demo'], reason: 'nothing asks for it yet');
      await organization.readAddress('demo');
      expect(store.shows, ['demo', 'demo']);
    });
  });

  group('whether a project can be removed', () {
    Future<String?> asked(String project) async {
      organization.whyNoRemoval(project);
      await pumpEventQueue();
      return organization.whyNoRemoval(project);
    }

    // Harm: removing a project is losing data, and each of these is not known to be the person's own.
    test('only what Porelo lists as local is offered', () async {
      store.listed = const [
        ListedProject(name: 'mine', source: 'local'),
        ListedProject(name: 'theirs', source: 'organization', role: 'admin'),
        ListedProject(name: 'default', source: 'built-in'),
        ListedProject(name: 'later', source: 'a-word-from-a-later-release'),
      ];
      expect(await asked('mine'), isNull);
      expect(await asked('theirs'), contains('organization'));
      expect(await asked('default'), contains('always there'));
      expect(await asked('later'), contains('a-word-from-a-later-release'));
      expect(await asked('unlisted'), contains('lists no project called unlisted'));
    });

    // Harm: a person removes a project while nothing could say it is theirs to remove.
    test('before the answer, it is not offered', () {
      store.listed = const [ListedProject(name: 'mine', source: 'local')];
      expect(organization.whyNoRemoval('mine'), isNotNull);
    });

    // Harm: as above, with Porelo's own reason lost.
    test('while the source cannot be read, it is not offered, and says Porelo’s reason', () async {
      store.refuseReads = const OrganizationRefused('The store could not be reached.');
      expect(await asked('mine'), contains('The store could not be reached.'));
    });

    // Harm: an answer from before goes on vouching for a removal after the source stopped answering.
    test('a source that stops answering takes the offer back, and one that answers again gives it', () async {
      store.listed = const [ListedProject(name: 'mine', source: 'local')];
      expect(await asked('mine'), isNull);
      store.refuseReads = const OrganizationRefused('The store could not be reached.');
      organization.readAnswersAgain();
      expect(await asked('mine'), contains('could not be reached'));
      store.refuseReads = null;
      organization.readAnswersAgain();
      expect(await asked('mine'), isNull);
    });

    // Harm: the last state read, from when the store was out of reach, decides a removal; no check rests on stale.
    test('a stale list is not asked to vouch for one', () async {
      store.listed = const [ListedProject(name: 'mine', source: 'local', stale: true)];
      expect(await asked('mine'), contains('cannot reach the Porelo organization'));
    });

    // Harm: every frame of a project list starts another `porelo project list`.
    test('the list is read once however many frames ask', () async {
      store.listed = const [ListedProject(name: 'mine', source: 'local')];
      for (var frame = 0; frame < 50; frame++) {
        await asked('mine');
      }
      expect(store.lists, 1);
    });
  });
}
