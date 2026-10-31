import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/fleet_model.dart';
import '../app/machines.dart';
import '../app/commands.dart';
import '../app/registry_pages.dart';
import 'command_menu.dart';
import 'expandable_list_row.dart';
import 'filtered_list_section.dart';
import 'machine_view.dart';
import 'tokens.dart';

/// Every project and admission on its own machine, including each permanent default.
class ProjectsPage extends StatelessWidget {
  /// Creates the list without merging equal project names across machines.
  const ProjectsPage({
    required this.machines,
    required this.muted,
    required this.onProject,
    required this.menuFor,
    required this.onFromARepository,
    required this.onFollow,
    this.registry,
    this.onAdmission,
    this.menuForAdmission,
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

  /// Opens repository setup when a machine can answer.
  final VoidCallback? onFromARepository;

  /// Opens following a project by its address.
  final VoidCallback? onFollow;

  /// The verified registry decisions and separate host confirmations.
  final RegistryPages? registry;

  /// Opens an admission with its complete registry identity.
  final void Function(RegistryPageItem item)? onAdmission;

  /// Creates commands with the row's exact registry scope.
  final List<Command> Function(Machine machine, ProjectOnScreen project, RegistryPageItem? admission)? menuForAdmission;

  /// The command the finder is revealing.
  final String? highlight;

  /// Reports that the finder destination is visible.
  final VoidCallback? onShown;

  @override
  Widget build(BuildContext context) {
    final rows = <RegistryProjectRow>[
      for (final machine in registryMachines(machines, registry))
        ...scopedProjectRows(machines, machine, registry: registry),
    ];
    return ListView(
      key: const Key('projects-page'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        if (registry?.problem case final problem?) Text(problem),
        FilteredListSection(
          storageId: 'projects',
          title: 'Projects',
          actions: [
            Highlight(
              active: highlight == 'project.fromRepository',
              child: FilledButton.icon(
                key: const Key('from-a-repository'),
                onPressed: onFromARepository,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Set up a project from a repository'),
              ),
            ),
            Highlight(
              active: highlight == 'project.follow',
              child: OutlinedButton.icon(
                key: const Key('follow-a-repository'),
                onPressed: onFollow,
                icon: const Icon(Icons.add_link),
                label: const Text('Follow a project by its address'),
              ),
            ),
          ],
          rows: [
            for (final row in rows)
              (
                words:
                    '${row.project.name == defaultProject ? 'Without a project' : row.project.label} ${row.machine.name} ${row.admission?.role ?? ''} ${row.admission?.target.registry ?? ''}',
                child: projectListRow(
                  machine: row.machine,
                  project: row.project,
                  machines: machines,
                  registry: registry,
                  admission: row.admission,
                  muted: muted.contains(row.project.name),
                  onOpen: () {
                    if (row.admission != null && onAdmission != null) {
                      onAdmission!(row.admission!);
                    } else {
                      onProject(row.machine, row.project.name);
                    }
                  },
                  commands:
                      menuForAdmission?.call(row.machine, row.project, row.admission) ??
                      menuFor(row.machine, row.project),
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
  RegistryPages? registry,
  RegistryPageItem? admission,
  bool muted = false,
}) {
  final isDefault = project.name == defaultProject;
  admission ??= registry?.project(machine, project.name);
  final identity = projectRowIdentity(machine, project.name, admission);
  final watched = machines.all.contains(machine);
  final connected = watched && machines.of(machine).reachability == Reachability.connected;
  final tunnel = watched ? machines.tunnels.of(machine) : null;
  final selected = watched && machines.current == machine && machines.of(machine).selectedProject?.name == project.name;

  final menu = isDefault ? commands.where((command) => command.id == 'work.start').toList() : commands;
  return ItemListRow(
    key: ValueKey('projects-row $identity'),
    bodyKey: ValueKey('project $identity'),
    selected: selected,
    title: isDefault ? 'Without a project' : project.label,
    subtitle: [
      'on ${machine.name}',
      if (isDefault) 'always there',
      if (admission != null) ...[
        admission.target.registry,
        admission.role,
        admission.state,
        registryStateWords(registry!, admission),
      ],
      if (!connected) 'Not connected; last known state',
      if (tunnel != null) tunnel.words else if (machine.needsATunnel) 'Tunnel not reached' else 'No SSH tunnel needed',
      ?tunnel?.problem,
      if (project.project.pending > 0) '${project.project.pending} waiting for review',
      if (!isDefault && !project.project.prepared) 'Environment not prepared',
      if (project.project.environmentIsStale) 'Environment older than its project file',
      if (!isDefault && !project.canBeActedOn) 'Not followed on this machine',
      if (project.project.following?.unverified ?? false) 'Followed unverified',
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

/// Words that keep the registry's decision separate from host confirmation.
String registryStateWords(RegistryPages registry, RegistryPageItem item) {
  final applied = registry.applied(item.target);
  return [
    'registry ${registry.decidedRevision(item.target)}',
    applied == null ? 'host state unknown' : 'host ${applied.revision}',
    if (registry.pending(item.target)) 'change not confirmed on the host',
    ?registry.failure(item.target),
  ].join(' · ');
}
