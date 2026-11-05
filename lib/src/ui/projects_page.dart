import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/fleet_model.dart';
import '../app/machines.dart';
import '../app/commands.dart';
import 'command_menu.dart';
import 'expandable_list_row.dart';
import 'filtered_list_section.dart';
import 'tokens.dart';

/// Every project on its own machine, including each permanent default.
class ProjectsPage extends StatelessWidget {
  /// Creates the list without merging equal project names across machines.
  const ProjectsPage({
    required this.machines,
    required this.muted,
    required this.onProject,
    required this.menuFor,
    this.highlight,
    this.onShown,
    super.key,
  });

  /// The watched machines and their daemon state.
  final Machines machines;

  /// The project names with notifications muted.
  final Set<String> muted;

  /// Opens a project on its exact machine.
  final void Function(Machine machine, String project) onProject;

  /// Creates commands for one project on one machine.
  final List<Command> Function(Machine machine, ProjectOnScreen project) menuFor;

  /// The command the finder is revealing.
  final String? highlight;

  /// Reports that the finder destination is visible.
  final VoidCallback? onShown;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final machine in listedMachines(machines))
        for (final project in projectsOnMachine(machines, machine)) (machine: machine, project: project),
    ];
    return ListView(
      key: const Key('projects-page'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        FilteredListSection(
          storageId: 'projects',
          title: 'My projects',
          rows: [
            for (final row in rows)
              (
                words: '${row.project.name == defaultProject ? 'Default' : row.project.label} ${row.machine.name}',
                child: projectListRow(
                  machine: row.machine,
                  project: row.project,
                  machines: machines,
                  muted: muted.contains(row.project.name),
                  onOpen: () => onProject(row.machine, row.project.name),
                  commands: menuFor(row.machine, row.project),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Creates the same project row in the top list and a machine's Projects section.
Widget projectListRow({
  required Machine machine,
  required ProjectOnScreen project,
  required Machines machines,
  required VoidCallback onOpen,
  required List<Command> commands,
  bool muted = false,
}) {
  final isDefault = project.name == defaultProject;
  final identity = '${machine.name}/${project.name}';
  final watched = machines.all.contains(machine);
  final connected = watched && machines.of(machine).reachability == Reachability.connected;
  final tunnel = watched ? machines.tunnels.of(machine) : null;
  final selected = watched && machines.current == machine && machines.of(machine).selectedProject?.name == project.name;

  final menu = isDefault ? commands.where((command) => command.id == 'work.start').toList() : commands;
  return ItemListRow(
    key: ValueKey('projects-row $identity'),
    bodyKey: ValueKey('project $identity'),
    selected: selected,
    title: isDefault ? 'Default' : project.label,
    subtitle: [
      'on ${machine.name}',
      if (isDefault) 'always there',
      if (!connected) 'Not connected; last known state',
      if (tunnel != null) ?tunnel.words else if (machine.needsATunnel) 'Tunnel not reached' else 'No SSH tunnel needed',
      if (tunnel?.problem != tunnel?.words) ?tunnel?.problem,
      if (project.project.pending > 0) '${project.project.pending} waiting for review',
      if (project.project.carried) 'Carried by this machine; starting work takes it here',
      if (!isDefault && !project.project.carried && !project.project.prepared) 'Environment not prepared',
      if (project.project.environmentIsStale) 'Environment older than its project file',
      if (!isDefault && !project.canBeActedOn && !project.project.carried) 'Not on this machine',
      if (muted) 'Notifications off',
    ].join(' · '),
    leading: Icon(selected ? Icons.folder : Icons.folder_outlined),
    onOpen: onOpen,
    menu: CommandMenu(
      key: ValueKey('projects-menu $identity'),
      commands: [
        listOpenCommand(label: isDefault ? 'Open' : 'Open the project', home: Home.projectRow, open: onOpen),
        ...menu,
      ],
      tooltip: 'What can be done with ${project.label} on ${machine.name}',
    ),
  );
}
