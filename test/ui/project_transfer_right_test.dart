import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';
import '../support/transfer_selection.dart';

const _transfers = {'project.pushApprovedMain', 'project.takeCentralState'};

ListedProject _demo({String? role = 'developer', bool locked = false}) =>
    ListedProject(name: 'demo', source: 'organization', role: role, locked: locked, host: 'alpha');

/// The project's page on a card host, the person's secrets file chosen, so only the role can stand in the way.
Future<Machine> _openOnCardHost(WidgetTester tester, OrganizationSource? organization) async {
  await World.startBackend(World.work);
  World.backend.theProjectsItHas = [
    Project.from({'name': 'demo', 'file': '/srv/demo/project.yml'}),
  ];
  await World.startApp(tester, organizationSource: organization);
  await World.settings.rememberSecretsFile('/home/somebody/secrets.kdbx');
  final card = selection(project: 'demo').machine;
  await World.machines.add(card);
  await World.settle(tester);
  World.machines.select(card);
  World.machines.of(card).selectProject('demo');
  World.shell.openProject(card, 'demo');
  await World.settle(tester);
  return card;
}

Iterable<Command> _shown(WidgetTester tester) => tester
    .widget<CommandMenu>(find.byKey(const Key('project-menu')))
    .commands
    .where((command) => _transfers.contains(command.id));

void main() {
  // Harm: work leaves the host for the central forge at the hand of a person with no right to move it.
  for (final (name, listed) in <(String, List<ListedProject>)>[
    ('no such project', const []),
    ('no role', [_demo(role: null)]),
    ('a locked role', [_demo(role: 'admin', locked: true)]),
  ]) {
    testWidgets('a person with $name is not offered the push or the pull', (tester) async {
      final organization = FixtureOrganization(organizationFor('mia'))..listed = listed;
      await _openOnCardHost(tester, organization);
      expect(_shown(tester).map((command) => command.id).toSet(), _transfers, reason: 'listed, with the reason');
      expect(_shown(tester).map((command) => command.unavailable), everyElement(isNotNull));
      for (final command in _shown(tester).toList()) {
        command.run();
      }
      await World.settle(tester);
      expect(World.terminals, isEmpty, reason: 'no terminal opens');
    });
  }

  // Harm: while the store cannot say who holds a role, everyone is taken to hold one.
  testWidgets('a role that cannot be read offers neither, and says the refusal', (tester) async {
    final organization = FixtureOrganization(organizationFor('mia'))
      ..listed = [_demo()]
      ..refuseReads = const OrganizationRefused('The store cannot be asked.');
    await _openOnCardHost(tester, organization);
    expect(_shown(tester).map((command) => command.unavailable), everyElement(contains('The store cannot be asked.')));
  });

  testWidgets('where this computer reads no organization, neither is offered', (tester) async {
    await _openOnCardHost(tester, null);
    expect(_shown(tester).map((command) => command.unavailable), everyElement(isNotNull));
  });

  testWidgets('a person with a role, not locked, is offered both', (tester) async {
    await _openOnCardHost(tester, FixtureOrganization(organizationFor('mia'))..listed = [_demo()]);
    expect(_shown(tester).map((command) => command.unavailable), [null, null]);
  });

  // Harm: a person locked after the menu was read pushes on the strength of that earlier answer.
  testWidgets('a lock since the menu was read stops the run when it is chosen', (tester) async {
    final organization = FixtureOrganization(organizationFor('mia'))..listed = [_demo()];
    await _openOnCardHost(tester, organization);
    final push = _shown(tester).first;
    expect(push.unavailable, isNull);
    organization.listed = [_demo(locked: true)];
    push.run();
    await World.settle(tester);
    expect(World.terminals, isEmpty, reason: 'no terminal opens');
    expect(_shown(tester).map((command) => command.unavailable), everyElement(isNotNull));
  });

  // The other side of the guard above: a run that is allowed reaches its terminal, so its silence means something.
  // Linux only: what it reaches is a Bash script around /usr/bin/ssh, with a Linux path to the host's config.
  testWidgets('a person still holding the role reaches the terminal', (tester) async {
    await _openOnCardHost(tester, FixtureOrganization(organizationFor('mia'))..listed = [_demo()]);
    _shown(tester).first.run();
    await World.settle(tester);
    expect(World.terminals, hasLength(1));
  }, tags: 'linux');
}
