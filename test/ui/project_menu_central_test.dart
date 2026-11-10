import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/command_menu.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

void main() {
  // Harm: two ways to release the same work, one through a secrets file the window has to have the person unlock, the
  // other through the machine; the person cannot tell which one reached central, or uses the one that asks for more.
  testWidgets('the project menu on a host offers no push or pull of its own, only Bring it to central', (tester) async {
    await World.startBackend(World.work);
    World.backend.theProjectsItHas = [
      Project.from({'name': 'demo', 'file': '/srv/demo/project.yml'}),
    ];
    await World.startApp(
      tester,
      organizationSource: FixtureOrganization(organizationFor('mia'))
        ..listed = const [ListedProject(name: 'demo', source: 'organization', role: 'developer', host: 'alpha')],
    );
    // The secrets file the old push read the central token from: chosen, so nothing else kept it from the menu.
    await World.settings.rememberSecretsFile('/home/somebody/secrets.kdbx');
    final card = Machine.fromHostCard(
      HostCardSsh(
        name: 'alpha',
        address: 'alpha.example.org',
        sshPort: 22,
        hostKey: _key,
        login: 'alice',
        publicKey: _key,
        webPort: 18080,
        gitPort: 18081,
        matrixPort: 18082,
      ),
      socketPath: '/run/person/daemon.sock',
    );
    await World.machines.add(card);
    await World.settle(tester);
    World.machines.select(card);
    World.machines.of(card).selectProject('demo');
    World.shell.openProject(card, 'demo');
    await World.settle(tester);
    final menu = tester.widget<CommandMenu>(find.byKey(const Key('project-menu'))).commands;
    expect(menu.map((command) => command.id), contains('project.bringToCentral'));
    expect(
      menu.where(
        (command) =>
            {'project.pushApprovedMain', 'project.takeCentralState'}.contains(command.id) ||
            command.label.startsWith('Push the approved main') ||
            command.label.startsWith('Take the central state'),
      ),
      isEmpty,
    );
  });
}
