import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/main.dart';
import 'package:porelo_frontend/src/app/host_access.dart';
import 'package:porelo_frontend/src/app/roles.dart';

import '../support/organization_fixtures.dart';

void main() {
  HostAccess made() =>
      HostAccess(source: FixtureOrganization(organizationFor('hana')), identity: () => null, scratch: '/nowhere');

  // Harm: *Prepare a server…* gone for every host admin, or offered to a person whose role cannot use it.
  test('host access is composed for a host admin, and for nobody else', () {
    expect(hostAccessFor(Roles.fromArguments(['--roles', 'host-admin']), made), isNotNull);
    expect(hostAccessFor(const Roles(), made), isNull);
  });
}
