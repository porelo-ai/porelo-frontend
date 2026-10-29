import 'dart:async';

import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/fleet_model.dart';
import '../app/machines.dart';
import '../app/templates.dart';
import '../app/tunnel.dart';
import 'command_menu.dart';
import 'emergency_stop_view.dart';
import 'machine_switcher.dart';
import 'tokens.dart';

/// Marks where the finder went: an outline around it, and a key the way there can be followed by.
class Highlight extends StatefulWidget {
  /// Constructor taking whether it is marked and what is.
  const Highlight({required this.active, required this.child, super.key});

  /// Whether the finder went here.
  final bool active;

  /// What is marked.
  final Widget child;

  @override
  State<Highlight> createState() => _HighlightState();
}

class _HighlightState extends State<Highlight> {
  @override
  void initState() {
    super.initState();
    if (widget.active) _bringIntoView();
  }

  @override
  void didUpdateWidget(Highlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _bringIntoView();
  }

  /// Scrolled to once, when it is marked: what the finder went to is on screen, wherever it is on a
  /// long page (walk 9: a project's points pushed its start below the fold).
  void _bringIntoView() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      unawaited(Scrollable.ensureVisible(context, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd));
    }
  });

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return KeyedSubtree(
      key: const Key('highlighted'),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.tertiary, width: Sizes.highlightBorder),
          borderRadius: BorderRadius.circular(Radii.medium),
        ),
        child: widget.child,
      ),
    );
  }
}

/// The top of a machine: which one it is, how it is reached, its emergency stop and its menu.
///
/// The stop sits here rather than in the menu: somebody reaching for it has just realized
/// something is wrong, and a person in that minute does not go looking through menus.
class MachineTitle extends StatelessWidget {
  /// Constructor taking the machine and what it can be told to do.
  const MachineTitle({
    required this.machine,
    required this.fleet,
    required this.kind,
    required this.onStop,
    required this.menu,
    this.vault,
    this.tunnel,
    this.highlight,
    this.onShown,
    super.key,
  });

  /// The machine.
  final Machine machine;

  /// Its model.
  final FleetModel fleet;

  /// What kind of way in it is, and which node it shares, after its name.
  final String kind;

  /// Asks before stopping everything on it.
  final VoidCallback onStop;

  /// What the machine can be told to do.
  final List<Command> menu;

  /// The vault's button, beside the stop: whether this device can open it matters as
  /// much as being able to stop what runs.
  final Widget? vault;

  /// The forward this interface raised for it, or null.
  final Tunnel? tunnel;

  /// The command the finder went to.
  final String? highlight;

  /// Called once a menu opened on [highlight].
  final VoidCallback? onShown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = fleet.info;
    final where = <String>[machine.where, if (info != null) '${info.product} ${info.version}'].join('  ·  ');
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.normal, Space.small, Space.small, Space.small),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: <Widget>[
          ReachIcon(name: machine.name, fleet: fleet, tunnel: tunnel),
          const SizedBox(width: Space.small),
          Flexible(
            child: Text(
              machine.name,
              key: const Key('machine-title'),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: Space.normal),
          Expanded(
            child: Text(
              '$where$kind',
              key: const Key('machine-kind'),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          ?vault,
          Highlight(
            active: highlight == 'machine.panic',
            child: EmergencyStopButton(onPressed: fleet.reachability == Reachability.connected ? onStop : null),
          ),
          CommandMenu(
            key: const Key('machine-menu'),
            commands: menu,
            tooltip: 'What ${machine.name} can be told to do',
            highlight: highlight,
            onShown: onShown,
          ),
        ],
      ),
    );
  }
}

/// A visible action using the same command and refusal as its menu entry.
class CommandTile extends StatelessWidget {
  /// Constructor taking the command, its mark, and one line explaining what it does.
  const CommandTile({
    required this.command,
    required this.icon,
    required this.description,
    this.highlighted = false,
    this.danger = false,
    super.key,
  });

