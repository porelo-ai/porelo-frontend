import 'package:flutter/material.dart';

import '../app/fleet_model.dart';
import '../app/machines.dart';
import '../app/commands.dart';
import 'command_menu.dart';
import 'machine_switcher.dart';
import 'tokens.dart';

/// Every machine watched, as a list: where work runs, set up rarely (walk 9). One row
/// per machine says how it stands; its details are a page of their own, and its projects and work
/// are under *Projects* and *Work*, never here.
class MachinesPage extends StatelessWidget {
  /// Constructor taking the machines and what choosing does.
  const MachinesPage({
    required this.machines,
    required this.onAdd,
    required this.onDetails,
    required this.onForget,
    this.hostCommands,
    super.key,
  });

  /// Every machine watched.
  final Machines machines;

  /// Adds a machine: this computer, or one reached over ssh.
  final VoidCallback onAdd;

  /// Opens a machine's details.
  final void Function(Machine machine) onDetails;

  /// Takes a machine off the list, after asking; never the last one.
  final void Function(Machine machine) onForget;

  /// The host's commands, including their reasons when unavailable.
  final List<Command> Function(Machine machine)? hostCommands;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      // The key the tree carried: what lists the machines, wherever a step looks for them.
      key: const Key('machine-tree'),
      padding: const EdgeInsets.all(Space.normal),
      children: <Widget>[
        Wrap(
          spacing: Space.normal,
          runSpacing: Space.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text('Machines', style: text.headlineSmall),
            FilledButton.icon(
              key: const Key('machines-add'),
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: Sizes.rowIcon),
              label: const Text('Add a machine'),
            ),
          ],
        ),
        const SizedBox(height: Space.tight),
        Text('Where work runs. Its projects are under Projects, and its work under Work.', style: text.bodySmall),
        const SizedBox(height: Space.normal),
        for (final machine in machines.all) _row(context, machine),
      ],
    );
  }

  Widget _row(BuildContext context, Machine machine) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final fleet = machines.of(machine);
    final info = fleet.info;
    final running = fleet.tasks.where((task) => task.running).length;
    final refused = machines.tunnels.of(machine)?.problem;
    final answering = fleet.reachability == Reachability.connected && refused == null;
    // This computer itself is never taken off the list (walk 9): it is where the window
    // runs, whatever else is watched.
    final local = Machine.local();
    final thisComputer = !machine.needsATunnel && machine.name == local.name && machine.socketPath == local.socketPath;
    final actions = <Command>[
      ...?hostCommands?.call(machine),
      forgetMachineCommand(
        label: 'Remove from this list',
        forget: () => onForget(machine),
        canForget: machines.all.length > 1,
      ),
    ];
    return Card(
      key: ValueKey<String>('machines-row ${machine.name}'),
      child: ListTile(
        key: ValueKey<String>('tree-machine ${machine.name}'),
        leading: Badge(
          key: ValueKey<String>('waiting-count ${machine.name}'),
          isLabelVisible: fleet.clearance.count > 0,
          label: Text('${fleet.clearance.count}'),
          child: ReachIcon(name: machine.name, fleet: fleet, tunnel: machines.tunnels.of(machine)),
        ),
        title: Text(
          machine.name,
          key: ValueKey<String>('rail-machine ${machine.name}'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              <String>[
                machine.where,
                if (info != null) '${info.product} ${info.version}',
                if (answering) running == 1 ? '1 running' : '$running running' else 'not answering',
              ].join('  ·  '),
              style: text.bodySmall,
            ),
            if (refused != null)
              Text(
                refused,
                key: ValueKey<String>('machine-refused ${machine.name}'),
                style: text.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!thisComputer)
              PopupMenuButton<String>(
                key: ValueKey<String>('machines-menu ${machine.name}'),
                tooltip: 'What can be done with ${machine.name}',
                onSelected: (id) {
                  final command = actions.firstWhere((command) => command.id == id);
                  if (command.available) command.run();
                },
                itemBuilder: (_) => commandMenuEntries(actions),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => onDetails(machine),
      ),
    );
  }
}
