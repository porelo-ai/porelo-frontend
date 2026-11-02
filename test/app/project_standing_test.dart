import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/project_standing.dart';

import '../support/organization_fixtures.dart';

ListedProject _demo({String? role = 'developer', bool locked = false}) =>
    ListedProject(name: 'demo', source: 'organization', role: role, locked: locked, host: 'build');

void main() {
  late FixtureOrganization organization;
  late ProjectStandings standings;

  setUp(() {
    organization = FixtureOrganization(organizationFor('mia'));
    standings = ProjectStandings(organization);
  });
  tearDown(() => standings.dispose());

  test('a role in the project, not locked, gives the right', () async {
    organization.listed = [_demo()];
    await standings.read();
    expect(standings.whyNoRight('demo'), isNull);
  });

  // Harm: a person locked since the store was last reached moves work on a list the store could not vouch for.
  test('a list the store could not vouch for gives no right', () async {
    organization.listed = [
      const ListedProject(name: 'demo', source: 'organization', role: 'developer', host: 'build', stale: true),
    ];
    await standings.read();
    expect(standings.whyNoRight('demo'), isNotNull);
  });

  // Harm: work leaves the host for the central forge at the hand of a person the project has locked out.
  test('a locked person has no right, whatever their role', () async {
    organization.listed = [_demo(role: 'admin', locked: true)];
    await standings.read();
    expect(standings.whyNoRight('demo'), isNotNull);
  });

  // Harm: work leaves at the hand of a person who is in no such project, or in one registered here alone.
  test('a project not listed, or listed with no role, gives no right', () async {
    organization.listed = [_demo(role: null), const ListedProject(name: 'mine', source: 'local')];
    await standings.read();
    expect(standings.whyNoRight('demo'), isNotNull);
    expect(standings.whyNoRight('mine'), isNotNull);
    expect(standings.whyNoRight('other'), isNotNull);
  });

  // Harm: a person locked out while the store cannot be asked goes on moving work on the last good answer.
  test('a read that fails takes the right away and says the refusal', () async {
    organization.listed = [_demo()];
    await standings.read();
    expect(standings.whyNoRight('demo'), isNull);
    organization.refuseReads = const OrganizationRefused('The store cannot be asked.');
    await standings.read();
    expect(standings.whyNoRight('demo'), contains('The store cannot be asked.'));
    organization.refuseReads = null;
    await standings.read();
    expect(standings.whyNoRight('demo'), isNull, reason: 'a later answer gives it back');
  });

  test('nothing gives the right before the first answer, nor with no organization', () {
    expect(standings.whyNoRight('demo'), isNotNull);
    final none = ProjectStandings(null);
    addTearDown(none.dispose);
    expect(none.whyNoRight('demo'), isNotNull);
  });
}
