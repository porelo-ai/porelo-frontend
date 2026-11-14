import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/forge.dart';
import 'package:porelo_frontend/src/app/forge_connection.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/step/i_open_the_command_finder.dart';
import '../features/step/the_command_is_unavailable_because.dart';
import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

/// A project's forge is found by the address `project show` answers, read when needed.
void main() {
  const command = 'Its machines and keys at its forge';

  /// An organization counting which projects are shown.
  FixtureOrganization organizationWith(String? address, {List<String>? shown}) =>
      _Showing(shown ?? [])..projects = {'checkout': ProjectView(name: 'checkout', revision: 'r1', address: address)};

  Future<void> selected(WidgetTester tester, FixtureOrganization organization) async {
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: organization);
    World.fleet.selectProject('checkout');
    await World.settle(tester);
    await iOpenTheCommandFinder(tester);
  }

  // Harm: the person is sent to a forge that is not set up here, with nothing saying why it does not open.
  testWidgets('an address on a forge not set up here says so', (tester) async {
    await selected(tester, organizationWith('git@gitlab.example.org:acme/api.git'));
    await theCommandIsUnavailableBecause(tester, command, 'gitlab.example.org, which is not set up here');
  });

  // Harm: a project with no address matches a forge by chance, or the menu says nothing of why it cannot.
  testWidgets('no address filed matches no forge, and says so', (tester) async {
    await selected(tester, organizationWith(null));
    await theCommandIsUnavailableBecause(tester, command, 'it has no address yet');
  });

  // Harm: an unreadable address reads as there being none, and the reason is lost.
  testWidgets('an address that cannot be read says Porelo’s reason', (tester) async {
    await selected(
      tester,
      organizationWith('git@forge.example.org:acme/api.git')
        ..refuseReads = const OrganizationRefused('The store could not be reached.'),
    );
    await theCommandIsUnavailableBecause(tester, command, 'The store could not be reached.');
  });

  // Harm: a list of projects starts a `project show`, each fetching the store, for every row on every frame.
  testWidgets('a list of projects reads no address for its rows', (tester) async {
    final shown = <String>[];
    await World.startBackend(World.work);
    await World.startApp(tester, organizationSource: organizationWith(null, shown: shown));
    World.fleet.selectProject(null);
    World.shell.goTo(Section.projects);
    await World.settle(tester);
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(shown, isEmpty);
  });

  // Harm: the forge pages say no machine has the project, or open none, for a project known only by its address.
  testWidgets('a forge page finds a project by its address, once', (tester) async {
    final shown = <String>[];
    await World.startBackend([]);
    World.backend.theProjectsItHas = [
      Project.from({'name': 'checkout', 'file': '/srv/checkout/project.yml'}),
    ];
    await World.startApp(
      tester,
      organizationSource: organizationWith('git@forge.example.org:acme/api.git', shown: shown),
    );
    World.forges.current = const ForgeEntry(
      id: 'central',
      kind: 'github',
      name: 'Central',
      address: 'forge.example.org',
    );
    World.forges.account = const ForgeAccount('alice');
    World.forges.repositories = [
      const ForgeRepository(
        fullName: 'acme/api',
        sshUrl: 'git@forge.example.org:acme/api.git',
        httpsUrl: 'https://forge.example.org/acme/api.git',
        defaultBranch: 'main',
        admin: true,
        push: true,
        private: true,
      ),
    ];
    World.shell.goTo(Section.forge);
    await World.settle(tester);
    await World.tapInView(tester, 'forge-repository-menu acme/api');
    expect(find.byKey(const Key('repository.project')), findsOneWidget);
    expect(shown, ['checkout'], reason: 'one read, however many frames drew the page');
  });
}

class _Showing extends FixtureOrganization {
  _Showing(this.shown) : super(organizationFor('mia'));

  final List<String> shown;

  @override
  Future<ProjectView> readProject(String project) {
    shown.add(project);
    return super.readProject(project);
  }
}