  /// The action, including its label and why it cannot run now.
  final Command command;

  /// The outlined mark above its label.
  final IconData icon;

  /// One line explaining what the action does.
  final String description;

  /// Whether the finder went here.
  final bool highlighted;

  /// Whether the action cannot be undone, such as giving a server back: its label and mark in the error colour.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    if (!command.visible) return const SizedBox.shrink();
    final starting = command.id == 'work.start';
    final scheme = Theme.of(context).colorScheme;
    Color foreground(Set<WidgetState> states) => states.contains(WidgetState.disabled)
        ? scheme.onSurface.withValues(alpha: ActionTiles.disabledInk)
        : danger
        ? scheme.error
        : scheme.primary;
    return Highlight(
      active: highlighted,
      child: Tooltip(
        message: command.unavailable ?? description,
        waitDuration: ActionTiles.tooltipDelay,
        constraints: const BoxConstraints(maxWidth: ActionTiles.tooltipWidth),
        padding: const EdgeInsets.all(Space.normal),
        verticalOffset: ActionTiles.tooltipOffset,
        child: SizedBox(
          width: ActionTiles.width,
          height: ActionTiles.height,
          child: ElevatedButton(
            key: starting ? const Key('start-work') : null,
            autofocus: highlighted,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.all(Space.wide)),
              alignment: Alignment.center,
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.medium))),
              side: const WidgetStatePropertyAll(BorderSide.none),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return scheme.surfaceContainer;
                if (states.contains(WidgetState.pressed)) {
                  return Color.alphaBlend(
                    scheme.primary.withValues(alpha: ActionTiles.pressedInk),
                    scheme.surfaceContainerLowest,
                  );
                }
                return scheme.surfaceContainerLowest;
              }),
              foregroundColor: WidgetStateProperty.resolveWith(foreground),
              textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.titleSmall),
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => foreground(states)
                    .withValues(alpha: states.contains(WidgetState.hovered) ? ActionTiles.hoverInk : ActionTiles.noInk),
              ),
              elevation: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return ActionTiles.disabledElevation;
                if (states.contains(WidgetState.pressed)) return ActionTiles.pressedElevation;
                return states.contains(WidgetState.hovered) ? ActionTiles.hoverElevation : ActionTiles.elevation;
              }),
              shadowColor: WidgetStatePropertyAll(scheme.shadow),
              surfaceTintColor: WidgetStatePropertyAll(scheme.surfaceTint),
            ),
            onPressed: command.available ? command.run : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: ActionTiles.icon),
                const SizedBox(height: Space.small),
                Flexible(
                  child: Text(
                    command.label,
                    key: starting ? const Key('start-work-says') : null,
                    textAlign: TextAlign.center,
                    maxLines: ActionTiles.titleLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A project's actions grouped by purpose, from the very commands offered in its menu.
class ProjectCommandTiles extends StatelessWidget {
  /// Constructor taking the menu's commands and the route to its existing work.
  const ProjectCommandTiles({required this.commands, required this.itsWork, this.highlight, super.key});

  /// The page's menu commands, each shown once as a tile.
  final List<Command> commands;

  /// Opens the project's work under Work.
  final Widget itsWork;

  /// The command the finder went to.
  final String? highlight;

  static const _groups = <String>['Work', 'Keep in step', 'Where it lives', 'Remove'];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      for (final group in _groups) ...<Widget>[
        SizedBox(height: group == 'Remove' ? Space.loose : Space.normal),
        if (group == 'Remove') const Divider(),
        Text(group, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Space.small),
        Wrap(
          spacing: Space.normal,
          runSpacing: Space.normal,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (final command in commands.where((command) => command.visible))
              if (_presentation(command).group == group) ...<Widget>[
                CommandTile(
                  key: ValueKey<String>('command-tile-${command.id}'),
                  command: command,
                  icon: _presentation(command).icon,
                  description: _presentation(command).description,
                  highlighted: command.id == 'work.start' && highlight == command.id,
                ),
                if (command.id == 'work.start') itsWork,
              ],
          ],
        ),
      ],
    ],
  );

  static ({String group, IconData icon, String description}) _presentation(Command command) => switch (command.id) {
    'work.start' => (group: 'Work', icon: Icons.add, description: 'Start a new piece of work in this project.'),
    'project.startAgents' => (
      group: 'Work',
      icon: Icons.groups_outlined,
      description: 'Start the agent each repository names, attended, one after another.',
    ),
    'project.messages' => (
      group: 'Work',
      icon: Icons.chat_outlined,
      description: 'Read its conversation, see who has joined and join its room.',
    ),
    'gate.open' => (
      group: 'Work',
      icon: Icons.fact_check_outlined,
      description: 'Review pushes waiting for a decision.',
    ),
    'work.check' => (
      group: 'Work',
      icon: Icons.preview_outlined,
      description: 'See what a start would open without creating work.',
    ),
    'notifications.mute' => (
      group: 'Work',
      icon: Icons.notifications_outlined,
      description: 'Choose whether this project notifies you.',
    ),
    'project.sync' => (
      group: 'Keep in step',
      icon: Icons.sync_outlined,
      description: 'Check how far its repositories are behind upstream.',
    ),
    'project.prepare' => (
      group: 'Keep in step',
      icon: Icons.build_outlined,
      description: 'Build the environment its work runs in.',
    ),
    'project.backups' => (
      group: 'Keep in step',
      icon: Icons.backup_outlined,
      description: 'See the backups kept on this machine.',
    ),
    'project.forge' => (
      group: 'Where it lives',
      icon: Icons.key_outlined,
      description: 'Manage its machines and keys at the forge.',
    ),
    'project.default' => (
      group: 'Where it lives',
      icon: Icons.source_outlined,
      description: 'Manage repositories worked on without a project.',
    ),
    'project.server' => (
      group: 'Where it lives',
      icon: Icons.dns_outlined,
      description: 'Bring this project onto a prepared server in your own account.',
    ),
    'project.follow' => (
      group: 'Where it lives',
      icon: Icons.add_link_outlined,
      description: 'Follow another project on this machine.',
    ),
    'egress.open' => (
      group: 'Where it lives',
      icon: Icons.public_outlined,
      description: 'See and change what this project may reach.',
    ),
    'project.clear' => (
      group: 'Remove',
      icon: Icons.cleaning_services_outlined,
      description: 'Review what clearing this project would remove.',
    ),
    'project.delete' => (
      group: 'Remove',
      icon: Icons.link_off_outlined,
      description: 'Review what stopping following would remove and keep.',
    ),
    'project.takeOffServer' => (
      group: 'Remove',
      icon: Icons.cloud_off_outlined,
      description: 'Review taking this project off its server. Following is kept until you choose to stop.',
    ),
    _ => throw StateError('No project tile description for ${command.id}'),
  };
}

/// A job somebody named, started again from its own tile.
class TemplateTile extends StatelessWidget {
  /// Constructor taking the job and what starting it does.
  const TemplateTile({
    required this.job,
    required this.onPressed,
    this.unavailable,
    this.highlighted = false,
    super.key,
  });

  /// The job.
  final Template job;

  /// Starts it.
  final VoidCallback onPressed;

  /// Why it cannot run now, or null.
  final String? unavailable;

  /// Whether the finder went here.
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Highlight(
    active: highlighted,
    child: SizedBox(
      width: Sizes.jobTile,
      height: Sizes.jobTileHeight,
      child: Tooltip(
        message: unavailable ?? 'Run ${job.name} in ${job.project}',
        child: OutlinedButton.icon(
          key: ValueKey<String>('job ${job.project}/${job.name}'),
          autofocus: highlighted,
          onPressed: unavailable == null ? onPressed : null,
          icon: const Icon(Icons.replay, size: Sizes.rowIcon),
          label: Text('Run ${job.name}', overflow: TextOverflow.ellipsis),
        ),
      ),
    ),
  );
}
