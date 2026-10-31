import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/registry_checkout.dart';
import 'package:porelo_frontend/src/app/registry_pages.dart';
import 'package:porelo_frontend/src/app/registry_read_source.dart';

const _repository = 'git@example.org:team/registry.git';
const _first = '1111111111111111111111111111111111111111';
const _refusedCommit = '3333333333333333333333333333333333333333';

String _fingerprint(String letter) => 'SHA256:${letter * 43}';

Map<String, dynamic> _card(String login, String letter, {String state = 'trusted', String? why}) => <String, dynamic>{
  'login': login,
  'name': 'Name of $login',
  'key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI${letter * 43}',
  'fingerprint': _fingerprint(letter),
  'state': state,
  'why': ?why,
};

Map<String, dynamic> _answer({String? revision = _first, Map<String, dynamic>? refused}) => <String, dynamic>{
  'revision': revision,
  'people': [
    _card('alice', 'A'),
    _card('bob', 'B'),
    _card('mallory', 'M', state: 'refused', why: 'its key is not on the forge account mallory'),
    _card('carol', 'C', state: 'first-seen'),
  ],
  'owners': [
    {'login': 'alice', 'fingerprint': _fingerprint('A'), 'backup': false},
  ],
  'warnings': <String>[],
  'hosts': [
    {
      'host': 'walk9server',
      'card': <String, dynamic>{},
      'admins': [
        {'login': 'alice', 'fingerprint': _fingerprint('A')},
      ],
      'projects': [
        {'name': 'demo', 'admin': 'bob', 'access_repository': 'git@example.org:team/demo-access.git'},
      ],
    },
  ],
  'refused_commit': ?refused,
};

class _FakeCore implements RegistryCore {
  Map<String, dynamic> next = _answer();

  Completer<void>? hold;

  @override
  Future<RegistryRead> read(String checkout) async {
    final answer = next;
    await hold?.future;
    return RegistryRead.from(answer);
  }

  @override
  Future<RegistryFiled> file(String checkout, RegistryFiling filing) => throw UnimplementedError();
}

class _FakeCheckout implements RegistryCheckout {
  @override
  String get root => '/private/registry';

  @override
  String get repository => _repository;

  @override
  String get folder => '/private/registry/checkout';

  @override
  Future<String> fetch() async => _first;

  @override
  Future<void> prepareFiling() async {}

  @override
  Future<void> publish(String revision) async {}
}

void main() {
  const watched = Machine(name: 'walk9server', socketPath: '/run/forward.sock', host: 'walk9server');
  late _FakeCore core;
  late RegistryPages pages;
  String? repository;

  setUp(() {
    core = _FakeCore();
    repository = _repository;
    pages = RegistryPages(
      source: RegistryReadSource(
        repository: () => repository,
        open: (_) => Registry(checkout: _FakeCheckout(), core: core),
        machines: () => [watched],
      ),
      features: const RegistryPageFeatures(operations: {RegistryOperation.refresh}),
    );
  });

  // Guards admitting a person whose card Core refused or has not yet checked against the forge.
  test('a picker is offered only the cards Core trusts', () async {
    await pages.refresh();

    expect(pages.people.map((person) => person.login), ['alice', 'bob'], reason: 'mallory is refused, carol unchecked');
    expect(pages.problem, isNull);
  });

  // Guards losing the verified lists, or acting on a state Core refused, when a newer commit is refused.
  test('a refused next commit is named and the last accepted lists stay', () async {
    await pages.refresh();
    core.next = _answer(
      refused: {'commit': _refusedCommit, 'path': 'hosts/walk9server/access.yml', 'why': 'signed by no host admin'},
    );

    await pages.refresh();

    expect(pages.problem, contains(_refusedCommit.substring(0, 12)), reason: 'the refused commit is named');
    expect(pages.problem, contains('signed by no host admin'), reason: "Core's reason is shown");
    expect(pages.items.map((item) => item.target), [
      (registry: _repository, host: 'walk9server', project: null),
      (registry: _repository, host: 'walk9server', project: 'demo'),
    ], reason: 'the last accepted host and project stay listed');
    expect(
      pages.unavailable(pages.items.first.target, RegistryOperation.refresh),
      isNotNull,
      reason: 'no change is made on a state Core did not accept',
    );
  });

  // Guards a registry whose first commit Core refused reading as an empty, trusted registry.
  test('a registry with no accepted commit lists nothing and says why', () async {
    core.next = _answer(
      revision: null,
      refused: {'commit': _refusedCommit, 'path': 'owners.yml', 'why': 'not signed by an owner'},
    );

    await pages.refresh();

    expect(pages.loaded, isFalse, reason: 'nothing accepted is nothing loaded');
    expect(pages.items, isEmpty);
    expect(pages.problem, contains('not signed by an owner'));
  });

  // Guards a registry nobody chose reading as an empty, verified one.
  test('without a chosen registry nothing is read and the page says to choose one', () async {
    repository = null;

    await pages.refresh();

    expect(pages.loaded, isFalse);
    expect(pages.items, isEmpty);
    expect(pages.problem, 'Choose the registry repository first.');
  });

  // Guards one registry's verified lists showing under another address after the address changed.
  test('another address shows nothing of the one before, also when it cannot be read', () async {
    await pages.refresh();
    expect(pages.items, isNotEmpty);
    repository = 'git@example.org:other/registry.git';
    core.next = _answer(
      revision: null,
      refused: {'commit': _refusedCommit, 'path': 'owners.yml', 'why': 'not signed by an owner'},
    );

    await pages.readAfresh();

    expect(pages.items, isEmpty, reason: 'nothing of the earlier registry stays');
    expect(pages.people, isEmpty);
    expect(pages.loaded, isFalse);
    expect(pages.problem, contains('not signed by an owner'));
  });

  // Guards a read of the earlier address, still running at the change, installing its state as current.
  test('a read still running when the address changes is never shown', () async {
    core.hold = Completer<void>();
    final earlier = pages.refresh();
    await pumpEventQueue();
    repository = 'git@example.org:other/registry.git';
    final afresh = pages.readAfresh();
    core.next = _answer(
      revision: null,
      refused: {'commit': _refusedCommit, 'path': 'owners.yml', 'why': 'not signed by an owner'},
    );
    core.hold!.complete();
    core.hold = null;

    await earlier;
    await afresh;

    expect(pages.items, isEmpty, reason: "the earlier address's hosts are not shown");
    expect(pages.loaded, isFalse);
    expect(pages.problem, contains('not signed by an owner'));
  });
}
