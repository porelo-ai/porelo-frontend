import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';

import '../support/organization_fixtures.dart';

/// The organization as Porelo kept it, shown while its check runs.
OrganizationView _kept(String revision) => OrganizationView(
  name: 'acme',
  keptIn: 'git@forge.example.org:acme/porelo.git',
  vouchedBy: 'pat',
  revision: revision,
  me: 'pat',
  stale: true,
  checkedAt: DateTime.utc(2026, 11, 11, 5, 33),
);

/// Hands [kept] at once and answers the checked state when the test lets it.
class _KeptFirst extends FixtureOrganization implements ReadsKeptFirst {
  _KeptFirst(super.view);

  OrganizationView kept = _kept('k1');
  Completer<void>? held;

  @override
  Future<OrganizationView> readKeptFirst(void Function(OrganizationView kept) handed) async {
    handed(kept);
    await held?.future;
    return read();
  }

  @override
  Future<ProjectView> readProjectKeptFirst(String project, void Function(ProjectView kept) handed) =>
      readProject(project);
}

void main() {
  // Harm: the organization's pages stay empty for as long as Porelo's check takes.
  test('the kept organization is shown at once, as stale and as old as its check, then the checked one', () async {
    final source = _KeptFirst(organizationFor('pat'))..held = Completer<void>();
    final organization = Organization(source);
    addTearDown(organization.dispose);
    final reading = organization.refresh();
    await pumpEventQueue();
    expect(organization.view?.revision, 'k1');
    expect(organization.view?.stale, isTrue);
    expect(organization.readAt, DateTime.utc(2026, 11, 11, 5, 33));
    source.held!.complete();
    await reading;
    expect(organization.view?.stale, isFalse, reason: 'the checked state replaces the kept one');
  });

  // Harm: an older kept state replaces a checked one, and passes for the organization as it stands.
  test('a kept state never replaces a checked one already shown', () async {
    final source = _KeptFirst(organizationFor('pat'));
    final organization = Organization(source);
    addTearDown(organization.dispose);
    await organization.refresh();
    final checked = organization.view;
    source
      ..held = Completer<void>()
      ..kept = _kept('k2');
    final reading = organization.refresh();
    await pumpEventQueue();
    expect(organization.view, same(checked));
    source.held!.complete();
    await reading;
  });
}
