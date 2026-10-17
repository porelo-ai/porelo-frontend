import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/fleet_model.dart';
import '../app/machines.dart';
import '../app/commands.dart';
import 'command_menu.dart';
import 'machine_view.dart';
import 'tokens.dart';

/// Every project on every machine: how work runs, set up rarely.
///
/// A project on several machines is one line per machine, since each machine follows it on its
/// own and is acted on there. Work in no project is a project too, every machine's default, as
/// "Without a project". Choosing one opens it on its machine, with its tools; its work is under
/// *Work*.
class ProjectsPage extends StatelessWidget {
  /// Constructor taking the machines and what choosing does.
  const ProjectsPage({
    required this.machines,
    required this.muted,
    required this.onProject,
    required this.menuFor,
    required this.onFromARepository,
    required this.onFollow,
    this.highlight,
    this.onShown,
    super.key,
  });

  /// Every machine watched.
  final Machines machines;

  /// The projects nothing is notified about.
  final Set<String> muted;

  /// Opens a project on its machine.
  final void Function(Machine machine, String project) onProject;

  /// What a project can be told to do, on its own machine: its menu, on its row (walk 9).
  final List<Command> Function(Machine machine, ProjectOnScreen project) menuFor;

  /// Sets up a project from a repository the person has; null where the machine does not answer.
  final VoidCallback? onFromARepository;

  /// Follows a repository by its address, wherever it is; null where the machine does not answer.
  final VoidCallback? onFollow;

  /// The command the finder went to, marked where it lives.
  final String? highlight;

  /// Called once the marked command was shown.
  final VoidCallback? onShown;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rows = <({Machine machine, ProjectOnScreen project})>[
      // Default is not listed (walk 10): its work is under Work, and a repository is put
      // into it from its card on the forge's page.
      for (final machine in machines.all)
        for (final project in machines.of(machine).projects)
          if (project.name != defaultProject) (machine: machine, project: project),
    ]..sort((a, b) {
        // Work without a project first, as every machine's own.
        final aDefault = a.project.name == defaultProject;
        final bDefault = b.project.name == defaultProject;
        if (aDefault != bDefault) return aDefault ? -1 : 1;
        final byName = a.project.label.toLowerCase().compareTo(b.project.label.toLowerCase());
        return byName != 0 ? byName : a.machine.name.compareTo(b.machine.name);
      });
    return ListView(
      key: const Key('projects-page'),
      padding: const EdgeInsets.all(Space.normal),
      children: <Widget>[
        Wrap(
          spacing: Space.normal,
          runSpacing: Space.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text('Projects', style: text.headlineSmall),
            Highlight(
              active: highlight == 'project.fromRepository',
              child: FilledButton.icon(
                key: const Key('from-a-repository'),
                onPressed: onFromARepository,
                icon: const Icon(Icons.cloud_download_outlined, size: Sizes.rowIcon),
                label: const Text('Set up a project from a repository'),
              ),
            ),
            Highlight(
              active: highlight == 'project.follow',
              child: Tooltip(
                message: onFollow == null ? 'Not answering, so nothing can be followed there' : '',
                child: OutlinedButton.icon(
                  key: const Key('follow-a-repository'),
                  onPressed: onFollow,
                  autofocus: highlight == 'project.follow',
                  icon: const Icon(Icons.add_link, size: Sizes.rowIcon),
                  label: const Text('Follow a project by its address'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.tight),
        Text('How work runs: its repositories, who reviews what it pushes, whom it may talk to. Its work is '
            'under Work.', style: text.bodySmall),
        const SizedBox(height: Space.normal),
        if (rows.isEmpty) const Text('No project yet.', key: Key('projects-none')),
        // Each project once, however many machines it is on: Projects is the view of what projects
        // there are, Default among them, and where each lies is said under it (walk 9).
        for (final name in <String>{for (final row in rows) row.project.name})
          _row(context, <({Machine machine, ProjectOnScreen project})>[
            for (final row in rows)
              if (row.project.name == name) row,
          ]),
      ],
    );
  }

  Widget _row(BuildContext context, List<({Machine machine, ProjectOnScreen project})> on) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // The machine it is opened and acted on: the one acted on already, where it is there.
    final chosen = on.where((each) => each.machine == machines.current).firstOrNull ?? on.first;
    final machine = chosen.machine;
    final project = chosen.project;
    final selected = machine == machines.current && machines.of(machine).selectedProject?.name == project.name;
    final running = on.fold<int>(0, (sum, each) => sum + each.project.running);
    final work = on.fold<int>(0, (sum, each) => sum + each.project.howMuchWork);
    final label = project.name == defaultProject ? 'Default' : project.label;
    final entry = Card(
      key: ValueKey<String>('projects-row ${project.name}'),
      child: ListTile(
        key: ValueKey<String>('project ${project.name}'),
        selected: selected,
        leading: Icon(running > 0 ? Icons.folder : Icons.folder_outlined),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'on ${on.map((each) => each.machine.name).join(', ')}  ·  $running running of $work',
          key: const Key('projects-row-machines'),
          style: text.bodySmall,
        ),
        trailing: Wrap(
          spacing: Space.tight,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (muted.contains(project.name))
              Tooltip(
                message: 'Nothing about this project will be notified.',
                child: Icon(Icons.notifications_off_outlined, size: Sizes.mark, color: scheme.outline),
              ),
            // Waiting for review is what makes a project need a person, so it is a number here.
            if (on.any((each) => each.project.project.pending > 0))
              Tooltip(
                message: 'Pushes are waiting at the gate, and will not leave their machine until somebody '
                    'approves them.',
                child: Chip(
                  avatar: Icon(Icons.outbox_outlined, size: Sizes.mark, color: scheme.onTertiaryContainer),
                  label: Text('${on.fold<int>(0, (sum, each) => sum + each.project.project.pending)}'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  backgroundColor: scheme.tertiaryContainer,
                ),
              ),
            if (!project.project.prepared && project.name != defaultProject)
              Tooltip(
                message: 'Its environment is not prepared: a task started here would have to build an image first.',
                child: Icon(Icons.construction_outlined,
                    key: const Key('project-unprepared'), size: Sizes.mark, color: scheme.tertiary),
              ),
            // Prepared and up to date are different questions.
            if (project.project.environmentIsStale)
              Tooltip(
                message: 'Its environment was built before the project file changed.',
                child: Icon(Icons.update_disabled, key: const Key('project-stale'), size: Sizes.mark, color: scheme.error),
              ),
            // Said wherever the project is: nothing checks what this machine is handed for it.
            if (project.project.following?.unverified ?? false)
              Tooltip(
                message: 'Followed unverified: anybody who can push to its repository decides what this machine runs.',
                child: Icon(Icons.gpp_maybe_outlined,
                    key: const Key('project-unverified'), size: Sizes.mark, color: scheme.error),
              ),
            if (!project.canBeActedOn)
              Tooltip(
                message: 'This machine does not follow it, so nothing can act on it. Following its repository makes '
                    'it a project here.',
                child: Icon(Icons.link_off, size: Sizes.mark, color: scheme.outline),
              ),
            if (menuFor(machine, project) case final commands when commands.isNotEmpty)
              CommandMenu(
                key: ValueKey<String>('projects-menu ${machine.name}/${project.name}'),
                commands: commands,
                tooltip: 'What can be done with ${project.label}',
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => onProject(machine, project.name),
      ),
    );
    return selected ? KeyedSubtree(key: const Key('selected-row'), child: entry) : entry;
  }
}
