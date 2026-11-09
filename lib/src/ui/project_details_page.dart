import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/commands.dart';
import '../app/fleet_model.dart';
import '../app/machines.dart';
import 'command_menu.dart';
import 'expandable_list_row.dart';
import 'filtered_list_section.dart';
import 'tokens.dart';
import 'page_explanation.dart';

/// One project on one machine, without transferring selection on matching names.
class ProjectDetailsPage extends StatelessWidget {
  /// Creates the project's scoped information and lists.
  const ProjectDetailsPage({
    required this.machine,
    required this.project,
    required this.commands,
    required this.onBack,
    required this.onMachine,
    this.machineState = 'not read',
    this.highlight,
    this.onShown,
    this.details,
    this.jobs = const [],
    this.machinePath,
    this.onGeneralPage,
    this.machineNote,
    super.key,
  });

  /// The way back to the machine it was opened from, where it was opened from one: the page is then what of the
  /// project is on that machine, and lists that machine no second time.
  final List<LeafPathStep>? machinePath;

  /// Opens the project's own page, for all of it, where the page was opened from a machine.
  final VoidCallback? onGeneralPage;

  /// Why some of what the machine holds of it is not read, said once above its repositories.
  final String? machineNote;

  /// The latest observed connection state, or not read before an answer.
  final String machineState;

  /// The machine this item belongs to.
  final Machine machine;

  /// The project on this specific machine.
  final ProjectOnScreen project;

  /// The commands scoped to this item.
  final List<Command> commands;

  /// Returns to the containing list.
  final VoidCallback onBack;

  /// Opens the machine belonging to this item.
  final VoidCallback onMachine;

  /// The command the finder is revealing.
  final String? highlight;

  /// Reports that the finder destination is visible.
  final VoidCallback? onShown;

  /// The additional information belonging to this item.
  final Widget? details;

  /// The saved jobs available on this project.
  final List<FilteredRow> jobs;

  @override
  Widget build(BuildContext context) {
    final isDefault = project.name == defaultProject;
    final fromMachine = machinePath != null;
    return ListView(
      key: ValueKey('project-details ${machine.name}/${project.name}'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        PageHead(
          title: isDefault ? 'Default' : project.label,
          titleInAppBar: true,
          path: machinePath ?? [(label: 'My projects', go: onBack)],
          // Opened from the machine, what the page says of it is only as good as the machine's answer.
          titleChip: fromMachine ? StateChip(machineState) : null,
          subtitle: 'on ${machine.name}',
          action: CommandMenu(
            key: const Key('project-menu'),
            commands: commands,
            tooltip: 'What can be done with ${project.label} on ${machine.name}',
            highlight: highlight,
            onShown: onShown,
          ),
        ),
        // The room in one press, by a name that says it is the room: the menu's entry names messages first.
        if (commands.where((each) => each.id == 'project.messages' && each.visible).firstOrNull case final room?)
          Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: room.unavailable ?? '${room.label} of ${project.label}',
              child: TextButton.icon(
                key: const Key('project-room'),
                onPressed: room.available ? room.run : null,
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Open the project’s room'),
              ),
            ),
          ),
        if (onGeneralPage case final open?)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('project-general-page'),
              onPressed: open,
              child: Text("${isDefault ? 'Default' : project.label}'s own page, for all of it"),
            ),
          ),
        if (machineNote case final note?)
          Text(note, key: const Key('project-machine-note'), style: Theme.of(context).textTheme.bodySmall),
        ?details,
        if (!fromMachine)
          FilteredListSection(
            title: 'Machines',
            leaf: true,
            subtitle: '1 machine',
            storageId: 'project-machines ${machine.name}/${project.name}',
            collapsible: true,
            rows: [
              (
                words: machine.name,
                child: ItemListRow(
                  title: machine.name,
                  state: machineState,
                  subtitle: machine.where,
                  leading: const Icon(Icons.dns_outlined),
                  onOpen: onMachine,
                  menu: CommandMenu(
                    tooltip: 'Machine for ${project.label}',
                    commands: [listOpenCommand(label: 'Open the machine', home: Home.machineRow, open: onMachine)],
                  ),
                ),
              ),
            ],
          ),
        if (jobs.isNotEmpty)
          FilteredListSection(
            title: 'Saved jobs',
            leaf: true,
            subtitle: counted(jobs.length, 'saved job', 'saved jobs'),
            storageId: 'project-jobs ${machine.name}/${project.name}',
            collapsible: true,
            reveal: highlight?.startsWith('template.start/${project.name}/') == true ? highlight : null,
            rows: jobs,
          ),
      ],
    );
  }
}
