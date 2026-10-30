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

/// A saved job with its start command in a row menu.
class TemplateRow extends StatelessWidget {
  /// Constructor taking the job and what starting it does.
  const TemplateRow({
    required this.job,
    required this.onPressed,
    this.unavailable,
    this.highlighted = false,
    this.onShown,
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

  /// Reports that the finder destination's row menu has opened.
  final VoidCallback? onShown;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey<String>('job ${job.project}/${job.name}'),
    title: Text(job.name),
    subtitle: unavailable == null ? Text('Saved job in ${job.project}') : Text(unavailable!),
    leading: const Icon(Icons.replay),
    trailing: CommandMenu(
      highlight: highlighted ? 'template.start/${job.project}/${job.name}' : null,
      onShown: onShown,
      commands: [
        Command(
          id: 'template.start/${job.project}/${job.name}',
          label: 'Run ${job.name}',
          group: 'Saved jobs',
          home: Home.templateTile,
          unavailable: unavailable,
          run: onPressed,
        ),
      ],
      tooltip: 'Saved job ${job.name}',
    ),
  );
}
