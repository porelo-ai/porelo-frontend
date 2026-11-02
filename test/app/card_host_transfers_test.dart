// Harm guarded: the central push and pull, built for a project on a card host, were never offered in its menu, so
// the approved main could not be pushed from the interface at all.
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart' show defaultProject;
import 'package:porelo_frontend/src/app/commands.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_transfers.dart';
import 'package:porelo_host/porelo_host.dart';

import '../support/transfer_selection.dart';

class _NoTerminal implements CentralTransferSource {
  @override
  Future<TransferResult> run(
    TransferSelection selection,
    ProjectTransfer direction, {
    required void Function() onSubmitted,
    void Function(String)? onLine,
  }) => throw const RemoteNotStarted();
}

void main() {
  late ProjectTransfers transfers;
  setUp(() => transfers = ProjectTransfers(source: _NoTerminal()));
  tearDown(() => transfers.dispose());
  final card = selection().machine;

  List<Command> commands({
    Machine? on,
    String project = 'example',
    bool followed = true,
    bool hasSecrets = true,
    List<ProjectTransfer>? started,
  }) => cardHostTransferCommands(
    transfers: transfers,
    machine: on ?? card,
    project: project,
    followed: followed,
    hasSecrets: hasSecrets,
    start: (direction) => started?.add(direction),
  );

  test('a project followed on a card host offers the push and the pull, each starting its own direction', () {
    final started = <ProjectTransfer>[];
    final offered = commands(started: started);
    expect(offered.map((command) => command.label), ['Push the approved main…', 'Take the central state…']);
    expect(offered.map((command) => command.home).toSet(), {Home.projectMenu}, reason: 'both stand in the menu');
    expect(offered.map((command) => command.unavailable), [null, null], reason: 'nothing stands in the way');
    for (final command in offered) {
      command.run();
    }
    expect(started, [ProjectTransfer.push, ProjectTransfer.pull], reason: 'each starts its own direction');
  });

  test('without a secrets file both are offered but refused with what to do', () {
    final offered = commands(hasSecrets: false);
    expect(offered, hasLength(2));
    expect(offered.map((command) => command.unavailable), everyElement(contains('secrets file')));
  });

  test(
    'a project the host does not follow is refused, and no machine without a card nor the default project offers them',
    () {
      expect(commands(followed: false).map((command) => command.unavailable), everyElement(isNotNull));
      expect(
        commands(
          on: const Machine(name: 'local', socketPath: '/run/porelo.sock'),
        ),
        isEmpty,
      );
      expect(commands(project: defaultProject), isEmpty, reason: 'Without a project is no project to transfer');
    },
  );
}
