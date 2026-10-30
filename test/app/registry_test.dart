import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

const _first = '1111111111111111111111111111111111111111';
const _second = '2222222222222222222222222222222222222222';
const _refusedCommit = '3333333333333333333333333333333333333333';

String _fingerprint(String letter) => 'SHA256:${letter * 43}';
String _key(String letter) => 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI${letter * 43}';

Map<String, dynamic> _card(String login, {String state = 'trusted', String? why, String? email, String letter = 'A'}) =>
    <String, dynamic>{
      'login': login,
      'name': 'Name of $login',
      'email': ?email,
      'key': _key(letter),
      'fingerprint': _fingerprint(letter),
      'state': state,
      'why': ?why,
    };

Map<String, dynamic> _answer({
  String revision = _first,
  List<Map<String, dynamic>>? people,
  Map<String, dynamic>? refused,
}) => <String, dynamic>{
  'revision': revision,
  'people':
      people ??
      [
        _card('alice', email: 'alice@example.org', letter: 'A'),
        _card('bob', letter: 'B'),
        _card('mallory', state: 'refused', why: 'its key is not on the forge account mallory', letter: 'M'),
        _card('carol', state: 'first-seen', letter: 'C'),
      ],
  'owners': [
    {'login': 'alice', 'fingerprint': _fingerprint('A'), 'backup': false},
    {'login': 'alice', 'fingerprint': _fingerprint('Z'), 'backup': true},
  ],
  'owners_signer': 'alice',
  'warnings': <String>[],
  'hosts': [
    {
      'host': 'walk9server',
      'card': <String, dynamic>{},
      'admins': ['alice', 'bob'],
      'projects': [
        {'name': 'demo', 'admin': 'bob', 'access_repository': 'git@example.org:team/demo-access.git'},
      ],
    },
  ],
  'refused_commit': ?refused,
  'unknown_field': 'ignored',
};

/// Core as the daemon would answer: each answer goes through the same reader the client uses.
class _FakeCore implements RegistryCore {
  Object next = _answer();
  Object? fileAnswer;
  Future<void>? holdFile;
  final calls = <String>[];
  final filed = <RegistryFiling>[];

  @override
  Future<RegistryRead> read(String checkout) async {
    calls.add('read $checkout');
    final next = this.next;
    if (next is Exception) throw next;
    return RegistryRead.from(next as Map<String, dynamic>);
  }

  @override
  Future<RegistryFiled> file(String checkout, RegistryFiling filing) async {
    calls.add('file $checkout');
    filed.add(filing);
    await holdFile;
    final answer = fileAnswer;
    if (answer is Exception) throw answer;
    return RegistryFiled.from(<String, dynamic>{'revision': _second});
  }
}

class _FakeCheckout implements RegistryCheckout {
  WorkspaceRefused? refuseFetch;
  WorkspaceRefused? refusePrepare;
  WorkspaceRefused? refusePublish;
  final List<String> calls;

  _FakeCheckout(this.calls);

  @override
  String get root => '/private/registry';

  @override
  String get repository => 'git@example.org:team/registry.git';

  @override
  String get folder => '/private/registry/checkout';

  @override
  Future<String> fetch() async {
    calls.add('fetch');
    if (refuseFetch case final refused?) throw refused;
    return _first;
  }

  @override
  Future<void> prepareFiling() async {
    calls.add('prepare');
    if (refusePrepare case final refused?) throw refused;
  }

  @override
  Future<void> publish(String revision) async {
    calls.add('publish');
    if (refusePublish case final refused?) throw refused;
  }
}

