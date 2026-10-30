import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/registry_pages.dart';

import '../support/registry_page_source.dart';

const _person = RegistryPerson(login: 'bob', name: 'Bob', email: 'bob@example.org');
const _machine = Machine(name: 'first', socketPath: '/first');
const _target = (registry: 'registry', host: 'first', project: 'checkout');
const _other = (registry: 'registry', host: 'second', project: 'checkout');

RegistryPageItem _item(
  RegistryTarget target, {
  Set<RegistryOperation> allowed = const {RegistryOperation.projectLock},
}) => RegistryPageItem(
  target: target,
  machine: _machine,
  role: 'project admin',
  state: 'registered',
  revision: 'revision-1',
  allowed: allowed,
  administrators: const [_person],
  members: const [RegistryMember(person: _person, role: 'developer', state: 'active')],
);

void main() {
  // Harm: refreshing a list must not publish or apply an access change.
  test('refreshing a registry reads without publishing or applying', () async {
    final source = FakeRegistryPageSource(
      RegistryPageSnapshot(
        items: [
          _item(_target, allowed: {RegistryOperation.refresh}),
        ],
      ),
    );
    final registry = RegistryPages(
      source: source,
      features: const RegistryPageFeatures(operations: {RegistryOperation.refresh}),
    );
    addTearDown(registry.dispose);
    await registry.refresh();
    await registry.change((target: _target, operation: RegistryOperation.refresh, person: null));
    expect(source.published, isEmpty);
    expect(source.applications, isEmpty);
  });

  // Harm: an old local overlay can hide newly verified access and imply obsolete host synchronization.
  test('new verified revisions replace older publication and host overlays', () async {
    final source = FakeRegistryPageSource(
      RegistryPageSnapshot(
        items: [_item(_target)],
        people: const [_person],
        applied: const {_target: RegistryHostState(revision: 'revision-1')},
      ),
    );
    final registry = RegistryPages(
      source: source,
      features: const RegistryPageFeatures(operations: {RegistryOperation.projectLock}),
    );
    addTearDown(registry.dispose);
    await registry.refresh();
    await registry.change((target: _target, operation: RegistryOperation.projectLock, person: 'bob'));
    source.snapshot = RegistryPageSnapshot(
      items: [
        RegistryPageItem(
          target: _target,
          machine: _machine,
          role: 'developer',
          state: 'registered',
          revision: 'revision-3',
        ),
      ],
      people: const [_person],
      applied: const {
        _target: RegistryHostState(revision: 'revision-3', personStates: {'bob': 'active'}),
      },
    );
    await registry.refresh();
    expect(registry.decidedRevision(_target), 'revision-3');
    expect(registry.applied(_target)!.personStates, {'bob': 'active'});
    expect(registry.pending(_target), isFalse);
  });

  // Harm: false synchronization success can leave revoked access active without warning.
  test('published access retains the last confirmed host state when application fails', () async {
    final source = FakeRegistryPageSource(
      RegistryPageSnapshot(
        items: [_item(_target)],
        people: const [_person],
        applied: const {
          _target: RegistryHostState(revision: 'revision-1', personStates: {'bob': 'active'}),
        },
      ),
    )..failApply = true;
    final registry = RegistryPages(
      source: source,
      features: const RegistryPageFeatures(operations: {RegistryOperation.projectLock}),
    );
    addTearDown(registry.dispose);
    await registry.refresh();
    await registry.change((target: _target, operation: RegistryOperation.projectLock, person: 'bob'));
    expect(source.published, [(target: _target, operation: RegistryOperation.projectLock, person: 'bob')]);
    expect(registry.applied(_target)!.personStates, {'bob': 'active'});
    expect(registry.applied(_target)!.revision, 'revision-1');
    expect(registry.decidedRevision(_target), 'revision-2');
    expect(registry.pending(_target), isTrue);
    expect(registry.failure(_target), isNotNull);
  });

  // Harm: a stale menu must never bypass permission checks or affect a same-named project.
  test('forbidden and unverified people send no mutation while a permitted scope changes only itself', () async {
    final source = FakeRegistryPageSource(
      RegistryPageSnapshot(
        items: [
          _item(_target, allowed: {}),
          _item(_other),
        ],
        people: const [_person],
      ),
    );
    final registry = RegistryPages(
      source: source,
      features: const RegistryPageFeatures(operations: {RegistryOperation.projectLock}),
    );
    addTearDown(registry.dispose);
    await registry.refresh();
    for (final change in [
      (target: _target, operation: RegistryOperation.projectLock, person: 'bob'),
      (target: _other, operation: RegistryOperation.projectLock, person: 'mallory'),
    ]) {
      await expectLater(registry.change(change), throwsStateError);
    }
    expect(source.published, isEmpty);
    await registry.change((target: _other, operation: RegistryOperation.projectLock, person: 'bob'));
    expect(source.hostPersons, {
      _other: {'bob': 'locked'},
    });
    expect(source.applications, [(target: _other, revision: 'revision-2')]);
  });

  // Harm: an unreadable source must not erase verified access or permit changes on stale permissions.
  test('a failed refresh retains verified admissions and blocks changes until a successful read', () async {
    final source = FakeRegistryPageSource(RegistryPageSnapshot(items: [_item(_target)], people: const [_person]));
    final registry = RegistryPages(
      source: source,
      features: const RegistryPageFeatures(operations: {RegistryOperation.projectLock}),
    );
    addTearDown(registry.dispose);
    await registry.refresh();
    source.failRead = true;
    await registry.refresh();
    expect(registry.items.map((item) => item.target), [_target]);
    await expectLater(
      registry.change((target: _target, operation: RegistryOperation.projectLock, person: 'bob')),
      throwsStateError,
    );
    expect(source.published, isEmpty);
    source.failRead = false;
    await registry.refresh();
    await registry.change((target: _target, operation: RegistryOperation.projectLock, person: 'bob'));
    expect(source.hostPersons, {
      _target: {'bob': 'locked'},
    });
  });
}