void main() {
  late _FakeCore core;
  late _FakeCheckout checkout;
  late Registry registry;

  setUp(() async {
    core = _FakeCore();
    checkout = _FakeCheckout(core.calls);
    registry = Registry(checkout: checkout, core: core);
    await registry.refresh();
    core.calls.clear();
  });

  // Harm: a card Core refused reaches an admission, and a refused commit wipes the verified state.
  test('a refused card reaches no change and a refused next commit keeps the accepted state', () async {
    const admitMallory = RegistryFiling(RegistryFilingKind.hostAccess, host: 'walk9server', person: 'mallory');

    expect(registry.selectable.map((card) => card.login), isNot(contains('mallory')));
    expect(registry.unavailable(admitMallory), contains('its key is not on the forge account mallory'));
    await expectLater(registry.file(admitMallory), throwsA(isA<RegistryRefusal>()));
    expect(core.filed, isEmpty, reason: 'no change may be sent for a refused card');

    core.next = _answer(
      refused: {'commit': _refusedCommit, 'path': 'people/alice.card', 'why': 'signed by another key than its own'},
    );
    await registry.refresh();

    expect(registry.accepted!.revision, _first);
    expect(registry.people.map((card) => card.login), ['alice', 'bob', 'mallory', 'carol']);
    expect(registry.hosts.single.host, 'walk9server');
    expect(registry.refusedCommit!.commit, _refusedCommit);
    expect(registry.problem, allOf(contains(_refusedCommit.substring(0, 12)), contains('signed by another key')));
    expect(registry.problem, contains('people/alice.card'));
  });

  // Harm: an absent selection bypasses the trusted-card guard and sends an admission to Core.
  test('an access change requires a selected person and a host card requires a host', () async {
    for (final people in [null, <Map<String, dynamic>>[]]) {
      core.next = _answer(people: people);
      await registry.refresh();
      for (final filing in const [
        RegistryFiling(RegistryFilingKind.hostAccess, host: 'walk9server'),
        RegistryFiling(RegistryFilingKind.hostCard),
        RegistryFiling(RegistryFilingKind.hostCard, host: ''),
      ]) {
        expect(registry.unavailable(filing), isNotNull);
        await expectLater(registry.file(filing), throwsA(isA<RegistryRefusal>()));
      }
    }
    expect(core.filed, isEmpty, reason: 'missing required choices never reach Core');
  });

  // Harm: a changed or unpublished checkout reaches Core and gets published without review.
  test('a refused checkout preparation sends no mutation and records the problem', () async {
    checkout.refusePrepare = const WorkspaceRefused('The checkout has unpublished work.');
    await expectLater(registry.file(const RegistryFiling(RegistryFilingKind.card)), throwsA(isA<WorkspaceRefused>()));
    expect(core.filed, isEmpty);
    expect(core.calls, ['prepare']);
    expect(registry.problem, contains('unpublished work'));
  });

  // Harm: retrying after a failed push silently includes the earlier unpublished mutation.
  test('a failed publication records a problem and blocks another mutation', () async {
    checkout.refusePublish = const WorkspaceRefused('Git could not publish the registry change.');
    const filing = RegistryFiling(RegistryFilingKind.card);
    await expectLater(registry.file(filing), throwsA(isA<WorkspaceRefused>()));
    expect(registry.problem, contains('could not publish'));
    await expectLater(registry.file(filing), throwsA(isA<RegistryRefusal>()));
    expect(core.filed, hasLength(1));
  });

  // Harm: a revocation accepted before a refused commit is ignored and revoked access stays offered.
  for (final initialRead in [false, true]) {
    test('Core last-good revocations are used beside a refused commit, initial=$initialRead', () async {
      core.next = _answer(
        revision: _second,
        people: [_card('alice')],
        refused: {'commit': _refusedCommit, 'path': 'people/bob.card', 'why': 'wrong signer'},
      );
      final target = initialRead ? Registry(checkout: checkout, core: core) : registry;
      addTearDown(initialRead ? target.dispose : () {});
      await target.refresh();
      expect(target.accepted!.revision, _second);
      expect(target.selectable.map((card) => card.login), ['alice']);
      expect(target.refusedCommit!.commit, _refusedCommit);
      expect(target.unavailable(const RegistryFiling(RegistryFilingKind.card)), isNotNull);
    });
  }

  // Harm: refusal of the first commit is lost or an unverified snapshot enables a mutation.
  test('a first refused commit without an accepted revision retains its reason and trusts nobody', () async {
    core.next = _answer(refused: {'commit': _refusedCommit, 'path': 'owners.yml', 'why': 'not an organization owner'})
      ..remove('revision');
    final target = Registry(checkout: checkout, core: core);
    addTearDown(target.dispose);
    await target.refresh();
    expect(target.refusedCommit!.commit, _refusedCommit);
    expect(target.problem, contains('not an organization owner'));
    expect(target.accepted, isNull);
    expect(target.selectable, isEmpty);
    expect(target.unavailable(const RegistryFiling(RegistryFilingKind.card)), isNotNull);
  });

  // Harm: a refused malformed key hides all cards or becomes available to an admission.
  for (final key in ['ssh-rsa AAAAinvalid', '${_key('A')} comment', '', null]) {
    test('a refused card with invalid key metadata remains visible and unavailable: $key', () async {
      core.next = _answer(
        people: [
          _card('alice'),
          _card('mallory', state: 'refused', why: 'invalid key')
            ..['key'] = key
            ..['fingerprint'] = null,
        ],
      );
      await registry.refresh();
      expect(registry.problem, isNull);
      expect(registry.people.map((card) => card.login), ['alice', 'mallory']);
      expect(registry.people.last.why, 'invalid key');
      expect(registry.selectable.map((card) => card.login), ['alice']);
      await expectLater(
        registry.file(const RegistryFiling(RegistryFilingKind.hostAccess, host: 'walk9server', person: 'mallory')),
        throwsA(isA<RegistryRefusal>()),
      );
      expect(core.filed, isEmpty);
    });
  }

  // Harm: legitimate hyphenated identities disappear or invalid identities cross the Core boundary.
  test('Core logins accept hyphens and reject characters outside the agreed grammar', () {
    final answer = _answer(people: [_card('alice-smith')]);
    answer['owners'] = [
      {'login': 'alice-smith', 'fingerprint': _fingerprint('A')},
    ];
    answer['owners_signer'] = 'alice-smith';
    final host = (answer['hosts'] as List).single as Map<String, dynamic>;
    host['admins'] = ['alice-smith'];
    (host['projects'] as List).single['admin'] = 'alice-smith';
    expect(RegistryRead.from(answer).people.single.login, 'alice-smith');
    for (final login in ['Alice', '1alice', 'alice.smith', 'alice_smith', 'a' * 33]) {
      expect(() => RegistryRead.from(_answer(people: [_card(login)])), throwsFormatException, reason: login);
    }
  });

  // Harm: an unassigned host has no contact for the owner who can assign its admins.
  test('a host without admins falls back to registry owners and their contact addresses', () async {
    final answer = _answer();
    (answer['hosts'] as List).single['admins'] = <String>[];
    core.next = answer;
    await registry.refresh();
    const filing = RegistryFiling(RegistryFilingKind.hostAccess, host: 'walk9server', person: 'bob');
    expect(registry.whoMay(filing).map((who) => (who.login, who.email)), [('alice', 'alice@example.org')]);
  });

  // Harm: a list that differs from Core's verdict offers the wrong person or hides who signed the owners.
  test('people, owners, hosts and projects are exactly what Core answered', () {
    expect(registry.people.map((card) => (card.login, card.name, card.email, card.fingerprint, card.state, card.why)), [
      ('alice', 'Name of alice', 'alice@example.org', _fingerprint('A'), 'trusted', ''),
      ('bob', 'Name of bob', null, _fingerprint('B'), 'trusted', ''),
      ('mallory', 'Name of mallory', null, _fingerprint('M'), 'refused', 'its key is not on the forge account mallory'),
      ('carol', 'Name of carol', null, _fingerprint('C'), 'first-seen', ''),
    ]);
    expect(registry.owners.map((owner) => (owner.login, owner.fingerprint, owner.backup)), [
      ('alice', _fingerprint('A'), false),
      ('alice', _fingerprint('Z'), true),
    ]);
    expect(registry.ownersSigner, 'alice');
    expect(registry.hosts.single.admins, ['alice', 'bob']);
    expect(registry.hosts.single.projects.map((project) => (project.name, project.admin, project.accessRepository)), [
      ('demo', 'bob', 'git@example.org:team/demo-access.git'),
    ]);
    expect(registry.accepted!.revision, _first);
    expect(registry.problem, isNull);
  });

  // Harm: a card the forge has not vouched for yet is admitted although Core did not trust it.
  test('a first-seen card is shown but cannot be named in a change', () async {
    const admitCarol = RegistryFiling(RegistryFilingKind.hostAccess, host: 'walk9server', person: 'carol');

    expect(registry.selectable.map((card) => card.login), ['alice', 'bob']);
    expect(registry.unavailable(admitCarol), contains('not been checked'));
    await expectLater(registry.file(admitCarol), throwsA(isA<RegistryRefusal>()));
    expect(core.filed, isEmpty);
  });

  // Harm: an incomplete or unsupported answer reads as an empty trusted registry, or lets a change through.
  group('an answer Core did not give completely', () {
    final broken = <String, Object>{
      'without a people list': Map<String, dynamic>.of(_answer())..remove('people'),
      'without a revision': Map<String, dynamic>.of(_answer())..remove('revision'),
      'with a card without fingerprint': _answer(people: [_card('alice')..remove('fingerprint')]),
      'with a refused card without why': _answer(people: [_card('alice', state: 'refused')]),
      'with a key carrying a comment': _answer(people: [_card('alice')..['key'] = '${_key('A')} alice@laptop']),
      'with a host without admins': Map<String, dynamic>.of(_answer())
        ..['hosts'] = [
          {'host': 'walk9server', 'projects': <Object>[]},
        ],
      'from a Porelo without the method': const FeatureNotSupported('RegistryRead'),
    };
    const admitBob = RegistryFiling(RegistryFilingKind.hostAccess, host: 'walk9server', person: 'bob');

    for (final MapEntry(key: name, value: answer) in broken.entries) {
      test('$name keeps the accepted registry and enables no change', () async {
        core.next = answer;
        await registry.refresh();

        expect(registry.accepted!.revision, _first);
        expect(registry.people, hasLength(4));
        expect(registry.problem, contains('The last accepted registry stays shown.'));
        expect(registry.unavailable(admitBob), isNotNull);
        await expectLater(registry.file(admitBob), throwsA(isA<RegistryRefusal>()));
        expect(core.filed, isEmpty);
      });

      test('$name on the first read lists nobody and enables no change', () async {
        core.next = answer;
        final first = Registry(checkout: checkout, core: core);
        await first.refresh();

        expect(first.accepted, isNull);
        expect(first.people, isEmpty);
        expect(first.selectable, isEmpty);
        expect(first.unavailable(admitBob), isNotNull);
        await expectLater(first.file(admitBob), throwsA(isA<RegistryRefusal>()));
        expect(core.filed, isEmpty);
      });
    }
  });

  // Harm: a fetch refused for want of access wipes the verified lists.
  test('a refused fetch keeps the accepted registry and asks Core nothing', () async {
    checkout.refuseFetch = const WorkspaceRefused('Git could not fetch the registry repository with your access.');
    core.next = _answer(
      revision: _second,
      people: [_card('eve', letter: 'E')],
    );
    await registry.refresh();

    expect(registry.accepted!.revision, _first);
    expect(registry.people, hasLength(4));
    expect(registry.problem, 'Git could not fetch the registry repository with your access.');
    expect(core.calls, ['fetch']);
  });

  // Harm: a person refused a change is left without knowing whom to ask.
  test('a change Core refuses names the host admins with the addresses their cards give', () async {
    core.fileAnswer = const VarlinkException('org.fuin.porelo.Tasks1.NotAHostAdmin');
    const admitBob = RegistryFiling(RegistryFilingKind.hostAccess, host: 'walk9server', person: 'bob');

    final refusal = await registry
        .file(admitBob)
        .then<RegistryRefusal?>((_) => null, onError: (Object e) => e as RegistryRefusal);

    expect(refusal!.whoMay.map((who) => (who.login, who.name, who.email)), [
      ('alice', 'Name of alice', 'alice@example.org'),
      ('bob', 'Name of bob', null),
    ]);
    expect(core.calls, isNot(contains('publish')));
  });

  // Harm: a change to a card names nobody to ask, or offers an owner's backup key as a second person.
  test('a refused card change names the registry owners once each', () {
    const card = RegistryFiling(RegistryFilingKind.card);

    expect(registry.whoMay(card).map((who) => who.login), ['alice']);
  });

  // Harm: a registry change bypasses Core's signature or is written through something other than Git.
  test('a change is written by Core, published by Git and read again, and nothing else', () async {
    const admitBob = RegistryFiling(RegistryFilingKind.hostAccess, host: 'walk9server', person: 'bob');

    final filed = await registry.file(admitBob);

    expect(filed.revision, _second);
    expect(core.calls, ['prepare', 'file ${checkout.folder}', 'publish', 'fetch', 'read ${checkout.folder}']);
    expect(core.filed.single, same(admitBob));
  });

  // Harm: a fetch moves the checkout while Core is writing a change into it.
  test('a refresh asked during a change waits until the change is published', () async {
    final writing = Completer<void>();
    core.holdFile = writing.future;
    const admitBob = RegistryFiling(RegistryFilingKind.hostAccess, host: 'walk9server', person: 'bob');

    final change = registry.file(admitBob);
    final refresh = registry.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(registry.busy, isTrue);
    writing.complete();
    await Future.wait([change, refresh]);

    expect(core.calls, [
      'prepare',
      'file ${checkout.folder}',
      'publish',
      'fetch',
      'read ${checkout.folder}',
      'fetch',
      'read ${checkout.folder}',
    ]);
    expect(registry.busy, isFalse);
  });
}
